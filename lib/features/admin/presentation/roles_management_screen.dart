import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../../rbac/data/rbac_repository.dart';

final rolesListProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  return ref.watch(rbacRepositoryProvider).getRoles();
});

class RolesManagementScreen extends ConsumerWidget {
  const RolesManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rolesAsync = ref.watch(rolesListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('RBAC Roles & Policies')),
      body: rolesAsync.when(
        loading: () => const LoadingIndicator(message: 'Loading roles...'),
        error: (err, stack) => ErrorView(
          message: 'Unable to load roles',
          onRetry: () => ref.refresh(rolesListProvider),
        ),
        data: (roles) {
          return ListView.separated(
            padding: const EdgeInsets.all(16.0),
            itemCount: roles.length,
            separatorBuilder: (context, index) => const Divider(),
            itemBuilder: (context, index) {
              final role = roles[index];
              final isSystem = role['is_system'] as bool? ?? false;

              return ListTile(
                leading: CircleAvatar(
                  child: Icon(isSystem ? Icons.shield : Icons.badge),
                ),
                title: Text(role['name'] as String? ?? ''),
                subtitle: Text(
                  '${role['key']} • ${role['description'] ?? 'No description'}',
                ),
                trailing: isSystem
                    ? const Chip(
                        label: Text('System', style: TextStyle(fontSize: 10)),
                      )
                    : null,
              );
            },
          );
        },
      ),
    );
  }
}
