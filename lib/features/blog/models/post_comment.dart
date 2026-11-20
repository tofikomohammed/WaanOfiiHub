class PostComment {
  final String id;
  final String postId;
  final String userId;
  final String userName;
  final String? userAvatar;
  final String body;
  final DateTime createdAt;
  final bool isHidden;

  const PostComment({
    required this.id,
    required this.postId,
    required this.userId,
    required this.userName,
    this.userAvatar,
    required this.body,
    required this.createdAt,
    this.isHidden = false,
  });

  factory PostComment.fromJson(Map<String, dynamic> json) {
    final profile = json['profiles'] as Map<String, dynamic>?;
    return PostComment(
      id: json['id'] as String,
      postId: json['post_id'] as String,
      userId: json['user_id'] as String,
      userName: profile?['display_name'] as String? ?? 'User',
      userAvatar: profile?['avatar_url'] as String?,
      body: json['body'] as String? ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      isHidden: json['is_hidden'] as bool? ?? false,
    );
  }
}
