import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/errors/error_handler.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../../blog/data/blog_repository.dart';

class AdminReportsScreen extends ConsumerStatefulWidget {
  const AdminReportsScreen({super.key});

  @override
  ConsumerState<AdminReportsScreen> createState() => _AdminReportsScreenState();
}

class _AdminReportsScreenState extends ConsumerState<AdminReportsScreen> {
  String _selectedStatus = 'open';

  Future<void> _handleAction(
    String reportId,
    String action,
    String actionLabel,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('$actionLabel Report'),
        content: Text(
          'Are you sure you want to $actionLabel this reported content? This action will be recorded in the security audit logs.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: action.contains('delete')
                ? FilledButton.styleFrom(backgroundColor: Colors.red)
                : null,
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
            .adminActionReport(reportId, action);
        ref.invalidate(moderationReportsProvider(_selectedStatus));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Report action ($action) completed.')),
          );
        }
      } catch (e) {
        if (mounted) ErrorHandler.showSnackBar(context, e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final reportsAsync = ref.watch(moderationReportsProvider(_selectedStatus));
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Moderation Reports'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _buildFilterChip('Open', 'open'),
                const SizedBox(width: 8),
                _buildFilterChip('Actioned', 'actioned'),
                const SizedBox(width: 8),
                _buildFilterChip('Dismissed', 'dismissed'),
                const SizedBox(width: 8),
                _buildFilterChip('All', 'all'),
              ],
            ),
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async =>
            ref.invalidate(moderationReportsProvider(_selectedStatus)),
        child: reportsAsync.when(
          loading: () =>
              const LoadingIndicator(message: 'Loading moderation reports...'),
          error: (err, stack) => ErrorView(
            message: 'Unable to load moderation reports',
            onRetry: () =>
                ref.invalidate(moderationReportsProvider(_selectedStatus)),
          ),
          data: (reports) {
            if (reports.isEmpty) {
              return EmptyState(
                icon: Icons.shield_outlined,
                title: 'No Reports Found',
                subtitle: _selectedStatus == 'open'
                    ? 'All clear! No user reports currently pending review.'
                    : 'No reports matching status "$_selectedStatus".',
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: reports.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final report = reports[index];
                final reportId = report['id'] as String;
                final reason = report['reason'] as String? ?? 'Unspecified';
                final details = report['details'] as String?;
                final status = report['status'] as String? ?? 'open';
                final createdAtStr = report['created_at'] as String?;
                final dateStr = createdAtStr != null
                    ? DateFormat.yMMMd().add_jm().format(
                          DateTime.parse(createdAtStr).toLocal(),
                        )
                    : '';

                final reporter = report['reporter'] as Map<String, dynamic>?;
                final reporterName =
                    reporter?['display_name'] as String? ?? 'Anonymous Reporter';

                final post = report['post'] as Map<String, dynamic>?;
                final comment = report['comment'] as Map<String, dynamic>?;
                final isComment = report['comment_id'] != null;

                Color statusColor = Colors.orange;
                if (status == 'actioned') statusColor = Colors.green;
                if (status == 'dismissed') statusColor = Colors.grey;

                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: statusColor.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: statusColor),
                              ),
                              child: Text(
                                status.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: statusColor,
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
                                color: theme.colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                isComment ? 'COMMENT REPORT' : 'POST REPORT',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                            const Spacer(),
                            Text(
                              dateStr,
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Reason: $reason',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (details != null && details.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Reporter note: "$details"',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                        const SizedBox(height: 4),
                        Text(
                          'Reported by: $reporterName',
                          style: theme.textTheme.bodySmall,
                        ),
                        const Divider(height: 24),
                        // Target Preview
                        if (isComment && comment != null) ...[
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.comment_outlined,
                                size: 18,
                                color: Colors.blueGrey,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Comment content: "${comment['body'] ?? ''}"',
                                  style: theme.textTheme.bodyMedium,
                                ),
                              ),
                            ],
                          ),
                          if (comment['is_hidden'] == true) ...[
                            const SizedBox(height: 4),
                            const Text(
                              'Status: Currently Hidden',
                              style: TextStyle(
                                color: Colors.orange,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ] else if (post != null) ...[
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.article_outlined,
                                size: 18,
                                color: Colors.blueGrey,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Article: "${post['title'] ?? 'Untitled'}"',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (status == 'open') ...[
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              OutlinedButton.icon(
                                icon: const Icon(Icons.close_rounded, size: 16),
                                label: const Text('Dismiss'),
                                onPressed: () => _handleAction(
                                  reportId,
                                  'dismiss',
                                  'Dismiss',
                                ),
                              ),
                              if (isComment) ...[
                                FilledButton.tonalIcon(
                                  icon: const Icon(
                                    Icons.visibility_off_outlined,
                                    size: 16,
                                  ),
                                  label: const Text('Hide Comment'),
                                  onPressed: () => _handleAction(
                                    reportId,
                                    'action_hide',
                                    'Hide Comment',
                                  ),
                                ),
                                FilledButton.icon(
                                  style: FilledButton.styleFrom(
                                    backgroundColor: Colors.red,
                                  ),
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    size: 16,
                                  ),
                                  label: const Text('Delete Comment'),
                                  onPressed: () => _handleAction(
                                    reportId,
                                    'action_delete',
                                    'Delete Comment',
                                  ),
                                ),
                              ] else ...[
                                FilledButton.icon(
                                  style: FilledButton.styleFrom(
                                    backgroundColor: Colors.red,
                                  ),
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    size: 16,
                                  ),
                                  label: const Text('Delete Article'),
                                  onPressed: () => _handleAction(
                                    reportId,
                                    'action_delete',
                                    'Delete Article',
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
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

  Widget _buildFilterChip(String label, String statusKey) {
    final isSelected = _selectedStatus == statusKey;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() => _selectedStatus = statusKey);
        }
      },
    );
  }
}
