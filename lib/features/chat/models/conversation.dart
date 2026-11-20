/// Model representing direct, group, or community channel conversations
class Conversation {
  final String id;
  final String type; // 'direct', 'group', 'community'
  final String title;
  final String? avatarUrl;
  final String? description;
  final String? createdBy;
  final bool isAnnouncementOnly;
  final bool isOpen;
  final String? lastMessageText;
  final DateTime? lastMessageAt;
  final DateTime createdAt;
  final int unreadCount;

  const Conversation({
    required this.id,
    required this.type,
    required this.title,
    this.avatarUrl,
    this.description,
    this.createdBy,
    this.isAnnouncementOnly = false,
    this.isOpen = true,
    this.lastMessageText,
    this.lastMessageAt,
    required this.createdAt,
    this.unreadCount = 0,
  });

  factory Conversation.fromJson(
    Map<String, dynamic> json, {
    String? currentUserId,
  }) {
    String derivedTitle = json['title'] as String? ?? 'Conversation';

    // If direct chat and title is null, derive from direct user metadata if available
    if (json['type'] == 'direct' && json['other_user'] != null) {
      final other = json['other_user'] as Map<String, dynamic>;
      derivedTitle = other['display_name'] as String? ?? 'Direct Chat';
    }

    return Conversation(
      id: json['id'] as String,
      type: json['type'] as String? ?? 'direct',
      title: derivedTitle,
      avatarUrl: json['avatar_url'] as String?,
      description: json['description'] as String?,
      createdBy: json['created_by'] as String?,
      isAnnouncementOnly: json['is_announcement_only'] as bool? ?? false,
      isOpen: json['is_open'] as bool? ?? true,
      lastMessageText: json['last_message_text'] as String?,
      lastMessageAt: json['last_message_at'] != null
          ? DateTime.tryParse(json['last_message_at'] as String)
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      unreadCount: json['unread_count'] as int? ?? 0,
    );
  }
}
