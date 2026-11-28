import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../core/constants.dart';
import '../core/utils.dart';
import '../models/chat.dart';
import '../models/message.dart';
import '../services/api_service.dart';
import '../services/database_service.dart';
import '../services/memory_service.dart';
import 'settings_provider.dart';

/// Chat screen ka dimaag: chats aur messages sambhalta hai, gateway ko
/// message bhejta hai, jawab stream karta hai, aur sab kuch database
/// (DatabaseService) mein save karta hai.
class ChatProvider extends ChangeNotifier {
  ChatProvider(this._settings, this._db, {ApiService? api})
      : _api = api ?? ApiService();

  final SettingsProvider _settings;
  final DatabaseService _db;
  final ApiService _api;

  /// Phone mein save hone wali yaaddasht (Memory screen yahin se lega).
  late final MemoryService _memory = MemoryService(_db);
  MemoryService get memory => _memory;

  static const Uuid _uuid = Uuid();

  static const String _systemPrompt =
      'You are a helpful, friendly AI assistant. Answer clearly and honestly. '
      'Reply in the same language the user writes in (for example English, '
      'Hindi or Hinglish). Use markdown for code and lists.';

  final List<Chat> _chats = [];
  final Map<String, List<ChatMessage>> _messages = {};
  final Set<String> _loadingMessages = {};

  String? _currentChatId;
  bool _generating = false;
  bool _stopRequested = false;
  bool _loaded = false;
  bool _disposed = false;
  DateTime _lastNotify = DateTime.fromMillisecondsSinceEpoch(0);

  /// Database ke kaam line se chalte hain (order na bigde).
  Future<void> _queue = Future<void>.value();

  // ---------- Read-only state ----------

  List<Chat> get chats => List.unmodifiable(_chats);
  String? get currentChatId => _currentChatId;
  bool get isGenerating => _generating;

  /// Kya chats database se load ho chuki hain?
  bool get isLoaded => _loaded;

  /// Kya khuli hui chat ke messages abhi load ho rahe hain?
  bool get isLoadingMessages {
    final id = _currentChatId;
    return id != null && _loadingMessages.contains(id);
  }

  /// Agla message is model se jayega ("auto" by default).
  String get currentModel => _settings.lastModel;

  Chat? get currentChat {
    final id = _currentChatId;
    if (id == null) return null;
    return _chatById(id);
  }

  /// Khuli hui chat ke messages.
  List<ChatMessage> get messages {
    final id = _currentChatId;
    if (id == null) return const [];
    return _messages[id] ?? const [];
  }

  /// True jab aakhri message jawab (ya error) ho, jise dobara banwaya ja sake.
  bool get canRegenerate {
    if (_generating) return false;
    final list = messages;
    if (list.isEmpty) return false;
    return !list.last.isUser && list.any((m) => m.isUser);
  }

  // ---------- Start: database se chats load ----------

  /// App shuru hone par ek baar chalao. Chats load hoti hain,
  /// lekin app nayi (khaali) chat par hi khulta hai.
  Future<void> load() async {
    if (_loaded) return;
    try {
      final loaded = await _db.getChats();
      _chats
        ..clear()
        ..addAll(loaded);
      _sortChats();
    } catch (e) {
      debugPrint('ChatProvider.load error: $e');
    }
    await _memory.load();
    _loaded = true;
    notifyListeners();
  }

  // ---------- Opening chats ----------

  /// Nayi khaali chat. Ye tab save hoti hai jab pehla message bhejo.
  void newChat() {
    if (_generating) stop();
    _currentChatId = null;
    notifyListeners();
  }

  void selectChat(String id) {
    if (_generating) stop();
    if (_chatById(id) == null) return;
    _currentChatId = id;
    notifyListeners();
    if (!_messages.containsKey(id)) {
      unawaited(_loadMessagesFor(id));
    }
  }

