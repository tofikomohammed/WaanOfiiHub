import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/env_config.dart';
import '../../../core/config/supabase_config.dart';
import '../models/blog_category.dart';
import '../models/blog_post.dart';
import '../models/blog_tag.dart';
import '../models/post_comment.dart';
import '../models/post_media.dart';
import '../utils/content_sanitizer.dart';
import 'blog_storage_service.dart';

class BlogRepository {
  final SupabaseClient? _client;

  BlogRepository(this._client);

  String? get currentUserId => _client?.auth.currentUser?.id;
  String get supabaseUrl => EnvConfig.supabaseUrl;

  /// Fetch published posts with optional category, type, tag, date and search filtering
  Future<List<BlogPost>> getPublishedPosts({
    String? category,
    String? searchQuery,
    String? postType,
    String? tag,
    DateTime? dateFrom,
    String sortBy = 'latest',
    int limit = 20,
    int offset = 0,
  }) async {
    if (_client == null) return [];
    final uid = currentUserId;

    var query = _client
        .from('posts')
        .select(
          '*, profiles:author_id(display_name, avatar_url), post_likes(user_id), post_bookmarks(user_id), post_media(*)',
        )
        .eq('status', 'published');

    if (category != null && category.isNotEmpty && category != 'all') {
      query = query.eq('category', category);
    }

    if (postType != null && postType.isNotEmpty && postType != 'all') {
      query = query.eq('type', postType);
    }

    if (tag != null && tag.isNotEmpty && tag != 'all') {
      query = query.contains('tags', [tag.toLowerCase()]);
    }

    if (dateFrom != null) {
      query = query.gte('published_at', dateFrom.toIso8601String());
    }

    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      final term = searchQuery.trim();
      List<String> authorIds = [];
      try {
        final authorRows = await _client
            .from('profiles')
            .select('id')
            .ilike('display_name', '%$term%');
        authorIds = (authorRows as List).map((a) => a['id'] as String).toList();
      } catch (_) {}

      if (authorIds.isNotEmpty) {
        final idsList = authorIds.join(',');
        query = query.or(
          'title.ilike.%$term%,body.ilike.%$term%,author_id.in.($idsList)',
        );
      } else {
        query = query.or('title.ilike.%$term%,body.ilike.%$term%');
      }
    }

    // Sorting (Requirement 4)
    var orderedQuery = query.order('is_pinned', ascending: false);
    if (sortBy == 'likes') {
      orderedQuery = orderedQuery
          .order('likes_count', ascending: false)
          .order('published_at', ascending: false);
    } else if (sortBy == 'comments') {
      orderedQuery = orderedQuery
          .order('comments_count', ascending: false)
          .order('published_at', ascending: false);
    } else {
      orderedQuery = orderedQuery.order('published_at', ascending: false);
    }

    final res = await orderedQuery.range(offset, offset + limit - 1);

