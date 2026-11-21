/// Categories supported by WAAN-OFIIHUB blog system
class BlogCategories {
  static const String education = 'education';
  static const String technology = 'technology';
  static const String health = 'health';
  static const String community = 'community';
  static const String agriculture = 'agriculture';
  static const String business = 'business';
  static const String ethics = 'ethics';
  static const String news = 'news';

  static const List<String> all = [
    education,
    technology,
    health,
    community,
    agriculture,
    business,
    ethics,
    news,
  ];

  static String getDisplayName(String key) {
    switch (key) {
      case education:
        return 'Education';
      case technology:
        return 'Technology & Innovation';
      case health:
        return 'Health & Wellness';
      case community:
        return 'Community Development';
      case agriculture:
        return 'Agriculture';
      case business:
        return 'Business & Entrepreneurship';
      case ethics:
        return 'Ethics & Good Deeds';
      case news:
      default:
        return 'News & Updates';
    }
  }
}

/// Immutable representation of a blog post
class BlogPost {
  final String id;
  final String authorId;
  final String? authorName;
  final String type; // 'text', 'image', 'audio'
  final String category; // 'education', 'technology', 'health', 'community', 'agriculture', 'business', 'ethics', 'news'
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
    this.category = BlogCategories.news,
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

  String get categoryDisplayName => BlogCategories.getDisplayName(category);

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
      category: json['category'] as String? ?? BlogCategories.news,
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

  BlogPost copyWith({
    String? title,
    String? body,
    String? type,
    String? category,
    String? coverUrl,
    String? status,
    DateTime? publishedAt,
    bool? isPinned,
    int? likesCount,
    bool? isLikedByMe,
    int? commentsCount,
  }) {
    return BlogPost(
      id: id,
      authorId: authorId,
      authorName: authorName,
      type: type ?? this.type,
      category: category ?? this.category,
      title: title ?? this.title,
      body: body ?? this.body,
      coverUrl: coverUrl ?? this.coverUrl,
      status: status ?? this.status,
      publishedAt: publishedAt ?? this.publishedAt,
      isPinned: isPinned ?? this.isPinned,
      likesCount: likesCount ?? this.likesCount,
      commentsCount: commentsCount ?? this.commentsCount,
      isLikedByMe: isLikedByMe ?? this.isLikedByMe,
      createdAt: createdAt,
    );
  }
}
