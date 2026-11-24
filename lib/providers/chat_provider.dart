import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../core/constants.dart';
import '../core/utils.dart';
import '../models/chat.dart';
import '../models/message.dart';
import '../services/api_service.dart';
import 'settings_provider.dart';

/// The brain of the chat screen: keeps the chats and messages, sends a message
/// to the gateway, shows the answer as it is written, and handles stop,
/// regenerate and errors.
class ChatProvider extends ChangeNotifier {
  ChatProvider(this._settings, {ApiService? api}) : _api = api ?? ApiService();

  final SettingsProvider _settings;
  final ApiService _api;

  static const Uuid _uuid = Uuid();

  static const String _systemPrompt =
      'You are a helpful, friendly AI assistant. Answer clearly and honestly. '
      'Reply in the same language the user writes in (for example English, '
      'Hindi or Hinglish). Use markdown for code and lists.';

  final List<Chat> _chats = [];
  final Map<String, List<ChatMessage>> _messages = {};
  String? _currentChatId;
  bool _generating = false;
  bool _stopRequested = false;
  DateTime _lastNotify = DateTime.fromMillisecondsSinceEpoch(0);

  // ---------- Read-only state ----------

  List<Chat> get chats => List.unmodifiable(_chats);
  String? get currentChatId => _currentChatId;
  bool get isGenerating => _generating;

  /// The model that will answer the next message ("auto" by default).
  String get currentModel => _settings.lastModel;

  Chat? get currentChat {
    final id = _currentChatId;
    if (id == null) return null;
    for (final c in _chats) {
      if (c.id == id) return c;
    }
    return null;
  }

  /// Messages of the chat that is open right now.
  List<ChatMessage> get messages {
    final id = _currentChatId;
    if (id == null) return const [];
    return _messages[id] ?? const [];
  }

  /// True when the last message is an answer (or an error) that can be redone.
  bool get canRegenerate {
    if (_generating) return false;
    final list = messages;
    if (list.isEmpty) return false;
    return !list.last.isUser && list.any((m) => m.isUser);
  }

  // ---------- Opening chats ----------

  /// Starts a fresh, empty chat. It is only saved when the first message is sent.
  void newChat() {
    if (_generating) stop();
    _currentChatId = null;
    notifyListeners();
  }

  void selectChat(String id) {
    if (_generating) stop();
    if (!_messages.containsKey(id)) return;
    _currentChatId = id;
    notifyListeners();
  }

  // ---------- Sending ----------

  /// Adds the user's message and gets the answer.
  /// [attachments] are plain maps (see ApiService.buildMessages).
  Future<void> sendMessage(
    String text, {
    List<Map<String, dynamic>> attachments = const [],
  }) async {
    final clean = text.trim();
    if (_generating) return;
    if (clean.isEmpty && attachments.isEmpty) return;

    final String chatId = _currentChatId ?? _createChat().id;
    final list = _messages[chatId]!;
    final isFirst = list.isEmpty;

    list.add(
      ChatMessage(
        id: _uuid.v4(),
        chatId: chatId,
        role: MessageRole.user,
        content: clean,
        createdAt: DateTime.now(),
        attachments: attachments,
      ),
    );

    if (isFirst) {
      _rename(chatId, AppUtils.makeTitle(clean.isEmpty ? 'Attachment' : clean));
    }
    notifyListeners();

    await _generate(chatId);
  }

  /// Throws away the last answer and asks the model again.
  Future<void> regenerate() async {
    if (_generating) return;
    final id = _currentChatId;
    if (id == null) return;
    final list = _messages[id];
    if (list == null || list.isEmpty) return;

    while (list.isNotEmpty && !list.last.isUser) {
      list.removeLast();
    }
    notifyListeners();
    if (list.isEmpty) return;

    await _generate(id);
  }

  /// Stops the answer that is being written. The part already written stays.
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

    final model = _settings.lastModel;
    final baseUrl = _settings.baseUrl;
    final apiKey = _settings.apiKey;

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
      final apiMessages =
          await _api.buildMessages(history, systemPrompt: _systemPrompt);

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
        // Some models do not support streaming: try once without it.
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

      // The stream ended without any text: try once without streaming.
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

  /// Puts the newest text into the answer that is being written.
  /// Updates the screen at most about 25 times a second.
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

  /// Turns the "being written" message into a final one (or an error).
  void _finish(
    String chatId,
    String messageId,
    String text,
    ApiException? failure,
    String model,
  ) {
    final list = _messages[chatId];
    if (list == null) return;

    final i = list.indexWhere((m) => m.id == messageId);
    if (i >= 0) {
      if (text.trim().isEmpty) {
        list.removeAt(i);
      } else {
        list[i] = list[i].copyWith(content: text, isStreaming: false);
      }
    }

    if (failure != null) {
      list.add(
        ChatMessage(
          id: _uuid.v4(),
          chatId: chatId,
          role: MessageRole.assistant,
          content: failure.friendlyMessage,
          modelName: model,
          createdAt: DateTime.now(),
          isError: true,
        ),
      );
    }
    _touch(chatId);
  }

  // ---------- Chat list helpers ----------

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
}