    return (res as List)
        .map(
          (e) => BlogPost.fromJson(
            e,
            currentUserId: uid,
            supabaseUrl: supabaseUrl,
          ),
        )
        .toList();
  }

  static String? _clientSessionId;
  String _getSessionHash() {
    _clientSessionId ??= DateTime.now().microsecondsSinceEpoch.toString();
    return _clientSessionId!;
  }

  /// Fetch private drafts and scheduled posts created by the current user
  Future<List<BlogPost>> getMyDrafts() async {
    if (_client == null) return [];
    final uid = currentUserId;
    if (uid == null) return [];

    final res = await _client
        .from('posts')
        .select(
          '*, profiles:author_id(display_name, avatar_url), post_likes(user_id), post_bookmarks(user_id), post_media(*)',
        )
        .eq('author_id', uid)
        .inFilter('status', ['draft', 'scheduled'])
        .order('created_at', ascending: false);

    return (res as List)
        .map(
          (e) => BlogPost.fromJson(
            e,
            currentUserId: uid,
            supabaseUrl: supabaseUrl,
          ),
        )
        .toList();
  }

  /// Record post view deduplicated by session and viewer (6-hour window, ignores author)
  Future<bool> recordPostView(String postId, {String? sessionHash}) async {
    if (_client == null) return false;
    try {
      final res = await _client.rpc(
        'record_post_view',
        params: {
          'p_post_id': postId,
          'p_session_hash': sessionHash ?? _getSessionHash(),
        },
      );
      return res as bool? ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Get single post by ID
  Future<BlogPost?> getPostById(String id) async {
    if (_client == null) return null;
    final uid = currentUserId;

    final res = await _client
        .from('posts')
        .select(
          '*, profiles:author_id(display_name, avatar_url), post_likes(user_id), post_bookmarks(user_id), post_media(*)',
        )
        .eq('id', id)
        .maybeSingle();

    if (res == null) return null;
    return BlogPost.fromJson(res, currentUserId: uid, supabaseUrl: supabaseUrl);
  }

  /// Toggle like on post
  Future<void> toggleLike(String postId, bool isLiked) async {
    if (_client == null) return;
    final uid = currentUserId;
    if (uid == null) return;

    if (isLiked) {
      await _client.from('post_likes').delete().match({
        'post_id': postId,
        'user_id': uid,
      });
    } else {
      await _client.from('post_likes').insert({
        'post_id': postId,
        'user_id': uid,
      });
    }
  }

  /// Toggle bookmark on post
  Future<void> toggleBookmark(String postId, bool isBookmarked) async {
    if (_client == null) return;
    final uid = currentUserId;
    if (uid == null) return;

    if (isBookmarked) {
      await _client.from('post_bookmarks').delete().match({
        'post_id': postId,
        'user_id': uid,
      });
    } else {
      await _client.from('post_bookmarks').insert({
        'post_id': postId,
        'user_id': uid,
      });
    }
  }

  /// Get bookmarked posts for the current user
  Future<List<BlogPost>> getBookmarkedPosts() async {
    if (_client == null) return [];
    final uid = currentUserId;
    if (uid == null) return [];

    final res = await _client
        .from('post_bookmarks')
        .select(
          'posts(*, profiles:posts.author_id(display_name, avatar_url), post_likes(user_id), post_bookmarks(user_id), post_media(*))',
        )
        .eq('user_id', uid)
        .order('created_at', ascending: false);

    return (res as List)
        .where((e) => e['posts'] != null)
        .map(
          (e) => BlogPost.fromJson(
            e['posts'] as Map<String, dynamic>,
            currentUserId: uid,
            supabaseUrl: supabaseUrl,
          ),
        )
        .toList();
  }

  /// Report a post for moderation
  Future<void> reportPost({
    required String postId,
    required String reason,
    String? details,
  }) async {
    if (_client == null) return;
    final uid = currentUserId;
    if (uid == null) return;

    await _client.from('reports').insert({
      'reporter_id': uid,
      'post_id': postId,
      'reason': reason.trim(),
      'details': details != null
          ? ContentSanitizer.sanitizeComment(details)
          : null,
      'status': 'open',
    });
  }

  /// Report a comment for moderation
  Future<void> reportComment({
    required String commentId,
    required String postId,
    required String reason,
    String? details,
  }) async {
    if (_client == null) return;
    final uid = currentUserId;
    if (uid == null) return;

    await _client.from('reports').insert({
      'reporter_id': uid,
      'post_id': postId,
      'comment_id': commentId,
      'reason': reason.trim(),
      'details': details != null
          ? ContentSanitizer.sanitizeComment(details)
          : null,
      'status': 'open',
    });
  }

  /// Fetch comments for a post (RLS automatically handles visibility of hidden comments)
  Future<List<PostComment>> getComments(String postId) async {
    if (_client == null) return [];
    final res = await _client
        .from('post_comments')
        .select('*, profiles:user_id(display_name, avatar_url)')
        .eq('post_id', postId)
        .order('created_at', ascending: true);

    return (res as List).map((e) => PostComment.fromJson(e)).toList();
  }

  /// Add comment or reply to post with input sanitization
  Future<void> addComment(
    String postId,
    String body, {
    String? parentId,
  }) async {
    if (_client == null) return;
    final uid = currentUserId;
    if (uid == null) return;

    final sanitized = ContentSanitizer.sanitizeComment(body);
    if (sanitized.isEmpty) return;

    final insertData = <String, dynamic>{
      'post_id': postId,
      'user_id': uid,
      'body': sanitized,
    };
    if (parentId != null && parentId.isNotEmpty) {
      insertData['parent_id'] = parentId;
    }

    await _client.from('post_comments').insert(insertData);
  }

  /// Update own comment
  Future<void> updateComment(String commentId, String newBody) async {
    if (_client == null) return;
    final sanitized = ContentSanitizer.sanitizeComment(newBody);
    if (sanitized.isEmpty) return;

    await _client
        .from('post_comments')
        .update({
          'body': sanitized,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', commentId);
  }

  /// Delete own comment
  Future<void> deleteComment(String commentId) async {
    if (_client == null) return;
    await _client.from('post_comments').delete().eq('id', commentId);
  }

  /// Admin hide or unhide comment (recorded in audit logs)
  Future<void> adminHideComment(String commentId, bool hide) async {
    if (_client == null) return;
    await _client.rpc(
      'admin_hide_comment',
      params: {'p_comment_id': commentId, 'p_hide': hide},
    );
  }

  /// Admin delete comment (recorded in audit logs)
  Future<void> adminDeleteComment(String commentId) async {
    if (_client == null) return;
    await _client.rpc(
      'admin_delete_comment',
      params: {'p_comment_id': commentId},
    );
  }

  /// Admin delete post (recorded in audit logs)
  Future<void> adminDeletePost(String postId) async {
    if (_client == null) return;
    await _client.rpc('admin_delete_post', params: {'p_post_id': postId});
  }

  /// Admin publish / unpublish post (recorded in audit logs)
  Future<void> adminSetPublishStatus(String postId, bool publish) async {
    if (_client == null) return;
    await _client.rpc(
      'admin_set_publish_status',
      params: {'p_post_id': postId, 'p_publish': publish},
    );
  }

  /// Schedule a post for future publication
  Future<void> schedulePost(String postId, DateTime scheduledFor) async {
    if (_client == null) return;
    await _client
        .from('posts')
        .update({
          'status': 'scheduled',
          'scheduled_for': scheduledFor.toUtc().toIso8601String(),
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', postId);
  }

  /// Cancel scheduled post, reverting to draft
  Future<void> cancelScheduledPost(String postId) async {
    if (_client == null) return;
    await _client
        .from('posts')
        .update({
          'status': 'draft',
          'scheduled_for': null,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', postId);
  }

  /// Fetch moderation reports for admins
  Future<List<Map<String, dynamic>>> getModerationReports({
    String? status = 'open',
  }) async {
    if (_client == null) return [];
    var query = _client
        .from('reports')
        .select(
          '*, reporter:reporter_id(display_name, avatar_url), post:post_id(title, status), comment:comment_id(body, is_hidden)',
        );
    if (status != null && status.isNotEmpty && status != 'all') {
      query = query.eq('status', status);
    }
    final res = await query.order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(res as List);
  }

  /// Admin action moderation report (dismiss, action_hide, action_delete)
  Future<void> adminActionReport(String reportId, String action) async {
    if (_client == null) return;
    await _client.rpc(
      'admin_action_report',
      params: {'p_report_id': reportId, 'p_action': action},
    );
  }

  /// Create a new post with optional gallery media, scheduling, and content sanitization
  Future<String?> createPost({
    required String title,
    required String body,
    required String type,
    String category = BlogCategories.news,
    String? coverUrl,
    bool publishNow = true,
    DateTime? scheduledFor,
    List<UploadedMediaItem> galleryMedia = const [],
    List<String> tags = const [],
  }) async {
    if (_client == null) return null;
    final uid = currentUserId;
    if (uid == null) return null;

    final sanitizedTitle = ContentSanitizer.sanitizeTitle(title);
    final sanitizedBody = ContentSanitizer.sanitizeBody(body);
    final cleanedTags = ContentSanitizer.sanitizeTags(tags);

    final isScheduled =
        scheduledFor != null && scheduledFor.isAfter(DateTime.now());
    final status = isScheduled
        ? 'scheduled'
        : (publishNow ? 'published' : 'draft');
    final publishedAt = (publishNow && !isScheduled)
        ? DateTime.now().toUtc().toIso8601String()
        : null;
    final scheduledForIso = isScheduled
        ? scheduledFor.toUtc().toIso8601String()
        : null;

    final res = await _client
        .from('posts')
        .insert({
          'author_id': uid,
          'title': sanitizedTitle,
          'body': sanitizedBody,
          'type': type,
          'category': category,
          'tags': cleanedTags,
          'cover_url': coverUrl,
          'status': status,
          'published_at': publishedAt,
          'scheduled_for': scheduledForIso,
        })
        .select('id')
        .single();

    final newPostId = res['id'] as String;

    // Attach gallery media items if any
    if (galleryMedia.isNotEmpty) {
      final mediaRows = galleryMedia.asMap().entries.map((entry) {
        final index = entry.key;
        final item = entry.value;
        return {
          'post_id': newPostId,
          'kind': item.kind,
          'storage_path': item.storagePath,
          'mime': item.mime,
          'size_bytes': item.sizeBytes,
          'duration_seconds': item.durationSeconds,
          'sort_order': index,
        };
      }).toList();

      await _client.from('post_media').insert(mediaRows);
    }

    return newPostId;
  }

  /// Update an existing post with content sanitization and scheduling support
  Future<void> updatePost({
    required String id,
    required String title,
    required String body,
    required String type,
    required String category,
    String? coverUrl,
    bool? isPinned,
    String? status,
    DateTime? scheduledFor,
    List<UploadedMediaItem> newMediaItems = const [],
    List<String>? tags,
  }) async {
    if (_client == null) return;

    final updates = <String, dynamic>{
      'title': ContentSanitizer.sanitizeTitle(title),
      'body': ContentSanitizer.sanitizeBody(body),
      'type': type,
      'category': category,
      'cover_url': coverUrl,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };

    if (tags != null) {
      updates['tags'] = ContentSanitizer.sanitizeTags(tags);
    }

    if (isPinned != null) updates['is_pinned'] = isPinned;
    if (scheduledFor != null) {
      updates['scheduled_for'] = scheduledFor.toUtc().toIso8601String();
      updates['status'] = 'scheduled';
    } else if (status != null) {
      updates['status'] = status;
      if (status == 'published') {
        updates['published_at'] = DateTime.now().toUtc().toIso8601String();
        updates['scheduled_for'] = null;
      } else if (status == 'draft') {
        updates['scheduled_for'] = null;
      }
    }

    await _client.from('posts').update(updates).eq('id', id);

    // Insert any new gallery media items
    if (newMediaItems.isNotEmpty) {
      final currentMedia = await _client
          .from('post_media')
          .select('sort_order')
          .eq('post_id', id)
          .order('sort_order', ascending: false)
          .limit(1);

      int highestSort = 0;
      if ((currentMedia as List).isNotEmpty) {
        highestSort = (currentMedia.first['sort_order'] as num).toInt() + 1;
      }

      final mediaRows = newMediaItems.asMap().entries.map((entry) {
        final item = entry.value;
        return {
          'post_id': id,
          'kind': item.kind,
          'storage_path': item.storagePath,
          'mime': item.mime,
          'size_bytes': item.sizeBytes,
          'duration_seconds': item.durationSeconds,
          'sort_order': highestSort + entry.key,
        };
      }).toList();

      await _client.from('post_media').insert(mediaRows);
    }
  }

  /// Delete a post and safely clean up all its media files in Supabase Storage
  Future<void> deletePost(String id) async {
    if (_client == null) return;

    // 1. Collect all storage paths to clean up
    final pathsToDelete = <String>[];

    try {
      final postData = await _client
          .from('posts')
          .select('cover_url, author_id')
          .eq('id', id)
          .maybeSingle();

      if (postData != null && postData['cover_url'] != null) {
        final coverUrl = postData['cover_url'] as String;
        if (coverUrl.contains('/blog-media/')) {
          final relativePath = coverUrl.split('/blog-media/').last;
          if (relativePath.isNotEmpty) pathsToDelete.add(relativePath);
        }
      }

      final mediaData = await _client
          .from('post_media')
          .select('storage_path')
          .eq('post_id', id);

      for (final m in (mediaData as List)) {
        final path = m['storage_path'] as String?;
        if (path != null && path.isNotEmpty) pathsToDelete.add(path);
      }
    } catch (_) {}

    // 2. Delete database record (cascades to post_media, post_likes, post_comments)
    await _client.from('posts').delete().eq('id', id);

    // 3. Remove orphaned files from storage bucket
    if (pathsToDelete.isNotEmpty) {
      try {
        await _client.storage.from('blog-media').remove(pathsToDelete);
      } catch (_) {}
    }
  }

  /// Remove single media item from post_media and Storage
  Future<void> deletePostMedia(String mediaId, String storagePath) async {
    if (_client == null) return;
    await _client.from('post_media').delete().eq('id', mediaId);
    if (storagePath.isNotEmpty) {
      try {
        await _client.storage.from('blog-media').remove([storagePath]);
      } catch (_) {}
    }
  }

  /// Reorder media items in post_media
  Future<void> updateMediaOrder(List<PostMedia> reorderedMedia) async {
    if (_client == null) return;
    for (int i = 0; i < reorderedMedia.length; i++) {
      final item = reorderedMedia[i];
      await _client
          .from('post_media')
          .update({'sort_order': i})
          .eq('id', item.id);
    }
  }

  /// Set specific media as post cover
  Future<void> setPostCover(String postId, String coverUrl) async {
    if (_client == null) return;
    await _client
        .from('posts')
        .update({
          'cover_url': coverUrl,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', postId);
  }

  /// Directly update status of post
  Future<void> setPostStatus(String id, String status) async {
    if (_client == null) return;
    final updates = <String, dynamic>{
      'status': status,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    if (status == 'published') {
      updates['published_at'] = DateTime.now().toUtc().toIso8601String();
    }
    await _client.from('posts').update(updates).eq('id', id);
  }

  /// Toggle pin status on a post
  Future<void> togglePinPost(String id, bool isPinned) async {
    if (_client == null) return;
    await _client
        .from('posts')
        .update({
          'is_pinned': isPinned,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', id);
  }

  /// Fetch all posts across authors for administrative oversight
  Future<List<BlogPost>> getAllPostsAdmin({
    String? status,
    String? type,
    String? searchQuery,
    int limit = 50,
    int offset = 0,
  }) async {
    if (_client == null) return [];
    final uid = currentUserId;

    var query = _client
        .from('posts')
        .select(
          '*, profiles:author_id(display_name, avatar_url), post_likes(user_id), post_bookmarks(user_id), post_media(*)',
        );

    if (status != null && status.isNotEmpty && status != 'all') {
      query = query.eq('status', status);
    }

    if (type != null && type.isNotEmpty && type != 'all') {
      query = query.eq('type', type);
    }

    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      final term = searchQuery.trim();
      query = query.or('title.ilike.%$term%,body.ilike.%$term%');
    }

    final res = await query
        .order('is_pinned', ascending: false)
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);

    return (res as List)
        .map(
          (e) => BlogPost.fromJson(
            e,
            currentUserId: uid,
            supabaseUrl: supabaseUrl,
          ),
        )
        .toList();
  }

  /// Fetch related posts based on matching category or shared tags, excluding the current post
  Future<List<BlogPost>> getRelatedPosts({
    required String postId,
    required String category,
    List<String> tags = const [],
    int limit = 3,
  }) async {
    if (_client == null) return [];
    final uid = currentUserId;

    var query = _client
        .from('posts')
        .select(
          '*, profiles:author_id(display_name, avatar_url), post_likes(user_id), post_comments(id), post_media(*)',
        )
        .eq('status', 'published')
        .neq('id', postId);

    if (category.isNotEmpty) {
      query = query.eq('category', category);
    }

    final res = await query
        .order('published_at', ascending: false)
        .limit(limit);

    return (res as List)
        .map(
          (e) => BlogPost.fromJson(
            e,
            currentUserId: uid,
            supabaseUrl: supabaseUrl,
          ),
        )
        .toList();
  }

  /// Get all categories
  Future<List<BlogCategory>> getCategories() async {
    if (_client == null) return [];
    final res = await _client
        .from('blog_categories')
        .select('*')
        .order('name', ascending: true);
    return (res as List).map((c) => BlogCategory.fromJson(c)).toList();
  }

  /// Create new category
  Future<void> createCategory({
    required String name,
    required String slug,
    String? description,
  }) async {
    if (_client == null) return;
    await _client.from('blog_categories').insert({
      'name': name.trim(),
      'slug': slug.trim().toLowerCase(),
      'description': description?.trim(),
    });
  }

  /// Rename existing category
  Future<void> renameCategory({
    required String id,
    required String newName,
    required String newSlug,
  }) async {
    if (_client == null) return;
    await _client
        .from('blog_categories')
        .update({'name': newName.trim(), 'slug': newSlug.trim().toLowerCase()})
        .eq('id', id);
  }

  /// Merge source category into target category and reassign all posts
  Future<void> mergeCategories({
    required String sourceSlug,
    required String targetSlug,
  }) async {
    if (_client == null) return;
    await _client.rpc(
      'merge_blog_categories',
      params: {'p_source_slug': sourceSlug, 'p_target_slug': targetSlug},
    );
  }

  /// Safely delete category, reassigning existing posts to fallback
  Future<void> deleteCategory({
    required String slug,
    String fallbackSlug = 'news',
  }) async {
    if (_client == null) return;
    await _client.rpc(
      'delete_blog_category',
      params: {'p_slug_to_delete': slug, 'p_fallback_slug': fallbackSlug},
    );
  }

  /// Get all tags
  Future<List<BlogTag>> getTags() async {
    if (_client == null) return [];
    final res = await _client
        .from('blog_tags')
        .select('*')
        .order('name', ascending: true);
    return (res as List).map((t) => BlogTag.fromJson(t)).toList();
  }

  /// Create new tag
  Future<void> createTag(String name) async {
    if (_client == null) return;
    final clean = name.trim().toLowerCase();
    await _client.from('blog_tags').insert({
      'name': name.trim(),
      'slug': clean.replaceAll(RegExp(r'\s+'), '-'),
    });
  }

  /// Rename existing tag
  Future<void> renameTag({
    required String id,
    required String newName,
    required String newSlug,
  }) async {
    if (_client == null) return;
    await _client
        .from('blog_tags')
        .update({'name': newName.trim(), 'slug': newSlug.trim().toLowerCase()})
        .eq('id', id);
  }

  /// Merge source tag into target tag and reassign in all posts
  Future<void> mergeTags({
    required String sourceName,
    required String targetName,
  }) async {
    if (_client == null) return;
    await _client.rpc(
      'merge_blog_tags',
      params: {'p_source_name': sourceName, 'p_target_name': targetName},
    );
  }

  /// Safely delete tag from database and post tag arrays
  Future<void> deleteTag(String tagName) async {
    if (_client == null) return;
    await _client.rpc('delete_blog_tag', params: {'p_tag_name': tagName});
  }
}

final blogRepositoryProvider = Provider<BlogRepository>((ref) {
  final client = isSupabaseInitialized
      ? ref.watch(supabaseClientProvider)
      : null;
  return BlogRepository(client);
});

/// Filter state providers
final selectedBlogCategoryProvider = StateProvider<String>((ref) => 'all');
final selectedBlogTypeProvider = StateProvider<String>((ref) => 'all');
final selectedBlogTagProvider = StateProvider<String?>((ref) => null);
final selectedBlogDateFilterProvider = StateProvider<String>((ref) => 'all');
final selectedBlogSortProvider = StateProvider<String>((ref) => 'latest');
final blogSearchQueryProvider = StateProvider<String>((ref) => '');

/// Taxonomies providers
final categoriesListProvider = FutureProvider<List<BlogCategory>>((ref) async {
  return ref.watch(blogRepositoryProvider).getCategories();
});

final tagsListProvider = FutureProvider<List<BlogTag>>((ref) async {
  return ref.watch(blogRepositoryProvider).getTags();
});

/// Related posts provider for post detail screen
final relatedPostsProvider = FutureProvider.family<List<BlogPost>, BlogPost>((
  ref,
  post,
) async {
  return ref
      .watch(blogRepositoryProvider)
      .getRelatedPosts(
        postId: post.id,
        category: post.category,
        tags: post.tags,
      );
});

/// Published blog feed provider reactive to all combined filters and search query
final blogFeedProvider = FutureProvider<List<BlogPost>>((ref) async {
  final repo = ref.watch(blogRepositoryProvider);
  final category = ref.watch(selectedBlogCategoryProvider);
  final type = ref.watch(selectedBlogTypeProvider);
  final tag = ref.watch(selectedBlogTagProvider);
  final dateFilter = ref.watch(selectedBlogDateFilterProvider);
  final sortBy = ref.watch(selectedBlogSortProvider);
  final query = ref.watch(blogSearchQueryProvider);

  DateTime? dateFrom;
  if (dateFilter == 'today') {
    dateFrom = DateTime.now().subtract(const Duration(days: 1));
  } else if (dateFilter == 'week') {
    dateFrom = DateTime.now().subtract(const Duration(days: 7));
  } else if (dateFilter == 'month') {
    dateFrom = DateTime.now().subtract(const Duration(days: 30));
  } else if (dateFilter == 'year') {
    dateFrom = DateTime.now().subtract(const Duration(days: 365));
  }

  return repo.getPublishedPosts(
    category: category == 'all' ? null : category,
    postType: type == 'all' ? null : type,
    tag: tag,
    dateFrom: dateFrom,
    sortBy: sortBy,
    searchQuery: query.isEmpty ? null : query,
  );
});

/// Drafts provider
final myDraftsProvider = FutureProvider<List<BlogPost>>((ref) async {
  final repo = ref.watch(blogRepositoryProvider);
  return repo.getMyDrafts();
});

/// Bookmarks provider
final myBookmarksProvider = FutureProvider<List<BlogPost>>((ref) async {
  final repo = ref.watch(blogRepositoryProvider);
  return repo.getBookmarkedPosts();
});

/// Moderation reports provider for admin queue
final moderationReportsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((
      ref,
      status,
    ) async {
      final repo = ref.watch(blogRepositoryProvider);
      return repo.getModerationReports(status: status);
    });

/// Immutable filter parameter for admin post management
class AdminPostsFilter {
  final String status;
  final String type;
  final String searchQuery;

  const AdminPostsFilter({
    this.status = 'all',
    this.type = 'all',
    this.searchQuery = '',
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AdminPostsFilter &&
          runtimeType == other.runtimeType &&
          status == other.status &&
          type == other.type &&
          searchQuery == other.searchQuery;

  @override
  int get hashCode => Object.hash(status, type, searchQuery);
}

/// Admin posts provider
final adminPostsProvider =
    FutureProvider.family<List<BlogPost>, AdminPostsFilter>((
      ref,
      filter,
    ) async {
      final repo = ref.watch(blogRepositoryProvider);
      return repo.getAllPostsAdmin(
        status: filter.status,
        type: filter.type,
        searchQuery: filter.searchQuery,
      );
    });
