import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/env_config.dart';
import '../../../core/config/supabase_config.dart';
import '../models/blog_post.dart';
import '../models/post_comment.dart';
import '../models/post_media.dart';
import 'blog_storage_service.dart';

class BlogRepository {
  final SupabaseClient? _client;

  BlogRepository(this._client);

  String? get currentUserId => _client?.auth.currentUser?.id;
  String get supabaseUrl => EnvConfig.supabaseUrl;

  /// Fetch published posts with optional category and search filtering
  Future<List<BlogPost>> getPublishedPosts({
    String? category,
    String? searchQuery,
    int limit = 20,
    int offset = 0,
  }) async {
    if (_client == null) return [];
    final uid = currentUserId;

    var query = _client
        .from('posts')
        .select(
          '*, profiles:author_id(display_name, avatar_url), post_likes(user_id), post_comments(id), post_media(*)',
        )
        .eq('status', 'published');

    if (category != null && category.isNotEmpty && category != 'all') {
      query = query.eq('category', category);
    }

    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      final term = searchQuery.trim();
      query = query.or('title.ilike.%$term%,body.ilike.%$term%');
    }

    final res = await query
        .order('is_pinned', ascending: false)
        .order('published_at', ascending: false)
        .range(offset, offset + limit - 1);

    return (res as List)
        .map((e) => BlogPost.fromJson(
              e,
              currentUserId: uid,
              supabaseUrl: supabaseUrl,
            ))
        .toList();
  }

  /// Fetch private drafts created by the current user
  Future<List<BlogPost>> getMyDrafts() async {
    if (_client == null) return [];
    final uid = currentUserId;
    if (uid == null) return [];

    final res = await _client
        .from('posts')
        .select(
          '*, profiles:author_id(display_name, avatar_url), post_likes(user_id), post_comments(id), post_media(*)',
        )
        .eq('author_id', uid)
        .eq('status', 'draft')
        .order('created_at', ascending: false);

    return (res as List)
        .map((e) => BlogPost.fromJson(
              e,
              currentUserId: uid,
              supabaseUrl: supabaseUrl,
            ))
        .toList();
  }

  /// Get single post by ID
  Future<BlogPost?> getPostById(String id) async {
    if (_client == null) return null;
    final uid = currentUserId;

    final res = await _client
        .from('posts')
        .select(
          '*, profiles:author_id(display_name, avatar_url), post_likes(user_id), post_comments(id), post_media(*)',
        )
        .eq('id', id)
        .maybeSingle();

    if (res == null) return null;
    return BlogPost.fromJson(
      res,
      currentUserId: uid,
      supabaseUrl: supabaseUrl,
    );
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

  /// Fetch comments for a post
  Future<List<PostComment>> getComments(String postId) async {
    if (_client == null) return [];
    final res = await _client
        .from('post_comments')
        .select('*, profiles:user_id(display_name, avatar_url)')
        .eq('post_id', postId)
        .eq('is_hidden', false)
        .order('created_at', ascending: true);

    return (res as List).map((e) => PostComment.fromJson(e)).toList();
  }

  /// Add comment to post
  Future<void> addComment(String postId, String body) async {
    if (_client == null) return;
    final uid = currentUserId;
    if (uid == null) return;

    await _client.from('post_comments').insert({
      'post_id': postId,
      'user_id': uid,
      'body': body.trim(),
    });
  }

  /// Create a new post with optional gallery media items
  Future<String?> createPost({
    required String title,
    required String body,
    required String type,
    String category = BlogCategories.news,
    String? coverUrl,
    bool publishNow = true,
    List<UploadedMediaItem> galleryMedia = const [],
  }) async {
    if (_client == null) return null;
    final uid = currentUserId;
    if (uid == null) return null;

    final res = await _client.from('posts').insert({
      'author_id': uid,
      'title': title.trim(),
      'body': body.trim(),
      'type': type,
      'category': category,
      'cover_url': coverUrl,
      'status': publishNow ? 'published' : 'draft',
      'published_at': publishNow ? DateTime.now().toIso8601String() : null,
    }).select('id').single();

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

  /// Update an existing post with optional added/reordered gallery media
  Future<void> updatePost({
    required String id,
    required String title,
    required String body,
    required String type,
    required String category,
    String? coverUrl,
    bool? isPinned,
    String? status,
    List<UploadedMediaItem> newMediaItems = const [],
  }) async {
    if (_client == null) return;

    final updates = <String, dynamic>{
      'title': title.trim(),
      'body': body.trim(),
      'type': type,
      'category': category,
      'cover_url': coverUrl,
      'updated_at': DateTime.now().toIso8601String(),
    };

    if (isPinned != null) updates['is_pinned'] = isPinned;
    if (status != null) {
      updates['status'] = status;
      if (status == 'published') {
        updates['published_at'] = DateTime.now().toIso8601String();
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
          .update({'sort_order': i}).eq('id', item.id);
    }
  }

  /// Set specific media as post cover
  Future<void> setPostCover(String postId, String coverUrl) async {
    if (_client == null) return;
    await _client
        .from('posts')
        .update({'cover_url': coverUrl, 'updated_at': DateTime.now().toIso8601String()})
        .eq('id', postId);
  }

  /// Directly update status of post
  Future<void> setPostStatus(String id, String status) async {
    if (_client == null) return;
    final updates = <String, dynamic>{
      'status': status,
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (status == 'published') {
      updates['published_at'] = DateTime.now().toIso8601String();
    }
    await _client.from('posts').update(updates).eq('id', id);
  }
}

final blogRepositoryProvider = Provider<BlogRepository>((ref) {
  final client =
      isSupabaseInitialized ? ref.watch(supabaseClientProvider) : null;
  return BlogRepository(client);
});

/// Filter state providers
final selectedBlogCategoryProvider = StateProvider<String>((ref) => 'all');
final blogSearchQueryProvider = StateProvider<String>((ref) => '');

/// Published blog feed provider reactive to category and search query
final blogFeedProvider = FutureProvider<List<BlogPost>>((ref) async {
  final repo = ref.watch(blogRepositoryProvider);
  final category = ref.watch(selectedBlogCategoryProvider);
  final query = ref.watch(blogSearchQueryProvider);

  return repo.getPublishedPosts(
    category: category == 'all' ? null : category,
    searchQuery: query.isEmpty ? null : query,
  );
});

/// Drafts provider
final myDraftsProvider = FutureProvider<List<BlogPost>>((ref) async {
  final repo = ref.watch(blogRepositoryProvider);
  return repo.getMyDrafts();
});
