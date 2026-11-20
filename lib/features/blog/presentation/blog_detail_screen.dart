import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../../chat/data/chat_repository.dart';
import '../data/blog_repository.dart';
import '../models/blog_post.dart';
import '../models/post_comment.dart';
import 'widgets/audio_player_widget.dart';

final postDetailProvider = FutureProvider.family<BlogPost?, String>((
  ref,
  id,
) async {
  return ref.watch(blogRepositoryProvider).getPostById(id);
});

final postCommentsProvider = FutureProvider.family<List<PostComment>, String>((
  ref,
  id,
) async {
  return ref.watch(blogRepositoryProvider).getComments(id);
});

class BlogDetailScreen extends ConsumerStatefulWidget {
  final String postId;

  const BlogDetailScreen({super.key, required this.postId});

  @override
  ConsumerState<BlogDetailScreen> createState() => _BlogDetailScreenState();
}

class _BlogDetailScreenState extends ConsumerState<BlogDetailScreen> {
  final _commentController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _handlePostComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    setState(() => _isSubmitting = true);
    try {
      await ref.read(blogRepositoryProvider).addComment(widget.postId, text);
      _commentController.clear();
      ref.invalidate(postCommentsProvider(widget.postId));
      ref.invalidate(postDetailProvider(widget.postId));
    } catch (_) {}
    if (mounted) {
      setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final postAsync = ref.watch(postDetailProvider(widget.postId));
    final commentsAsync = ref.watch(postCommentsProvider(widget.postId));
    final currentUserId = ref.watch(chatRepositoryProvider).currentUserId;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Post')),
      body: postAsync.when(
        loading: () => const LoadingIndicator(message: 'Loading post...'),
        error: (err, stack) => ErrorView(
          message: 'Unable to load post details',
          onRetry: () => ref.invalidate(postDetailProvider(widget.postId)),
        ),
        data: (post) {
          if (post == null) {
            return const Center(child: Text('Post not found'));
          }

          final dateStr = post.publishedAt != null
              ? DateFormat.yMMMd().format(post.publishedAt!)
              : 'Draft';

          return ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              if (post.coverUrl != null && post.coverUrl!.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: CachedNetworkImage(
                    imageUrl: post.coverUrl!,
                    height: 240,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
              const SizedBox(height: 16),
              Text(post.title, style: theme.textTheme.headlineMedium),
              const SizedBox(height: 8),
              Row(
                children: [
                  CircleAvatar(
                    radius: 14,
                    child: Text(
                      post.authorName != null && post.authorName!.isNotEmpty
                          ? post.authorName![0].toUpperCase()
                          : 'A',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    post.authorName ?? 'Admin',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (post.authorId != currentUserId) ...[
                    const SizedBox(width: 8),
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      icon: const Icon(Icons.chat_bubble_outline_rounded, size: 14),
                      label: const Text('Chat', style: TextStyle(fontSize: 12)),
                      onPressed: () async {
                        final convId = await ref
                            .read(chatRepositoryProvider)
                            .startDirectChat(post.authorId);
                        if (convId != null && context.mounted) {
                          unawaited(context.push('/chat/$convId'));
                        }
                      },
                    ),
                  ],
                  const Spacer(),
                  Text(dateStr, style: theme.textTheme.bodySmall),
                ],
              ),
              const Divider(height: 32),
              if (post.type == 'audio' && post.coverUrl != null) ...[
                AudioPlayerWidget(audioUrl: post.coverUrl!, title: post.title),
                const SizedBox(height: 16),
              ],
              Text(
                post.body,
                style: theme.textTheme.bodyLarge?.copyWith(height: 1.6),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  IconButton(
                    icon: Icon(
                      post.isLikedByMe ? Icons.favorite : Icons.favorite_border,
                      color: post.isLikedByMe ? Colors.red : null,
                    ),
                    onPressed: () async {
                      await ref
                          .read(blogRepositoryProvider)
                          .toggleLike(post.id, post.isLikedByMe);
                      ref.invalidate(postDetailProvider(widget.postId));
                    },
                  ),
                  Text('${post.likesCount} Likes'),
                  const SizedBox(width: 24),
                  const Icon(Icons.mode_comment_outlined, size: 20),
                  const SizedBox(width: 6),
                  Text('${post.commentsCount} Comments'),
                ],
              ),
              const Divider(height: 32),
              Text('Comments', style: theme.textTheme.titleMedium),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _commentController,
                      decoration: const InputDecoration(
                        hintText: 'Write a comment...',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    icon: _isSubmitting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.send),
                    onPressed: _isSubmitting ? null : _handlePostComment,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              commentsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => const Text('Could not load comments'),
                data: (comments) {
                  if (comments.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16.0),
                      child: Text('No comments yet. Be the first to reply!'),
                    );
                  }
                  return Column(
                    children: comments.map((c) {
                      final isMe = c.userId == currentUserId;
                      return ListTile(
                        leading: CircleAvatar(
                          child: Text(
                            c.userName.isNotEmpty
                                ? c.userName[0].toUpperCase()
                                : 'U',
                          ),
                        ),
                        title: Text(
                          c.userName,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(c.body),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              DateFormat.MMMd().format(c.createdAt),
                              style: theme.textTheme.bodySmall,
                            ),
                            if (!isMe) ...[
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(
                                  Icons.chat_bubble_outline_rounded,
                                  size: 18,
                                  color: Colors.teal,
                                ),
                                tooltip: 'Chat with ${c.userName}',
                                onPressed: () async {
                                  final convId = await ref
                                      .read(chatRepositoryProvider)
                                      .startDirectChat(c.userId);
                                  if (convId != null && context.mounted) {
                                    unawaited(context.push('/chat/$convId'));
                                  }
                                },
                              ),
                            ],
                          ],
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}
