import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/errors/error_handler.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../../chat/data/chat_repository.dart';
import '../../rbac/data/rbac_repository.dart';
import '../data/blog_repository.dart';
import '../models/blog_post.dart';
import '../models/post_comment.dart';
import 'widgets/audio_player_widget.dart';
import 'widgets/multi_image_gallery_widget.dart';

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

  Future<void> _handleDeletePost() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Post'),
        content: const Text(
          'Are you sure you want to permanently delete this post?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await ref.read(blogRepositoryProvider).deletePost(widget.postId);
        ref.invalidate(blogFeedProvider);
        ref.invalidate(myDraftsProvider);
        if (mounted) {
          context.pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Post deleted successfully.')),
          );
        }
      } catch (e) {
        if (mounted) ErrorHandler.showSnackBar(context, e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final postAsync = ref.watch(postDetailProvider(widget.postId));
    final commentsAsync = ref.watch(postCommentsProvider(widget.postId));
    final currentUserId = ref.watch(chatRepositoryProvider).currentUserId;
    final canEditAny = ref.can('blog.edit_any');
    final canDelete = ref.can('blog.delete');
    final theme = Theme.of(context);

    return postAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('Post')),
        body: const LoadingIndicator(message: 'Loading post...'),
      ),
      error: (err, stack) => Scaffold(
        appBar: AppBar(title: const Text('Post')),
        body: ErrorView(
          message: 'Unable to load post details',
          onRetry: () => ref.invalidate(postDetailProvider(widget.postId)),
        ),
      ),
      data: (post) {
        if (post == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Post')),
            body: const Center(child: Text('Post not found')),
          );
        }

        final isAuthor = post.authorId == currentUserId;
        final canEdit = (isAuthor && ref.can('blog.edit_own')) || canEditAny;
        final canDeleteThis =
            (isAuthor && post.status == 'draft') || canDelete;

        final dateStr = post.publishedAt != null
            ? DateFormat.yMMMd().format(post.publishedAt!)
            : 'Draft';

        return Scaffold(
          appBar: AppBar(
            title: const Text('Post'),
            actions: [
              if (canEdit || canDeleteThis)
                PopupMenuButton<String>(
                  onSelected: (val) {
                    if (val == 'edit') {
                      context.push('/blog/edit/${post.id}');
                    } else if (val == 'delete') {
                      _handleDeletePost();
                    }
                  },
                  itemBuilder: (ctx) => [
                    if (canEdit)
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit_outlined, size: 20),
                            SizedBox(width: 8),
                            Text('Edit Post'),
                          ],
                        ),
                      ),
                    if (canDeleteThis)
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline, color: Colors.red, size: 20),
                            SizedBox(width: 8),
                            Text('Delete Post', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                  ],
                ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              // Multi-Image Gallery or Cover Image
              if (post.imageMedia.isNotEmpty)
                MultiImageGalleryWidget(images: post.imageMedia)
              else if (post.coverUrl != null && post.coverUrl!.isNotEmpty)
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

              // Category Badge
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      post.type.toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      post.categoryDisplayName.toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSecondaryContainer,
                      ),
                    ),
                  ),
                  if (post.status == 'draft') ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.amber.withAlpha(50),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'DRAFT',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.amber,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),

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
          ),
        );
      },
    );
  }
}
