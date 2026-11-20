/// Model representing individual chat messages
class ChatMessage {
  final String id;
  final String conversationId;
  final String senderId;
  final String? senderName;
  final String type; // 'text', 'image', 'audio', 'system'
  final String body;
  final String? mediaPath;
  final String? mediaMime;
  final int? mediaSize;
  final int? mediaDurationSeconds;
  final String? replyToId;
  final DateTime createdAt;
  final DateTime? editedAt;
  final bool deletedForEveryone;
  final bool isDelivered;
  final bool isRead;

  const ChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    this.senderName,
    required this.type,
    required this.body,
    this.mediaPath,
    this.mediaMime,
    this.mediaSize,
    this.mediaDurationSeconds,
    this.replyToId,
    required this.createdAt,
    this.editedAt,
    this.deletedForEveryone = false,
    this.isDelivered = true,
    this.isRead = false,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    final senderProfile = json['profiles'] as Map<String, dynamic>?;
    return ChatMessage(
      id: json['id'] as String,
      conversationId: json['conversation_id'] as String,
      senderId: json['sender_id'] as String,
      senderName: senderProfile?['display_name'] as String?,
      type: json['type'] as String? ?? 'text',
      body: json['body'] as String? ?? '',
      mediaPath: json['media_path'] as String?,
      mediaMime: json['media_mime'] as String?,
      mediaSize: json['media_size'] as int?,
      mediaDurationSeconds: json['media_duration_seconds'] as int?,
      replyToId: json['reply_to_id'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      editedAt: json['edited_at'] != null
          ? DateTime.tryParse(json['edited_at'] as String)
          : null,
      deletedForEveryone: json['deleted_for_everyone'] as bool? ?? false,
    );
  }
}
