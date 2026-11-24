/// One conversation (a row in the chat list). The messages live in ChatMessage.
class Chat {
  final String id;
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool pinned;

  /// The model that was last used in this chat ("auto" by default).
  final String modelId;

  const Chat({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    this.pinned = false,
    this.modelId = 'auto',
  });

  Chat copyWith({
    String? title,
    DateTime? updatedAt,
    bool? pinned,
    String? modelId,
  }) {
    return Chat(
      id: id,
      title: title ?? this.title,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      pinned: pinned ?? this.pinned,
      modelId: modelId ?? this.modelId,
    );
  }

  // ---------- Database ----------

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'title': title,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
      'pinned': pinned ? 1 : 0,
      'model_id': modelId,
    };
  }

  factory Chat.fromMap(Map<String, Object?> map) {
    return Chat(
      id: map['id'] as String,
      title: map['title'] as String? ?? 'New chat',
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        (map['created_at'] as int?) ?? 0,
      ),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        (map['updated_at'] as int?) ?? 0,
      ),
      pinned: ((map['pinned'] as int?) ?? 0) == 1,
      modelId: map['model_id'] as String? ?? 'auto',
    );
  }
}
