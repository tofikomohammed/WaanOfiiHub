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
import '../../blog/data/blog_repository.dart';
import '../../blog/models/blog_post.dart';

class AdminPostsScreen extends ConsumerStatefulWidget {
  const AdminPostsScreen({super.key});

  @override
  ConsumerState<AdminPostsScreen> createState() => _AdminPostsScreenState();
}

class _AdminPostsScreenState extends ConsumerState<AdminPostsScreen> {
  final _searchController = TextEditingController();
  String _selectedStatus = 'all';
  String _selectedType = 'all';
  String _searchQuery = '';
  Timer? _debounceTimer;

  @override
  void dispose() {
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String val) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() => _searchQuery = val.trim());
      }
    });
  }

  AdminPostsFilter get _currentFilter => AdminPostsFilter(
    status: _selectedStatus,
    type: _selectedType,
    searchQuery: _searchQuery,
  );

  void _refreshList() {
    ref.invalidate(adminPostsProvider(_currentFilter));
  }

  Future<void> _handleTogglePublish(BlogPost post) async {
    final willPublish = post.status != 'published';
    final actionLabel = willPublish ? 'Publish' : 'Unpublish';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('$actionLabel Post'),
        content: Text(
          willPublish
              ? 'Are you sure you want to publish "${post.title}"? It will become visible immediately to all readers.'
              : 'Are you sure you want to unpublish "${post.title}"? It will be reverted to draft status.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(actionLabel),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await ref
            .read(blogRepositoryProvider)
            .adminSetPublishStatus(post.id, willPublish);
        _refreshList();
        ref.invalidate(blogFeedProvider);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                willPublish
                    ? 'Post published to feed (logged to audit).'
                    : 'Post unpublished (logged to audit).',
              ),
            ),
          );
        }
      } catch (e) {
        if (mounted) ErrorHandler.showSnackBar(context, e);
      }
    }
  }

  Future<void> _handleTogglePin(BlogPost post) async {
    final newPinned = !post.isPinned;
    try {
      await ref.read(blogRepositoryProvider).togglePinPost(post.id, newPinned);
      _refreshList();
      ref.invalidate(blogFeedProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              newPinned ? 'Post pinned to top of feed.' : 'Post unpinned.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) ErrorHandler.showSnackBar(context, e);
    }
  }

  Future<void> _handleToggleArchive(BlogPost post) async {
    final willArchive = post.status != 'archived';
    final newStatus = willArchive ? 'archived' : 'draft';
    try {
      await ref.read(blogRepositoryProvider).setPostStatus(post.id, newStatus);
      _refreshList();
      ref.invalidate(blogFeedProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              willArchive
                  ? 'Post moved to archived.'
                  : 'Post restored to draft.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) ErrorHandler.showSnackBar(context, e);
    }
  }

  Future<void> _handleDeletePost(BlogPost post) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Post Permanently'),
        content: Text(
          'Are you sure you want to delete "${post.title}"? All associated media, likes, and comments will be permanently erased. This action will be logged in security audit logs.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete Permanently'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await ref.read(blogRepositoryProvider).adminDeletePost(post.id);
        _refreshList();
        ref.invalidate(blogFeedProvider);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Post permanently deleted (logged to audit).'),
            ),
          );
        }
      } catch (e) {
        if (mounted) ErrorHandler.showSnackBar(context, e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final postsAsync = ref.watch(adminPostsProvider(_currentFilter));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Articles & Content Manager'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: _refreshList,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/blog/create'),
        icon: const Icon(Icons.add),
        label: const Text('New Article'),
      ),
      body: Column(
        children: [
          // Search & Filter Header
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            color: theme.colorScheme.surface,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Search Input
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search articles by title, content, or author...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                  ),
                  onChanged: _onSearchChanged,
                ),
                const SizedBox(height: 10),

                // Status Filter Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      const Text(
                        'Status: ',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 4),
                      _buildStatusChip('All', 'all'),
                      const SizedBox(width: 6),
                      _buildStatusChip('Published', 'published'),
                      const SizedBox(width: 6),
                      _buildStatusChip('Scheduled', 'scheduled'),
                      const SizedBox(width: 6),
                      _buildStatusChip('Drafts', 'draft'),
                      const SizedBox(width: 6),
                      _buildStatusChip('Archived', 'archived'),
                    ],
                  ),
                ),
                const SizedBox(height: 6),

                // Type Filter Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      const Text(
                        'Type: ',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 4),
                      _buildTypeChip('All Types', 'all'),
                      const SizedBox(width: 6),
                      _buildTypeChip('Text', 'text'),
                      const SizedBox(width: 6),
                      _buildTypeChip('Image', 'image'),
                      const SizedBox(width: 6),
                      _buildTypeChip('Audio', 'audio'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Posts List
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async => _refreshList(),
              child: postsAsync.when(
                loading: () =>
                    const LoadingIndicator(message: 'Loading articles...'),
                error: (err, stack) => ErrorView(
                  message: 'Unable to load articles',
                  technicalDetails: err.toString(),
                  onRetry: _refreshList,
                ),
                data: (posts) {
                  if (posts.isEmpty) {
                    return EmptyState(
                      icon: Icons.article_outlined,
                      title: 'No Articles Found',
                      subtitle: _searchQuery.isNotEmpty
                          ? 'No articles matching search query "$_searchQuery".'
                          : 'No articles found matching the selected filters.',
                      action: ElevatedButton.icon(
                        onPressed: () => context.push('/blog/create'),
                        icon: const Icon(Icons.edit_note_rounded),
                        label: const Text('Create New Article'),
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                    itemCount: posts.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final post = posts[index];
                      return _buildAdminPostCard(post, theme);
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String label, String value) {
    final isSelected = _selectedStatus == value;
    return ChoiceChip(
      visualDensity: VisualDensity.compact,
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() => _selectedStatus = value);
        }
      },
    );
  }

  Widget _buildTypeChip(String label, String value) {
    final isSelected = _selectedType == value;
    return ChoiceChip(
      visualDensity: VisualDensity.compact,
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() => _selectedType = value);
        }
      },
    );
  }

  Widget _buildAdminPostCard(BlogPost post, ThemeData theme) {
    Color statusColor = Colors.grey;
    final statusLabel = post.status.toUpperCase();

    if (post.status == 'published') {
      statusColor = Colors.green;
    } else if (post.status == 'scheduled') {
      statusColor = Colors.purple;
    } else if (post.status == 'draft') {
      statusColor = Colors.amber.shade800;
    }

    final dateStr = post.isScheduled && post.scheduledFor != null
        ? 'Scheduled: ${DateFormat.MMMd().add_jm().format(post.scheduledFor!.toLocal())}'
        : (post.publishedAt != null
              ? 'Published: ${DateFormat.yMMMd().format(post.publishedAt!)}'
              : 'Created: ${DateFormat.yMMMd().format(post.createdAt)}');

    return Card(
      elevation: 1,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            contentPadding: const EdgeInsets.fromLTRB(16, 12, 12, 8),
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: post.coverUrl != null && post.coverUrl!.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: post.coverUrl!,
                      width: 56,
                      height: 56,
                      fit: BoxFit.cover,
                      placeholder: (_, _) => Container(
                        width: 56,
                        height: 56,
                        color: theme.colorScheme.surfaceContainerHighest,
                        child: const Icon(Icons.image, size: 24),
                      ),
                      errorWidget: (_, _, _) => Container(
                        width: 56,
                        height: 56,
                        color: theme.colorScheme.surfaceContainerHighest,
                        child: const Icon(Icons.broken_image, size: 24),
                      ),
                    )
                  : Container(
                      width: 56,
                      height: 56,
                      color: theme.colorScheme.primaryContainer,
                      child: Icon(
                        post.type == 'audio'
                            ? Icons.audiotrack
                            : (post.type == 'image'
                                  ? Icons.photo_library
                                  : Icons.article),
                        color: theme.colorScheme.primary,
                        size: 26,
                      ),
                    ),
            ),
            title: Row(
              children: [
                // Status Badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: statusColor, width: 0.8),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                ),
                const SizedBox(width: 6),

                // Category Badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
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

                if (post.isPinned) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.amber, width: 0.8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.push_pin, size: 10, color: Colors.amber),
                        SizedBox(width: 2),
                        Text(
                          'PINNED',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.amber,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 6),
                Text(
                  post.title.isEmpty ? '(Untitled Article)' : post.title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  'By ${post.authorName ?? 'Admin'} • $dateStr',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
            trailing: PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (val) {
                if (val == 'view') {
                  context.push('/blog/${post.id}');
                } else if (val == 'edit') {
                  context.push('/blog/edit/${post.id}');
                } else if (val == 'publish_toggle') {
                  _handleTogglePublish(post);
                } else if (val == 'pin_toggle') {
                  _handleTogglePin(post);
                } else if (val == 'archive_toggle') {
                  _handleToggleArchive(post);
                } else if (val == 'delete') {
                  _handleDeletePost(post);
                }
              },
              itemBuilder: (ctx) => [
                const PopupMenuItem(
                  value: 'view',
                  child: Row(
                    children: [
                      Icon(Icons.visibility_outlined, size: 18),
                      SizedBox(width: 8),
                      Text('View Article'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit_outlined, size: 18),
                      SizedBox(width: 8),
                      Text('Edit Post'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'publish_toggle',
                  child: Row(
                    children: [
                      Icon(
                        post.status == 'published'
                            ? Icons.unpublished_outlined
                            : Icons.publish_rounded,
                        size: 18,
                        color: post.status == 'published'
                            ? Colors.orange
                            : Colors.green,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        post.status == 'published'
                            ? 'Unpublish Post'
                            : 'Publish Post',
                      ),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'pin_toggle',
                  child: Row(
                    children: [
                      Icon(
                        post.isPinned
                            ? Icons.push_pin_outlined
                            : Icons.push_pin,
                        size: 18,
                        color: Colors.amber,
                      ),
                      const SizedBox(width: 8),
                      Text(post.isPinned ? 'Unpin Post' : 'Pin to Top'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'archive_toggle',
                  child: Row(
                    children: [
                      Icon(
                        post.status == 'archived'
                            ? Icons.unarchive_outlined
                            : Icons.archive_outlined,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        post.status == 'archived'
                            ? 'Restore to Draft'
                            : 'Archive Post',
                      ),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline, size: 18, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Delete Post', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
            ),
            onTap: () => context.push('/blog/${post.id}'),
          ),

          // Post Metrics & Quick Action Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withAlpha(50),
              border: Border(
                top: BorderSide(
                  color: theme.colorScheme.outlineVariant.withAlpha(50),
                ),
              ),
            ),
            child: Row(
              children: [
                // Views
                const Icon(Icons.remove_red_eye_outlined, size: 14),
                const SizedBox(width: 4),
                Text(
                  '${post.viewsCount}',
                  style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
                ),
                const SizedBox(width: 14),

                // Likes
                const Icon(Icons.favorite_outline, size: 14),
                const SizedBox(width: 4),
                Text(
                  '${post.likesCount}',
                  style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
                ),
                const SizedBox(width: 14),

                // Comments
                const Icon(Icons.mode_comment_outlined, size: 14),
                const SizedBox(width: 4),
                Text(
                  '${post.commentsCount}',
                  style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
                ),

                const Spacer(),

                // Fast Action: Edit
                TextButton.icon(
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  icon: const Icon(Icons.edit_outlined, size: 14),
                  label: const Text('Edit', style: TextStyle(fontSize: 12)),
                  onPressed: () => context.push('/blog/edit/${post.id}'),
                ),

                // Fast Action: Toggle Publish
                TextButton.icon(
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  icon: Icon(
                    post.status == 'published'
                        ? Icons.unpublished_outlined
                        : Icons.publish_rounded,
                    size: 14,
                    color: post.status == 'published'
                        ? Colors.orange
                        : Colors.green,
                  ),
                  label: Text(
                    post.status == 'published' ? 'Unpublish' : 'Publish',
                    style: TextStyle(
                      fontSize: 12,
                      color: post.status == 'published'
                          ? Colors.orange
                          : Colors.green,
                    ),
                  ),
                  onPressed: () => _handleTogglePublish(post),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
