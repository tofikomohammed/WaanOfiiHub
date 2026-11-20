/// Immutable representation of a blog post
class BlogPost {
  final String id;
  final String authorId;
  final String? authorName;
  final String type; // 'text', 'image', 'audio'
  final String title;
  final String body;
  final String? coverUrl;
  final String status; // 'draft', 'published', 'archived'
  final DateTime? publishedAt;
  final bool isPinned;
  final int likesCount;
  final int commentsCount;
  final bool isLikedByMe;
  final DateTime createdAt;

  const BlogPost({
    required this.id,
    required this.authorId,
    this.authorName,
    required this.type,
    required this.title,
    this.body = '',
    this.coverUrl,
    required this.status,
    this.publishedAt,
    this.isPinned = false,
    this.likesCount = 0,
    this.commentsCount = 0,
    this.isLikedByMe = false,
    required this.createdAt,
  });

  factory BlogPost.fromJson(
    Map<String, dynamic> json, {
    String? currentUserId,
  }) {
    final likes = json['post_likes'] as List<dynamic>? ?? [];
    final comments = json['post_comments'] as List<dynamic>? ?? [];
    final authorProfile = json['profiles'] as Map<String, dynamic>?;

    final isLiked =
        currentUserId != null &&
        likes.any(
          (l) => (l as Map<String, dynamic>)['user_id'] == currentUserId,
        );

    return BlogPost(
      id: json['id'] as String,
      authorId: json['author_id'] as String,
      authorName: authorProfile?['display_name'] as String? ?? 'Admin',
      type: json['type'] as String? ?? 'text',
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      coverUrl: json['cover_url'] as String?,
      status: json['status'] as String? ?? 'draft',
      publishedAt: json['published_at'] != null
          ? DateTime.tryParse(json['published_at'] as String)
          : null,
      isPinned: json['is_pinned'] as bool? ?? false,
      likesCount: likes.length,
      commentsCount: comments.length,
      isLikedByMe: isLiked,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  BlogPost copyWith({int? likesCount, bool? isLikedByMe, int? commentsCount}) {
    return BlogPost(
      id: id,
      authorId: authorId,
      authorName: authorName,
      type: type,
      title: title,
      body: body,
      coverUrl: coverUrl,
      status: status,
      publishedAt: publishedAt,
      isPinned: isPinned,
      likesCount: likesCount ?? this.likesCount,
      commentsCount: commentsCount ?? this.commentsCount,
      isLikedByMe: isLikedByMe ?? this.isLikedByMe,
      createdAt: createdAt,
    );
  }
}
