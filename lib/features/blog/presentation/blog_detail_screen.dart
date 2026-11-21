import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/errors/error_handler.dart';
import '../../../core/widgets/empty_state.dart';
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Comment posted successfully!')),
        );
      }
    } catch (e) {
      if (mounted) ErrorHandler.showSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _handleReportPost(String postId) async {
    String selectedReason = 'Spam or advertising';
    final detailsCtrl = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Report Article'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Why are you reporting this post?'),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: selectedReason,
                items: const [
                  DropdownMenuItem(
                    value: 'Spam or advertising',
                    child: Text('Spam or advertising'),
                  ),
                  DropdownMenuItem(
                    value: 'Misinformation or fake news',
                    child: Text('Misinformation'),
                  ),
                  DropdownMenuItem(
                    value: 'Harassment or hate speech',
                    child: Text('Harassment or hate'),
                  ),
                  DropdownMenuItem(
                    value: 'Inappropriate content',
                    child: Text('Inappropriate content'),
                  ),
                  DropdownMenuItem(
                    value: 'Other',
                    child: Text('Other reason'),
                  ),
                ],
                onChanged: (val) {
                  if (val != null) setDialogState(() => selectedReason = val);
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: detailsCtrl,
                decoration: const InputDecoration(
                  labelText: 'Additional Details (Optional)',
                ),
                maxLines: 2,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Submit Report'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await ref.read(blogRepositoryProvider).reportPost(
              postId: postId,
              reason: selectedReason,
              details: detailsCtrl.text.trim(),
            );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Thank you. Post reported for moderation review.')),
          );
        }
      } catch (e) {
        if (mounted) ErrorHandler.showSnackBar(context, e);
      }
    }
  }

  Future<void> _handleReportComment(String commentId, String postId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Report Comment'),
        content: const Text(
          'Are you sure you want to flag this comment for moderator review?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Flag Comment'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await ref.read(blogRepositoryProvider).reportComment(
              commentId: commentId,
              postId: postId,
              reason: 'Inappropriate or offensive comment',
            );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Comment reported for moderation review.')),
          );
        }
      } catch (e) {
        if (mounted) ErrorHandler.showSnackBar(context, e);
      }
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
            appBar: AppBar(title: const Text('Post Not Found')),
            body: EmptyState(
              icon: Icons.article_outlined,
              title: 'Article Not Found',
              subtitle: 'This post may have been removed, archived, or is unpublished.',
              action: ElevatedButton.icon(
                onPressed: () => context.pop(),
                icon: const Icon(Icons.arrow_back),
                label: const Text('Back to Blog'),
              ),
            ),
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
              // Bookmark Button
              IconButton(
                icon: Icon(
                  post.isBookmarkedByMe
                      ? Icons.bookmark
                      : Icons.bookmark_border_rounded,
                  color: post.isBookmarkedByMe
                      ? theme.colorScheme.primary
                      : null,
                ),
                tooltip: post.isBookmarkedByMe
                    ? 'Remove Bookmark'
                    : 'Save Article',
                onPressed: () async {
                  await ref
                      .read(blogRepositoryProvider)
                      .toggleBookmark(post.id, post.isBookmarkedByMe);
                  ref.invalidate(postDetailProvider(widget.postId));
                  ref.invalidate(myBookmarksProvider);
                },
              ),
              PopupMenuButton<String>(
                onSelected: (val) {
                  if (val == 'edit') {
                    context.push('/blog/edit/${post.id}');
                  } else if (val == 'delete') {
                    _handleDeletePost();
                  } else if (val == 'report') {
                    _handleReportPost(post.id);
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
                  if (!isAuthor)
                    const PopupMenuItem(
                      value: 'report',
                      child: Row(
                        children: [
                          Icon(Icons.flag_outlined, color: Colors.orange, size: 20),
                          SizedBox(width: 8),
                          Text('Report Post'),
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
                    memCacheWidth: 1000,
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
                  Text(
                    '$dateStr • ${post.readingTimeMinutes} min read',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
              if (post.tags.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: post.tags.map((tag) {
                    return ActionChip(
                      visualDensity: VisualDensity.compact,
                      avatar: const Icon(Icons.tag, size: 14),
                      label: Text(tag),
                      onPressed: () => context.push('/blog/topic?tag=${Uri.encodeComponent(tag)}'),
                    );
                  }).toList(),
                ),
              ],
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

              // Related Articles (Requirement 6)
              Consumer(
                builder: (context, ref, _) {
                  final relatedAsync = ref.watch(relatedPostsProvider(post));
                  return relatedAsync.when(
                    data: (relatedList) {
                      if (relatedList.isEmpty) return const SizedBox.shrink();
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Divider(height: 32),
                          Row(
                            children: [
                              const Icon(Icons.auto_stories_outlined, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                'Related Articles',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          ...relatedList.map((relPost) => Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                child: ListTile(
                                  title: Text(
                                    relPost.title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  subtitle: Text(
                                    '${relPost.categoryDisplayName} • ${relPost.readingTimeMinutes} min read',
                                    style: theme.textTheme.bodySmall,
                                  ),
                                  trailing: const Icon(
                                    Icons.arrow_forward_ios,
                                    size: 14,
                                  ),
                                  onTap: () =>
                                      context.push('/blog/${relPost.id}'),
                                ),
                              )),
                        ],
                      );
                    },
                    loading: () => const SizedBox.shrink(),
                    error: (err, stack) => const SizedBox.shrink(),
                  );
                },
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
                              IconButton(
                                icon: const Icon(
                                  Icons.flag_outlined,
                                  size: 16,
                                  color: Colors.orange,
                                ),
                                tooltip: 'Report Comment',
                                onPressed: () => _handleReportComment(
                                  c.id,
                                  widget.postId,
                                ),
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
