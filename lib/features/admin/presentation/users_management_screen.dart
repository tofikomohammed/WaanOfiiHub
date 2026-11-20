import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/supabase_config.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../../rbac/data/rbac_repository.dart';

final adminUsersListProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  final client = isSupabaseInitialized
      ? ref.watch(supabaseClientProvider)
      : null;
  if (client == null) return [];
  final res = await client
      .from('profiles')
      .select(
        'id, public_id, display_name, username, phone_e164, is_banned, created_at',
      )
      .order('created_at', ascending: false)
      .limit(50);
  return List<Map<String, dynamic>>.from(res);
});

class UsersManagementScreen extends ConsumerWidget {
  const UsersManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(adminUsersListProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Users Management'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(adminUsersListProvider),
          ),
        ],
      ),
      body: usersAsync.when(
        loading: () => const LoadingIndicator(message: 'Loading users...'),
        error: (err, stack) => ErrorView(
          message: 'Unable to load users',
          onRetry: () => ref.invalidate(adminUsersListProvider),
        ),
        data: (users) {
          if (users.isEmpty) {
            return const Center(child: Text('No users found.'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16.0),
            itemCount: users.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final user = users[index];
              final isBanned = user['is_banned'] as bool? ?? false;
              final name = user['display_name'] as String? ?? 'User';
              final publicId = user['public_id'] as String? ?? '';
              final uid = user['id'] as String;

              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: isBanned
                      ? Colors.red.shade100
                      : theme.colorScheme.primaryContainer,
                  child: Icon(
                    isBanned ? Icons.block : Icons.person,
                    color: isBanned ? Colors.red : theme.colorScheme.primary,
                  ),
                ),
                title: Text('$name ($publicId)'),
                subtitle: Text('Status: ${isBanned ? 'Banned' : 'Active'}'),
                trailing: PopupMenuButton<String>(
                  onSelected: (action) async {
                    if (action == 'toggle_ban') {
                      await ref
                          .read(rbacRepositoryProvider)
                          .setBanStatus(
                            uid,
                            !isBanned,
                            !isBanned
                                ? 'Admin manual ban'
                                : 'Unbanned by admin',
                          );
                      ref.invalidate(adminUsersListProvider);
                    } else if (action == 'assign_admin') {
                      await ref
                          .read(rbacRepositoryProvider)
                          .assignRole(uid, 'admin');
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Assigned admin role')),
                        );
                      }
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'toggle_ban',
                      child: Text(isBanned ? 'Unban User' : 'Ban User'),
                    ),
                    const PopupMenuItem(
                      value: 'assign_admin',
                      child: Text('Grant Admin Role'),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
