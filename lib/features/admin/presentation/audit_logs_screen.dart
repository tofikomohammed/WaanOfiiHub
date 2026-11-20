import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/supabase_config.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_indicator.dart';

final auditLogsProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  final client = isSupabaseInitialized
      ? ref.watch(supabaseClientProvider)
      : null;
  if (client == null) return [];
  final res = await client
      .from('audit_logs')
      .select(
        'id, actor_id, action, target_type, target_id, metadata, created_at',
      )
      .order('created_at', ascending: false)
      .limit(50);
  return List<Map<String, dynamic>>.from(res);
});

class AuditLogsScreen extends ConsumerWidget {
  const AuditLogsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logsAsync = ref.watch(auditLogsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('System Audit Logs'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.refresh(auditLogsProvider),
          ),
        ],
      ),
      body: logsAsync.when(
        loading: () => const LoadingIndicator(message: 'Loading audit logs...'),
        error: (err, stack) => ErrorView(
          message: 'Unable to load audit logs (requires audit.view permission)',
          onRetry: () => ref.refresh(auditLogsProvider),
        ),
        data: (logs) {
          if (logs.isEmpty) {
            return const Center(child: Text('No audit log entries recorded.'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16.0),
            itemCount: logs.length,
            separatorBuilder: (context, index) => const Divider(),
            itemBuilder: (context, index) {
              final log = logs[index];
              return ListTile(
                leading: const CircleAvatar(
                  child: Icon(Icons.receipt_long_outlined, size: 20),
                ),
                title: Text('${log['action']} on ${log['target_type']}'),
                subtitle: Text(
                  'Target: ${log['target_id'] ?? 'N/A'}\nTime: ${log['created_at']}',
                  style: const TextStyle(fontSize: 12),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
