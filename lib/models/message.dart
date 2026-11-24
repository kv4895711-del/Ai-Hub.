import 'dart:convert';

/// Who wrote a message.
enum MessageRole { user, assistant, system }

/// One message in a chat. Also knows how to be saved to / loaded from the database.
class ChatMessage {
  final String id;
  final String chatId;
  final MessageRole role;
  final String content;

  /// Which AI model wrote this answer (empty for user messages).
  final String modelName;

  final DateTime createdAt;

  /// True when this message is an error notice (shown in a different style).
  final bool isError;

  /// Files attached to this message, kept as plain maps so this file never
  /// needs to change (see Attachment.toJson in attachment.dart).
  final List<Map<String, dynamic>> attachments;

  /// True only while the answer is still being written (not saved to the database).
  final bool isStreaming;

  const ChatMessage({
    required this.id,
    required this.chatId,
    required this.role,
    required this.content,
    this.modelName = '',
    required this.createdAt,
    this.isError = false,
    this.attachments = const [],
    this.isStreaming = false,
  });

  bool get isUser => role == MessageRole.user;
  bool get isAssistant => role == MessageRole.assistant;
  bool get hasAttachments => attachments.isNotEmpty;

  ChatMessage copyWith({
    String? content,
    String? modelName,
    bool? isError,
    List<Map<String, dynamic>>? attachments,
    bool? isStreaming,
  }) {
    return ChatMessage(
      id: id,
      chatId: chatId,
      role: role,
      content: content ?? this.content,
      modelName: modelName ?? this.modelName,
      createdAt: createdAt,
      isError: isError ?? this.isError,
      attachments: attachments ?? this.attachments,
      isStreaming: isStreaming ?? this.isStreaming,
    );
  }

  // ---------- Database ----------

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'chat_id': chatId,
      'role': role.name,
      'content': content,
      'model_name': modelName,
      'created_at': createdAt.millisecondsSinceEpoch,
      'is_error': isError ? 1 : 0,
      'attachments': jsonEncode(attachments),
    };
  }

  factory ChatMessage.fromMap(Map<String, Object?> map) {
    List<Map<String, dynamic>> files = [];
    try {
      final raw = map['attachments'] as String?;
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          files = decoded
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        }
      }
    } catch (_) {
      files = [];
    }

    final roleName = map['role'] as String? ?? 'user';
    return ChatMessage(
      id: map['id'] as String,
      chatId: map['chat_id'] as String,
      role: MessageRole.values.firstWhere(
        (r) => r.name == roleName,
        orElse: () => MessageRole.user,
      ),
      content: map['content'] as String? ?? '',
      modelName: map['model_name'] as String? ?? '',
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        (map['created_at'] as int?) ?? 0,
      ),
      isError: ((map['is_error'] as int?) ?? 0) == 1,
      attachments: files,
    );
  }
}
