import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../rbac/data/rbac_repository.dart';

class AdminScreen extends ConsumerWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final perms = ref.watch(myPermissionsProvider).valueOrNull ?? [];

    final canManageRoles = perms.contains('roles.manage');
    final canViewUsers = perms.contains('users.view');
    final canViewAudit = perms.contains('audit.view');
    final canReviewReports = perms.contains('reports.review');
    final canManageMedia = perms.contains('blog.edit_any') || canManageRoles;

    if (!canManageRoles &&
        !canViewUsers &&
        !canViewAudit &&
        !canReviewReports &&
        !canManageMedia) {
      return Scaffold(
        appBar: AppBar(title: const Text('Admin Panel')),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: theme.colorScheme.outlineVariant),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer.withAlpha(51),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.shield_outlined,
                        size: 48,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Administrative Access Required',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Your account currently has standard member privileges. Administrative tools (User Management, Roles & RBAC, Audit Logs) are restricted to Superadmin and Admin roles.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Check / Refresh Permissions'),
                      onPressed: () => ref.invalidate(myPermissionsProvider),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Administration')),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          if (canViewUsers)
            Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: theme.colorScheme.primaryContainer,
                  child: const Icon(Icons.people_alt_outlined),
                ),
                title: const Text('User Management'),
                subtitle: const Text(
                  'View registered users, assign roles, and apply bans',
                ),
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                onTap: () => context.push('/admin/users'),
              ),
            ),
          if (canManageRoles) ...[
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: theme.colorScheme.secondaryContainer,
                  child: const Icon(Icons.security_outlined),
                ),
                title: const Text('Roles & Permissions'),
                subtitle: const Text(
                  'Inspect RBAC roles, permission sets, and system roles',
                ),
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                onTap: () => context.push('/admin/roles'),
              ),
            ),
          ],
          if (canReviewReports) ...[
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Colors.amber,
                  child: Icon(Icons.gavel_rounded, color: Colors.white),
                ),
                title: const Text('Moderation Reports'),
                subtitle: const Text(
                  'Review flagged messages and action user reports',
                ),
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                onTap: () => context.push('/admin/reports'),
              ),
            ),
          ],
          if (canViewAudit) ...[
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Colors.blueGrey,
                  child: Icon(Icons.history_rounded, color: Colors.white),
                ),
                title: const Text('Audit Logs'),
                subtitle: const Text(
                  'Track security events, role changes, and admin actions',
                ),
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                onTap: () => context.push('/admin/audit'),
              ),
            ),
          ],
          if (canManageMedia) ...[
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: theme.colorScheme.tertiaryContainer,
                  child: const Icon(Icons.perm_media_outlined),
                ),
                title: const Text('Media Manager'),
                subtitle: const Text(
                  'Inspect storage assets, clean up orphaned files and manage media',
                ),
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                onTap: () => context.push('/admin/media'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