  Future<void> _loadMessagesFor(String id) async {
    if (_messages.containsKey(id) || _loadingMessages.contains(id)) return;
    _loadingMessages.add(id);
    notifyListeners();

    List<ChatMessage> loaded = [];
    try {
      await _queue; // pehle ke saare writes poore hone do
      loaded = List<ChatMessage>.from(await _db.getMessages(id));
      loaded.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    } catch (e) {
      debugPrint('ChatProvider._loadMessagesFor error: $e');
    }

    _loadingMessages.remove(id);
    // Agar beech mein chat delete ho gayi to kuch mat jodo.
    if (_chatById(id) != null && !_messages.containsKey(id)) {
      _messages[id] = loaded;
    }
    notifyListeners();
  }

  // ---------- Chat list actions (drawer) ----------

  void renameChat(String id, String title) {
    var clean = title.trim();
    if (clean.isEmpty) return;
    if (clean.length > AppConstants.maxTitleLength) {
      clean = clean.substring(0, AppConstants.maxTitleLength);
    }
    final i = _chats.indexWhere((c) => c.id == id);
    if (i < 0) return;
    _chats[i] = _chats[i].copyWith(title: clean);
    notifyListeners();
    _enqueue(() async {
      await _db.renameChat(id, clean);
    });
  }

  void setPinned(String id, bool pinned) {
    final i = _chats.indexWhere((c) => c.id == id);
    if (i < 0) return;
    _chats[i] = _chats[i].copyWith(pinned: pinned);
    notifyListeners();
    _enqueue(() async {
      await _db.setPinned(id, pinned);
    });
  }

  void deleteChat(String id) {
    if (_generating && id == _currentChatId) stop();
    _chats.removeWhere((c) => c.id == id);
    _messages.remove(id);
    _loadingMessages.remove(id);
    if (_currentChatId == id) _currentChatId = null;
    notifyListeners();
    _enqueue(() async {
      await _db.deleteChat(id);
    });
  }

  void deleteAllChats() {
    if (_generating) stop();
    _chats.clear();
    _messages.clear();
    _loadingMessages.clear();
    _currentChatId = null;
    notifyListeners();
    _enqueue(() async {
      await _db.deleteAllChats();
    });
  }

  /// Title mein search (memory mein, database nahi chhoota).
  List<Chat> searchChats(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return chats;
    return _chats.where((c) => c.title.toLowerCase().contains(q)).toList();
  }

  // ---------- Sending ----------

  /// User ka message jodta hai aur jawab laata hai.
  /// [attachments] plain maps hain (Attachment.toJson() se banao).
  Future<void> sendMessage(
    String text, {
    List<Map<String, dynamic>> attachments = const [],
  }) async {
    final clean = text.trim();
    if (_generating) return;
    if (clean.isEmpty && attachments.isEmpty) return;

    final bool isNewChat = _currentChatId == null;
    final String chatId = _currentChatId ?? _createChat().id;

    // Chat ke purane messages abhi load ho rahe hain: thodi der ruko.
    if (_loadingMessages.contains(chatId)) return;
    final list = _messages[chatId];
    if (list == null) return;

    final isFirst = list.isEmpty;
    final userMsg = ChatMessage(
      id: _uuid.v4(),
      chatId: chatId,
      role: MessageRole.user,
      content: clean,
      createdAt: DateTime.now(),
      attachments: attachments,
    );
    list.add(userMsg);

    String? newTitle;
    if (isFirst) {
      newTitle = AppUtils.makeTitle(clean.isEmpty ? 'Attachment' : clean);
      _rename(chatId, newTitle);
    }

    // Database mein save (pehle chat, phir message).
    final chat = _chatById(chatId);
    if (isNewChat && chat != null) {
      _enqueue(() async {
        await _db.saveChat(chat);
      });
    } else if (newTitle != null) {
      final t = newTitle;
      _enqueue(() async {
        await _db.renameChat(chatId, t);
      });
    }
    _enqueue(() async {
      await _db.saveMessage(userMsg);
    });

    notifyListeners();

    // "yaad rakho: ..." likha ho to memory mein save karo. Note memory list
    // mein turant jud jaata hai, isliye isi message ke jawab mein bhi dikhega.
    unawaited(
      _memory.saveFromChat(clean, chatId: chatId).catchError((_) => false),
    );

    await _generate(chatId);
  }

