import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/memory_item.dart';
import 'database_service.dart';

/// App ki yaaddasht: chhote text notes jo phone mein hi save hote hain.
///
/// Kaam:
///  - notes add / edit / delete (Memory screen se, ya chat mein "yaad rakho: ...")
///  - <private>...</private> ke andar ka text kabhi save nahi hota
///  - search (phone ki memory mein hi, bina internet)
///  - chat ke liye chhota "context" banana (pehle chhoti list, kaam ke notes poore)
///
/// Saare notes memory (RAM) mein bhi rehte hain (max 2000, kuch MB), isliye
/// search aur context banana turant hota hai.
class MemoryService extends ChangeNotifier {
  MemoryService(this._db);

  final DatabaseService _db;

  static const Uuid _uuid = Uuid();

  /// Isse zyada notes hone par sabse purane apne aap hat jaate hain.
  static const int maxItems = 2000;

  /// Ek note ki max lambai.
  static const int maxTextLength = 600;

  static const int _contextMaxLines = 15;
  static const int _contextRelevantMax = 5;
  static const int _relevantClip = 300;
  static const int _otherClip = 100;
  static const String _enabledKey = 'memory_enabled';

  final List<MemoryItem> _items = []; // sabse naya pehle
  bool _enabled = true;
  bool _loaded = false;
  bool _disposed = false;

  List<MemoryItem> get items => List.unmodifiable(_items);
  bool get enabled => _enabled;
  bool get isLoaded => _loaded;
  int get count => _items.length;

  // ---------- Load / settings ----------

  Future<void> load() async {
    if (_loaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      _enabled = prefs.getBool(_enabledKey) ?? true;
    } catch (_) {
      // Default: ON.
    }
    try {
      final loaded = await _db.getMemories();
      _items
        ..clear()
        ..addAll(loaded);
    } catch (e) {
      debugPrint('MemoryService.load error: $e');
    }
    _loaded = true;
    _safeNotify();
  }

