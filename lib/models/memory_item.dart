import 'dart:convert';

/// Ek yaaddasht (memory note) jo app ko yaad rakhni hai.
/// Ye sirf text hai, isliye phone par bahut kam jagah leti hai.
class MemoryItem {
  const MemoryItem({
    required this.id,
    required this.text,
    required this.createdAt,
    required this.updatedAt,
    this.kind = 'note',
    this.title = '',
    this.concepts = const [],
    this.source = 'manual',
    this.chatId,
  });

  final String id;

  /// note | preference | fact | decision (abhi sab 'note' hain, aage ke liye).
  final String kind;

  /// Chhota naam (text ke shuru ke shabd).
  final String title;

  /// Poori yaaddasht.
  final String text;

  /// Tags (aage ke liye).
  final List<String> concepts;

  /// manual (tumne add kiya) ya chat ("yaad rakho" likha).
  final String source;

  /// Kis chat se bani (agar chat se bani ho).
  final String? chatId;

  final DateTime createdAt;
  final DateTime updatedAt;

  MemoryItem copyWith({
    String? title,
    String? text,
    DateTime? updatedAt,
  }) {
    return MemoryItem(
      id: id,
      kind: kind,
      title: title ?? this.title,
      text: text ?? this.text,
      concepts: concepts,
      source: source,
      chatId: chatId,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'kind': kind,
      'title': title,
      'text': text,
      'concepts': jsonEncode(concepts),
      'source': source,
      'chat_id': chatId,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }

  factory MemoryItem.fromMap(Map<String, Object?> map) {
    var concepts = <String>[];
    try {
      final raw = map['concepts'] as String?;
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          concepts = decoded.map((e) => e.toString()).toList();
        }
      }
    } catch (_) {
      concepts = <String>[];
    }

    return MemoryItem(
      id: map['id'] as String,
      kind: map['kind'] as String? ?? 'note',
      title: map['title'] as String? ?? '',
      text: map['text'] as String? ?? '',
      concepts: concepts,
      source: map['source'] as String? ?? 'manual',
      chatId: map['chat_id'] as String?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        (map['created_at'] as int?) ?? 0,
      ),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        (map['updated_at'] as int?) ?? 0,
      ),
    );
  }
}
