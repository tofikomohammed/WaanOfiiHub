import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/supabase_config.dart';
import '../models/blog_post.dart';
import '../models/post_comment.dart';

class BlogRepository {
  final SupabaseClient? _client;

  BlogRepository(this._client);

  Future<List<BlogPost>> getPublishedPosts({
    int limit = 20,
    int offset = 0,
  }) async {
    if (_client == null) return [];
    final currentUserId = _client.auth.currentUser?.id;

    final res = await _client
        .from('posts')
        .select(
          '*, profiles:author_id(display_name, avatar_url), post_likes(user_id), post_comments(id)',
        )
        .eq('status', 'published')
        .order('is_pinned', ascending: false)
        .order('published_at', ascending: false)
        .range(offset, offset + limit - 1);

    return (res as List)
        .map((e) => BlogPost.fromJson(e, currentUserId: currentUserId))
        .toList();
  }

  Future<BlogPost?> getPostById(String id) async {
    if (_client == null) return null;
    final currentUserId = _client.auth.currentUser?.id;

    final res = await _client
        .from('posts')
        .select(
          '*, profiles:author_id(display_name, avatar_url), post_likes(user_id), post_comments(id)',
        )
        .eq('id', id)
        .maybeSingle();

    if (res == null) return null;
    return BlogPost.fromJson(res, currentUserId: currentUserId);
  }

  Future<void> toggleLike(String postId, bool isLiked) async {
    if (_client == null) return;
    final uid = _client.auth.currentUser?.id;
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

  Future<void> addComment(String postId, String body) async {
    if (_client == null) return;
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return;

    await _client.from('post_comments').insert({
      'post_id': postId,
      'user_id': uid,
      'body': body.trim(),
    });
  }

  Future<void> createPost({
    required String title,
    required String body,
    required String type,
    String? coverUrl,
    bool publishNow = true,
  }) async {
    if (_client == null) return;
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return;

    await _client.from('posts').insert({
      'author_id': uid,
      'title': title.trim(),
      'body': body.trim(),
      'type': type,
      'cover_url': coverUrl,
      'status': publishNow ? 'published' : 'draft',
      'published_at': publishNow ? DateTime.now().toIso8601String() : null,
    });
  }
}

final blogRepositoryProvider = Provider<BlogRepository>((ref) {
  final client = isSupabaseInitialized
      ? ref.watch(supabaseClientProvider)
      : null;
  return BlogRepository(client);
});

final blogFeedProvider = FutureProvider<List<BlogPost>>((ref) async {
  return ref.watch(blogRepositoryProvider).getPublishedPosts();
});
