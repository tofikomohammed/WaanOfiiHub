import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/errors/error_handler.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../../rbac/data/rbac_repository.dart';
import '../data/blog_repository.dart';

class MyDraftsScreen extends ConsumerWidget {
  const MyDraftsScreen({super.key});

  Future<void> _handleDelete(
    BuildContext context,
    WidgetRef ref,
    String id,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Draft'),
        content: const Text(
          'Are you sure you want to permanently delete this draft?',
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

    if (confirmed == true) {
      try {
        await ref.read(blogRepositoryProvider).deletePost(id);
        ref.invalidate(myDraftsProvider);
        if (context.mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('Draft deleted.')));
        }
      } catch (e) {
        if (context.mounted) ErrorHandler.showSnackBar(context, e);
      }
    }
  }

  Future<void> _handleCancelSchedule(
    BuildContext context,
    WidgetRef ref,
    String id,
  ) async {
    try {
      await ref.read(blogRepositoryProvider).cancelScheduledPost(id);
      ref.invalidate(myDraftsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Scheduled publication cancelled. Reverted to draft.',
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) ErrorHandler.showSnackBar(context, e);
    }
  }

  Future<void> _handlePublish(
    BuildContext context,
    WidgetRef ref,
    String id,
  ) async {
    try {
      await ref.read(blogRepositoryProvider).setPostStatus(id, 'published');
      ref.invalidate(myDraftsProvider);
      ref.invalidate(blogFeedProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Post published to feed!')),
        );
      }
    } catch (e) {
      if (context.mounted) ErrorHandler.showSnackBar(context, e);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draftsAsync = ref.watch(myDraftsProvider);
    final canPublish = ref.can('blog.publish');
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Drafts & Scheduled'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'New Post',
            onPressed: () => context.push('/blog/create'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(myDraftsProvider),
        child: draftsAsync.when(
          loading: () => const LoadingIndicator(message: 'Loading drafts...'),
          error: (err, stack) => ErrorView(
            message: 'Unable to load drafts',
            onRetry: () => ref.invalidate(myDraftsProvider),
          ),
          data: (drafts) {
            if (drafts.isEmpty) {
              return EmptyState(
                icon: Icons.drafts_outlined,
                title: 'No Drafts',
                subtitle: 'Any unpublished articles or notes you save will appear here.',
                action: ElevatedButton.icon(
                  onPressed: () => context.push('/blog/create'),
                  icon: const Icon(Icons.edit_note_rounded),
                  label: const Text('Write a Draft'),
                ),
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.all(16.0),
              itemCount: drafts.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final draft = drafts[index];
                final dateStr = DateFormat.yMMMd().add_jm().format(
                  draft.createdAt,
                );

                return Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    title: Row(
                      children: [
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
                            draft.categoryDisplayName.toUpperCase(),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSecondaryContainer,
                            ),
                          ),
                        ),
                        if (draft.isScheduled) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.purple.withAlpha(40),
                              border: Border.all(color: Colors.purple),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'SCHEDULED',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.purple,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            draft.title.isEmpty
                                ? '(Untitled Draft)'
                                : draft.title,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 6),
                        if (draft.body.isNotEmpty)
                          Text(
                            draft.body,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        const SizedBox(height: 6),
                        if (draft.isScheduled && draft.scheduledFor != null)
                          Text(
                            'Scheduled for: ${DateFormat.yMMMd().add_jm().format(draft.scheduledFor!.toLocal())}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.purple,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        else
                          Text(
                            'Created $dateStr',
                            style: theme.textTheme.bodySmall,
                          ),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (draft.isScheduled)
                          IconButton(
                            icon: const Icon(
                              Icons.cancel_schedule_send_rounded,
                              color: Colors.purple,
                            ),
                            tooltip: 'Cancel Schedule',
                            onPressed: () =>
                                _handleCancelSchedule(context, ref, draft.id),
                          )
                        else if (canPublish)
                          IconButton(
                            icon: const Icon(
                              Icons.publish_rounded,
                              color: Colors.green,
                            ),
                            tooltip: 'Publish Now',
                            onPressed: () =>
                                _handlePublish(context, ref, draft.id),
                          ),
                        IconButton(
                          icon: const Icon(Icons.edit_outlined),
                          tooltip: 'Edit Draft',
                          onPressed: () =>
                              context.push('/blog/edit/${draft.id}'),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.delete_outline,
                            color: Colors.red,
                          ),
                          tooltip: 'Delete Draft',
                          onPressed: () =>
                              _handleDelete(context, ref, draft.id),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