  /// Aakhri jawab hata kar model se dobara poochta hai.
  Future<void> regenerate() async {
    if (_generating) return;
    final id = _currentChatId;
    if (id == null) return;
    final list = _messages[id];
    if (list == null || list.isEmpty) return;

    final removedIds = <String>[];
    while (list.isNotEmpty && !list.last.isUser) {
      removedIds.add(list.removeLast().id);
    }
    for (final mid in removedIds) {
      _enqueue(() async {
        await _db.deleteMessage(mid);
      });
    }
    notifyListeners();
    if (list.isEmpty) return;

    await _generate(id);
  }

  /// Jawab likhna rokta hai. Jo likha ja chuka wo rehta hai.
  void stop() {
    if (!_generating) return;
    _stopRequested = true;
    _api.cancel();
  }

  // ---------- The actual work ----------

  Future<void> _generate(String chatId) async {
    final list = _messages[chatId];
    if (list == null) return;

    _generating = true;
    _stopRequested = false;

    // Model beech chat mein badla ho to naya model use hota hai.
    final model = _settings.lastModel;
    final baseUrl = _settings.baseUrl;
    final apiKey = _settings.apiKey;

    final ci = _chats.indexWhere((c) => c.id == chatId);
    if (ci >= 0 && _chats[ci].modelId != model) {
      _chats[ci] = _chats[ci].copyWith(modelId: model);
      _enqueue(() async {
        await _db.updateChatModel(chatId, model);
      });
    }

    final history = List<ChatMessage>.from(list);
    final placeholder = ChatMessage(
      id: _uuid.v4(),
      chatId: chatId,
      role: MessageRole.assistant,
      content: '',
      modelName: model,
      createdAt: DateTime.now(),
      isStreaming: true,
    );
    list.add(placeholder);
    notifyListeners();

    final buffer = StringBuffer();
    ApiException? failure;

    try {
      final apiMessages = await _api.buildMessages(
        history,
        systemPrompt: _promptWithMemory(history),
      );

      try {
        await for (final piece in _api.streamChat(
          baseUrl: baseUrl,
          apiKey: apiKey,
          model: model,
          messages: apiMessages,
        )) {
          buffer.write(piece);
          _updateStreaming(chatId, placeholder.id, buffer.toString());
        }
      } on ApiException catch (e) {
        // Kuch models streaming nahi karte: ek baar bina streaming ke try.
        final canFallback = buffer.isEmpty &&
            !_stopRequested &&
            (e.kind == ApiErrorKind.badRequest ||
                e.kind == ApiErrorKind.unknown);
        if (!canFallback) rethrow;
        final full = await _api.chat(
          baseUrl: baseUrl,
          apiKey: apiKey,
          model: model,
          messages: apiMessages,
        );
        buffer.write(full);
      }

      // Stream bina text ke khatam hui: ek baar bina streaming ke try.
      if (buffer.isEmpty && !_stopRequested) {
        final full = await _api.chat(
          baseUrl: baseUrl,
          apiKey: apiKey,
          model: model,
          messages: apiMessages,
        );
        buffer.write(full);
      }

      if (buffer.isEmpty && !_stopRequested) {
        failure = const ApiException(
          ApiErrorKind.unknown,
          detail: 'The model sent an empty reply.',
        );
      }
    } on ApiException catch (e) {
      failure = e;
    } catch (e) {
      failure = ApiException(ApiErrorKind.unknown, detail: e.toString());
    }

    _finish(chatId, placeholder.id, buffer.toString(), failure, model);
    _generating = false;
    _stopRequested = false;
    notifyListeners();
  }

