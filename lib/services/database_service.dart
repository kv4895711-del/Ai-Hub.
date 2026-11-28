import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/chat.dart';
import '../models/memory_item.dart';
import '../models/message.dart';

/// Saves chats and messages on the phone (SQLite).
/// Messages are linked to their chat, so deleting a chat deletes its messages too.
class DatabaseService {
  static const String _dbName = 'ai_hub.db';
  static const int _dbVersion = 2;

  static const String _chatsTable = 'chats';
  static const String _messagesTable = 'messages';
  static const String _memoryTable = 'memory_items';

  Future<Database>? _opening;

  // ---------- Opening ----------

  Future<Database> _database() {
    return _opening ??= _open();
  }

  Future<Database> _open() async {
    final dir = await getDatabasesPath();
    final path = p.join(dir, _dbName);
    return openDatabase(
      path,
      version: _dbVersion,
      onConfigure: (db) async {
        // Needed so deleting a chat also deletes its messages.
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $_chatsTable (
            id TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL,
            pinned INTEGER NOT NULL DEFAULT 0,
            model_id TEXT NOT NULL DEFAULT 'auto'
          )
        ''');
        await db.execute('''
          CREATE TABLE $_messagesTable (
            id TEXT PRIMARY KEY,
            chat_id TEXT NOT NULL,
            role TEXT NOT NULL,
            content TEXT NOT NULL,
            model_name TEXT NOT NULL DEFAULT '',
            created_at INTEGER NOT NULL,
            is_error INTEGER NOT NULL DEFAULT 0,
            attachments TEXT NOT NULL DEFAULT '[]',
            FOREIGN KEY (chat_id) REFERENCES $_chatsTable (id) ON DELETE CASCADE
          )
        ''');
        await db.execute(
          'CREATE INDEX idx_messages_chat ON $_messagesTable (chat_id, created_at)',
        );
        await _createMemoryTable(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        // Purani chats ko haath nahi lagate: sirf naya memory table jodte hain.
        if (oldVersion < 2) {
          await _createMemoryTable(db);
        }
      },
    );
  }

  static Future<void> _createMemoryTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_memoryTable (
        id TEXT PRIMARY KEY,
        kind TEXT NOT NULL DEFAULT 'note',
        title TEXT NOT NULL DEFAULT '',
        text TEXT NOT NULL,
        concepts TEXT NOT NULL DEFAULT '[]',
        source TEXT NOT NULL DEFAULT 'manual',
        chat_id TEXT,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_memory_updated '
      'ON $_memoryTable (updated_at)',
    );
  }

  // ---------- Chats ----------

  /// All chats: pinned first, then the most recently used.
  Future<List<Chat>> getChats() async {
    final db = await _database();
    final rows = await db.query(
      _chatsTable,
      orderBy: 'pinned DESC, updated_at DESC',
    );
    return rows.map(Chat.fromMap).toList();
  }

  /// Chats whose title or any message contains [query].
  Future<List<Chat>> searchChats(String query) async {
    final q = query.trim();
    if (q.isEmpty) return getChats();

    final db = await _database();
    final like = '%${_escapeLike(q)}%';
    final rows = await db.rawQuery(
      'SELECT DISTINCT c.* FROM $_chatsTable c '
      'LEFT JOIN $_messagesTable m ON m.chat_id = c.id '
      "WHERE c.title LIKE ? ESCAPE '\\' OR m.content LIKE ? ESCAPE '\\' "
      'ORDER BY c.pinned DESC, c.updated_at DESC',
      [like, like],
    );
    return rows.map(Chat.fromMap).toList();
  }

  /// Adds the chat, or updates it if it already exists.
  /// (We do not use "replace", because that would delete the chat's messages.)
  Future<void> saveChat(Chat chat) async {
    final db = await _database();
    await db.insert(
      _chatsTable,
      chat.toMap(),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    await db.update(
      _chatsTable,
      chat.toMap(),
      where: 'id = ?',
      whereArgs: [chat.id],
    );
  }

  Future<void> renameChat(String chatId, String title) async {
    final db = await _database();
    await db.update(
      _chatsTable,
      {
        'title': title,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [chatId],
    );
  }

  Future<void> setPinned(String chatId, bool pinned) async {
    final db = await _database();
    await db.update(
      _chatsTable,
      {'pinned': pinned ? 1 : 0},
      where: 'id = ?',
      whereArgs: [chatId],
    );
  }

  Future<void> updateChatModel(String chatId, String modelId) async {
    final db = await _database();
    await db.update(
      _chatsTable,
      {
        'model_id': modelId,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [chatId],
    );
  }

  /// Deletes one chat and all its messages.
  Future<void> deleteChat(String chatId) async {
    final db = await _database();
    await db.delete(_messagesTable, where: 'chat_id = ?', whereArgs: [chatId]);
    await db.delete(_chatsTable, where: 'id = ?', whereArgs: [chatId]);
  }

  /// Deletes every chat and every message.
  Future<void> deleteAllChats() async {
    final db = await _database();
    await db.delete(_messagesTable);
    await db.delete(_chatsTable);
  }

  // ---------- Messages ----------

  /// All messages of a chat, oldest first.
  Future<List<ChatMessage>> getMessages(String chatId) async {
    final db = await _database();
    final rows = await db.query(
      _messagesTable,
      where: 'chat_id = ?',
      whereArgs: [chatId],
      orderBy: 'created_at ASC',
    );
    return rows.map(ChatMessage.fromMap).toList();
  }

  /// Adds the message, or replaces it if the same id is saved again.
  Future<void> saveMessage(ChatMessage message) async {
    final db = await _database();
    await db.insert(
      _messagesTable,
      message.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteMessage(String messageId) async {
    final db = await _database();
    await db.delete(_messagesTable, where: 'id = ?', whereArgs: [messageId]);
  }

  // ---------- Helpers ----------

  /// Makes %, _ and \ in a search word mean themselves, not "wildcard".
  String _escapeLike(String input) {
    return input
        .replaceAll(r'\', r'\\')
        .replaceAll('%', r'\%')
        .replaceAll('_', r'\_');
  }

  // ---------- Memory ----------

  /// Saare memory notes, sabse naya pehle.
  Future<List<MemoryItem>> getMemories() async {
    final db = await _database();
    final rows = await db.query(_memoryTable, orderBy: 'updated_at DESC');
    return rows.map(MemoryItem.fromMap).toList();
  }

  /// Note jodta hai, ya wahi id pehle se ho to badal deta hai.
  Future<void> saveMemory(MemoryItem item) async {
    final db = await _database();
    await db.insert(
      _memoryTable,
      item.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteMemories(List<String> ids) async {
    if (ids.isEmpty) return;
    final db = await _database();
    const chunk = 400; // SQLite ek baar mein limited "?" leta hai
    for (var i = 0; i < ids.length; i += chunk) {
      final part = ids.sublist(i, i + chunk > ids.length ? ids.length : i + chunk);
      final marks = List.filled(part.length, '?').join(',');
      await db.delete(_memoryTable, where: 'id IN ($marks)', whereArgs: part);
    }
  }

  Future<void> deleteAllMemories() async {
    final db = await _database();
    await db.delete(_memoryTable);
  }

  Future<void> close() async {
    final opening = _opening;
    if (opening == null) return;
    final db = await opening;
    await db.close();
    _opening = null;
  }
}
