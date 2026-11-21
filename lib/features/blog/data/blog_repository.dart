import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/supabase_config.dart';
import '../models/blog_post.dart';
import '../models/post_comment.dart';

class BlogRepository {
  final SupabaseClient? _client;

  BlogRepository(this._client);

  String? get currentUserId => _client?.auth.currentUser?.id;

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
          '*, profiles:author_id(display_name, avatar_url), post_likes(user_id), post_comments(id)',
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
        .map((e) => BlogPost.fromJson(e, currentUserId: uid))
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
          '*, profiles:author_id(display_name, avatar_url), post_likes(user_id), post_comments(id)',
        )
        .eq('author_id', uid)
        .eq('status', 'draft')
        .order('created_at', ascending: false);

    return (res as List)
        .map((e) => BlogPost.fromJson(e, currentUserId: uid))
        .toList();
  }

  /// Get single post by ID
  Future<BlogPost?> getPostById(String id) async {
    if (_client == null) return null;
    final uid = currentUserId;

    final res = await _client
        .from('posts')
        .select(
          '*, profiles:author_id(display_name, avatar_url), post_likes(user_id), post_comments(id)',
        )
        .eq('id', id)
        .maybeSingle();

    if (res == null) return null;
    return BlogPost.fromJson(res, currentUserId: uid);
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

  /// Create a new post
  Future<String?> createPost({
    required String title,
    required String body,
    required String type,
    String category = BlogCategories.news,
    String? coverUrl,
    bool publishNow = true,
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

    return res['id'] as String?;
  }

  /// Update an existing post
  Future<void> updatePost({
    required String id,
    required String title,
    required String body,
    required String type,
    required String category,
    String? coverUrl,
    bool? isPinned,
    String? status,
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
  }

  /// Publish a draft post
  Future<void> publishPost(String id) async {
    await updatePost(
      id: id,
      title: '', // will be ignored if using targeted update
      body: '',
      type: '',
      category: '',
    );
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

  /// Delete a post (allowed for own drafts or users with blog.delete)
  Future<void> deletePost(String id) async {
    if (_client == null) return;
    await _client.from('posts').delete().eq('id', id);
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