  /// System prompt, aur memory ON ho to user ke saved notes ka chhota hissa.
  String _promptWithMemory(List<ChatMessage> history) {
    var lastUser = '';
    for (var i = history.length - 1; i >= 0; i--) {
      if (history[i].isUser) {
        lastUser = history[i].content;
        break;
      }
    }
    final context = _memory.buildContext(lastUser);
    return context.isEmpty ? _systemPrompt : '$_systemPrompt\n\n$context';
  }

  /// Naya text "likhe ja rahe" jawab mein daalta hai.
  /// Screen ko ek second mein lagbhag 25 baar hi update karta hai.
  void _updateStreaming(String chatId, String messageId, String text) {
    final list = _messages[chatId];
    if (list == null) return;
    final i = list.indexWhere((m) => m.id == messageId);
    if (i < 0) return;
    list[i] = list[i].copyWith(content: text);

    final now = DateTime.now();
    if (now.difference(_lastNotify).inMilliseconds >= 40) {
      _lastNotify = now;
      notifyListeners();
    }
  }

  /// "Likhe ja rahe" message ko final (ya error) banata hai aur save karta hai.
  void _finish(
    String chatId,
    String messageId,
    String text,
    ApiException? failure,
    String model,
  ) {
    final list = _messages[chatId];
    if (list == null) return; // chat beech mein delete ho gayi

    final toSave = <ChatMessage>[];

    final i = list.indexWhere((m) => m.id == messageId);
    if (i >= 0) {
      if (text.trim().isEmpty) {
        list.removeAt(i);
      } else {
        list[i] = list[i].copyWith(content: text, isStreaming: false);
        toSave.add(list[i]);
      }
    }

    if (failure != null) {
      final err = ChatMessage(
        id: _uuid.v4(),
        chatId: chatId,
        role: MessageRole.assistant,
        content: failure.friendlyMessage,
        modelName: model,
        createdAt: DateTime.now(),
        isError: true,
      );
      list.add(err);
      toSave.add(err);
    }

    _touch(chatId);

    for (final m in toSave) {
      _enqueue(() async {
        await _db.saveMessage(m);
      });
    }
  }

  // ---------- Helpers ----------

  Chat? _chatById(String id) {
    for (final c in _chats) {
      if (c.id == id) return c;
    }
    return null;
  }

  Chat _createChat() {
    final now = DateTime.now();
    final chat = Chat(
      id: _uuid.v4(),
      title: AppConstants.newChatTitle,
      createdAt: now,
      updatedAt: now,
      modelId: _settings.lastModel,
    );
    _chats.insert(0, chat);
    _messages[chat.id] = [];
    _currentChatId = chat.id;
    return chat;
  }

  void _rename(String id, String title) {
    final i = _chats.indexWhere((c) => c.id == id);
    if (i < 0) return;
    _chats[i] = _chats[i].copyWith(title: title, updatedAt: DateTime.now());
  }

  void _touch(String id) {
    final i = _chats.indexWhere((c) => c.id == id);
    if (i < 0) return;
    _chats[i] = _chats[i].copyWith(updatedAt: DateTime.now());
  }

  void _sortChats() {
    _chats.sort((a, b) {
      if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
      return b.updatedAt.compareTo(a.updatedAt);
    });
  }

  /// Database ka kaam line mein lagata hai. Error aaye to app nahi toot'ta.
  void _enqueue(Future<void> Function() job) {
    _queue = _queue.then((_) async {
      try {
        await job();
      } catch (e) {
        debugPrint('Database error: $e');
      }
    });
  }

  // ---------- Lifecycle ----------

  @override
  void notifyListeners() {
    if (_disposed) return;
    super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _memory.dispose();
    _api.cancel();
    _queue.then((_) async {
      try {
        await _db.close();
      } catch (_) {}
    });
    super.dispose();
  }
}
