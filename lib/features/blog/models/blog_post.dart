import 'post_media.dart';

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
  final String status; // 'draft', 'published', 'archived', 'scheduled'
  final DateTime? publishedAt;
  final DateTime? scheduledFor;
  final bool isPinned;
  final int likesCount;
  final int commentsCount;
  final int viewsCount;
  final bool isLikedByMe;
  final bool isBookmarkedByMe;
  final DateTime createdAt;
  final List<PostMedia> media;
  final List<String> tags;

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
    this.scheduledFor,
    this.isPinned = false,
    this.likesCount = 0,
    this.commentsCount = 0,
    this.viewsCount = 0,
    this.isLikedByMe = false,
    this.isBookmarkedByMe = false,
    required this.createdAt,
    this.media = const [],
    this.tags = const [],
  });

  bool get isScheduled => status == 'scheduled';

  String get categoryDisplayName => BlogCategories.getDisplayName(category);

  /// Estimated reading time in minutes (approx. 200 words per minute)
  int get readingTimeMinutes {
    final words = body.trim().isEmpty
        ? 0
        : body.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
    return (words / 200).ceil().clamp(1, 120);
  }

  List<PostMedia> get imageMedia =>
      media.where((m) => m.kind == 'image').toList()
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

  List<PostMedia> get audioMedia =>
      media.where((m) => m.kind == 'audio').toList();

  factory BlogPost.fromJson(
    Map<String, dynamic> json, {
    String? currentUserId,
    String? supabaseUrl,
  }) {
    final likes = json['post_likes'] as List<dynamic>? ?? [];
    final comments = json['post_comments'] as List<dynamic>? ?? [];
    final bookmarks = json['post_bookmarks'] as List<dynamic>? ?? [];
    final rawMedia = json['post_media'] as List<dynamic>? ?? [];
    final rawTags = json['tags'] as List<dynamic>? ?? [];
    final authorProfile = json['profiles'] as Map<String, dynamic>?;

    final isLiked =
        currentUserId != null &&
        likes.any(
          (l) => (l as Map<String, dynamic>)['user_id'] == currentUserId,
        );

    final isBookmarked =
        currentUserId != null &&
        bookmarks.any(
          (b) => (b as Map<String, dynamic>)['user_id'] == currentUserId,
        );

    final parsedMedia =
        rawMedia
            .map(
              (m) => PostMedia.fromJson(
                m as Map<String, dynamic>,
                supabaseUrl: supabaseUrl,
              ),
            )
            .toList()
          ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    final parsedTags = rawTags.map((t) => t.toString()).toList();
    final likesTotal = json['likes_count'] as int? ?? likes.length;
    final commentsTotal = json['comments_count'] as int? ?? comments.length;
    final viewsTotal = json['views_count'] as int? ?? 0;

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
      scheduledFor: json['scheduled_for'] != null
          ? DateTime.tryParse(json['scheduled_for'] as String)
          : null,
      isPinned: json['is_pinned'] as bool? ?? false,
      likesCount: likesTotal,
      commentsCount: commentsTotal,
      viewsCount: viewsTotal,
      isLikedByMe: isLiked,
      isBookmarkedByMe: isBookmarked,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      media: parsedMedia,
      tags: parsedTags,
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
    DateTime? scheduledFor,
    bool? isPinned,
    int? likesCount,
    bool? isLikedByMe,
    bool? isBookmarkedByMe,
    int? commentsCount,
    int? viewsCount,
    List<PostMedia>? media,
    List<String>? tags,
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
      scheduledFor: scheduledFor ?? this.scheduledFor,
      isPinned: isPinned ?? this.isPinned,
      likesCount: likesCount ?? this.likesCount,
      commentsCount: commentsCount ?? this.commentsCount,
      viewsCount: viewsCount ?? this.viewsCount,
      isLikedByMe: isLikedByMe ?? this.isLikedByMe,
      isBookmarkedByMe: isBookmarkedByMe ?? this.isBookmarkedByMe,
      createdAt: createdAt,
      media: media ?? this.media,
      tags: tags ?? this.tags,
    );
  }
}