  Future<void> setEnabled(bool value) async {
    _enabled = value;
    _safeNotify();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_enabledKey, value);
    } catch (_) {
      // Saving is best-effort.
    }
  }

  // ---------- Cleaning ----------

  static final RegExp _privatePair =
      RegExp(r'<private>[\s\S]*?</private>', caseSensitive: false);
  static final RegExp _privateOpen =
      RegExp(r'<private>[\s\S]*$', caseSensitive: false);

  /// <private>...</private> ke andar ka text hata deta hai, extra space
  /// saaf karta hai aur lambai ki hadd lagata hai.
  static String clean(String input) {
    var t = input.replaceAll(_privatePair, ' ');
    // Band na kiya hua <private> ho to uske baad ka sab kuch chhupa do.
    t = t.replaceAll(_privateOpen, ' ');
    t = t.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (t.length > maxTextLength) {
      t = t.substring(0, maxTextLength).trim();
    }
    return t;
  }

  static String _makeTitle(String text) {
    if (text.length <= 60) return text;
    return '${text.substring(0, 57).trim()}...';
  }

  static String _norm(String text) => text.toLowerCase().trim();

  // ---------- Add / edit / delete ----------

  /// Note jodta hai. Wahi text pehle se ho to bas use naya (upar) kar deta hai.
  /// Memory list turant badal jaati hai; database ka kaam uske baad hota hai.
  Future<MemoryItem?> add(
    String text, {
    String source = 'manual',
    String? chatId,
  }) async {
    final cleaned = clean(text);
    if (cleaned.isEmpty) return null;

    final now = DateTime.now();
    final key = _norm(cleaned);
    final idx = _items.indexWhere((m) => _norm(m.text) == key);

    final MemoryItem item;
    if (idx >= 0) {
      item = _items[idx].copyWith(updatedAt: now);
      _items.removeAt(idx);
    } else {
      item = MemoryItem(
        id: _uuid.v4(),
        text: cleaned,
        title: _makeTitle(cleaned),
        source: source,
        chatId: chatId,
        createdAt: now,
        updatedAt: now,
      );
    }
    _items.insert(0, item);
    _safeNotify();

    try {
      await _db.saveMemory(item);
    } catch (e) {
      debugPrint('MemoryService.add error: $e');
    }
    await _trim();
    return item;
  }

  Future<void> edit(String id, String text) async {
    final cleaned = clean(text);
    if (cleaned.isEmpty) return;
    final idx = _items.indexWhere((m) => m.id == id);
    if (idx < 0) return;

    final item = _items[idx].copyWith(
      text: cleaned,
      title: _makeTitle(cleaned),
      updatedAt: DateTime.now(),
    );
    _items.removeAt(idx);
    _items.insert(0, item);
    _safeNotify();

    try {
      await _db.saveMemory(item);
    } catch (e) {
      debugPrint('MemoryService.edit error: $e');
    }
  }

  Future<void> remove(String id) async {
    _items.removeWhere((m) => m.id == id);
    _safeNotify();
    try {
      await _db.deleteMemories([id]);
    } catch (e) {
      debugPrint('MemoryService.remove error: $e');
    }
  }

  Future<void> clearAll() async {
    _items.clear();
    _safeNotify();
    try {
      await _db.deleteAllMemories();
    } catch (e) {
      debugPrint('MemoryService.clearAll error: $e');
    }
  }

  /// Hadd se zyada hone par sabse purane notes hata deta hai.
  Future<void> _trim() async {
    if (_items.length <= maxItems) return;
    final extra = _items.sublist(maxItems).map((m) => m.id).toList();
    _items.removeRange(maxItems, _items.length);
    _safeNotify();
    try {
      await _db.deleteMemories(extra);
    } catch (e) {
      debugPrint('MemoryService.trim error: $e');
    }
  }

  // ---------- Chat se "yaad rakho" ----------

  static final RegExp _command = RegExp(
    r'^(?:yaad\s+rakh(?:o|na|iye)|remember(?:\s+that)?|याद\s+रख(?:ो|ना|िए))'
    r'(?:\s*[:,\-]\s*|\s+)(?:ki\s+)?(.+)$',
    caseSensitive: false,
    dotAll: true,
  );

  /// "yaad rakho: ..." ya "remember that ..." jaisa message ho to use save
  /// karta hai. Save hua to true.
  Future<bool> saveFromChat(String message, {String? chatId}) async {
    if (!_enabled) return false;
    final match = _command.firstMatch(message.trim());
    if (match == null) return false;
    final item = await add(
      match.group(1) ?? '',
      source: 'chat',
      chatId: chatId,
    );
    return item != null;
  }

  // ---------- Search ----------

  static List<String> _words(String text) {
    return text
        .toLowerCase()
        .split(RegExp(r'[^\p{L}\p{M}\p{N}]+', unicode: true))
        .where((w) => w.isNotEmpty)
        .toList();
  }

  /// Saare shabd jis note mein hon, wahi dikhte hain. Khaali search = sab.
  List<MemoryItem> search(String query) {
    final words = _words(query);
    if (words.isEmpty) return items;
    return _items.where((m) {
      final hay = m.text.toLowerCase();
      return words.every((w) => hay.contains(w));
    }).toList();
  }

  // ---------- Chat ke liye context ----------

  static const Set<String> _stopWords = {
    'the', 'and', 'for', 'you', 'that', 'with', 'this', 'what', 'how',
    'are', 'was', 'can', 'please', 'about', 'have', 'from', 'your',
    'mujhe', 'mera', 'meri', 'mere', 'hai', 'hain', 'kya', 'ko', 'ka',
    'ki', 'ke', 'se', 'mein', 'aur', 'tum', 'main', 'nahi', 'karo', 'kar',
    'ye', 'yeh', 'wo', 'woh', 'bata', 'batao', 'kaise',
  };

  static List<String> _keywords(String text) {
    final out = <String>[];
    for (final w in _words(text)) {
      if (w.length < 3 || _stopWords.contains(w)) continue;
      if (!out.contains(w)) out.add(w);
      if (out.length >= 8) break;
    }
    return out;
  }

  static String _clip(String text, int max) {
    if (text.length <= max) return text;
    return '${text.substring(0, max - 3).trim()}...';
  }

  /// Chat ke system prompt mein jodne ke liye chhota text.
  /// Pehle "kaam ke" notes (user ke naye message se milte shabd) poore,
  /// phir baaki naye notes chhote karke. Memory band ya khaali ho to ''.
  String buildContext(String userText) {
    if (!_enabled || _items.isEmpty) return '';

    final keywords = _keywords(userText);
    final scored = <MapEntry<MemoryItem, int>>[];
    if (keywords.isNotEmpty) {
      for (final m in _items) {
        final hay = m.text.toLowerCase();
        var score = 0;
        for (final k in keywords) {
          if (hay.contains(k)) score++;
        }
        if (score > 0) scored.add(MapEntry(m, score));
      }
      scored.sort((a, b) {
        final c = b.value.compareTo(a.value);
        return c != 0 ? c : b.key.updatedAt.compareTo(a.key.updatedAt);
      });
    }

    final relevant =
        scored.take(_contextRelevantMax).map((e) => e.key).toList();
    final relevantIds = relevant.map((m) => m.id).toSet();
    final others = _items
        .where((m) => !relevantIds.contains(m.id))
        .take(_contextMaxLines - relevant.length)
        .toList();

    final b = StringBuffer()
      ..writeln('Notes the user saved in this app (their memory). '
          'Use them only when they help. Do not mention them otherwise.');
    for (final m in relevant) {
      b.writeln('- ${_clip(m.text, _relevantClip)}');
    }
    for (final m in others) {
      b.writeln('- ${_clip(m.text, _otherClip)}');
    }
    return b.toString().trim();
  }

  // ---------- Lifecycle ----------

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
