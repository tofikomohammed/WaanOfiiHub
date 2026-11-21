class PostComment {
  final String id;
  final String postId;
  final String userId;
  final String userName;
  final String? userAvatar;
  final String body;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final bool isHidden;
  final String? parentId;
  final List<PostComment> replies;

  const PostComment({
    required this.id,
    required this.postId,
    required this.userId,
    required this.userName,
    this.userAvatar,
    required this.body,
    required this.createdAt,
    this.updatedAt,
    this.isHidden = false,
    this.parentId,
    this.replies = const [],
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
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
      isHidden: json['is_hidden'] as bool? ?? false,
      parentId: json['parent_id'] as String?,
      replies: const [],
    );
  }

  PostComment copyWith({
    String? id,
    String? postId,
    String? userId,
    String? userName,
    String? userAvatar,
    String? body,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isHidden,
    String? parentId,
    List<PostComment>? replies,
  }) {
    return PostComment(
      id: id ?? this.id,
      postId: postId ?? this.postId,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userAvatar: userAvatar ?? this.userAvatar,
      body: body ?? this.body,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isHidden: isHidden ?? this.isHidden,
      parentId: parentId ?? this.parentId,
      replies: replies ?? this.replies,
    );
  }

  /// Builds a 2-level threaded comment tree from a flat list of comments.
  /// Any nested reply beyond depth 2 is flattened under the top-level root.
  static List<PostComment> buildTree(List<PostComment> flatComments) {
    final Map<String, List<PostComment>> repliesMap = {};
    final List<PostComment> topLevel = [];

    for (final c in flatComments) {
      if (c.parentId == null || c.parentId!.isEmpty) {
        topLevel.add(c);
      } else {
        repliesMap.putIfAbsent(c.parentId!, () => []).add(c);
      }
    }

    return topLevel.map((root) {
      final directReplies = repliesMap[root.id] ?? [];
      // Also collect any replies targeting directReplies to maintain sensible depth limit (depth 2)
      final allSubReplies = <PostComment>[...directReplies];
      for (final r in directReplies) {
        if (repliesMap.containsKey(r.id)) {
          allSubReplies.addAll(repliesMap[r.id]!);
        }
      }
      // Sort replies chronologically
      allSubReplies.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      return root.copyWith(replies: allSubReplies);
    }).toList();
  }
}
