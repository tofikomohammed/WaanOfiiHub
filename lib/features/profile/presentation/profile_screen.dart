import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_names.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../../auth/data/auth_repository.dart';
import '../data/profile_repository.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final profileAsync = ref.watch(currentProfileProvider);
    final authUser = ref.watch(authRepositoryProvider).currentUser;

    if (authUser == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Profile')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.account_circle_outlined, size: 64),
              const SizedBox(height: 16),
              Text('Not signed in', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              const Text('Sign in or register to view your profile.'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => context.go(RouteNames.login),
                child: const Text('Sign In'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit Profile',
            onPressed: () => context.push('/profile/edit'),
          ),
        ],
      ),
      body: profileAsync.when(
        loading: () => const LoadingIndicator(message: 'Loading profile...'),
        error: (err, stack) => ErrorView(
          message: 'Unable to load profile',
          onRetry: () => ref.invalidate(currentProfileProvider),
        ),
        data: (profile) {
          final p = profile;
          if (p == null) {
            return const Center(child: Text('Profile not found'));
          }

          return ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              // Avatar & Name Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 40,
                        backgroundColor: theme.colorScheme.primaryContainer,
                        child: Text(
                          p.displayName.isNotEmpty
                              ? p.displayName[0].toUpperCase()
                              : 'U',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(p.displayName, style: theme.textTheme.titleLarge),
                      if (p.username != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          '@${p.username}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface.withAlpha(153),
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      // Public ID with copy button
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'ID: ${p.publicId}',
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.copy_rounded, size: 16),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              tooltip: 'Copy Public ID',
                              onPressed: () {
                                Clipboard.setData(
                                  ClipboardData(text: p.publicId),
                                );
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Public ID copied!'),
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Details & Privacy Settings
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.info_outline),
                      title: const Text('About'),
                      subtitle: Text(p.about ?? 'No bio provided'),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.phone_outlined),
                      title: const Text('Phone Number'),
                      subtitle: Text(
                        p.phoneE164 != null
                            ? '${p.phoneE164} (${p.phoneVerified ? 'Verified' : 'Unverified'})'
                            : 'No phone linked',
                      ),
                    ),
                    const Divider(height: 1),
                    SwitchListTile(
                      secondary: const Icon(Icons.visibility_outlined),
                      title: const Text('Show Last Seen'),
                      subtitle: const Text(
                        'Allow others to view when you were last online',
                      ),
                      value: p.showLastSeen,
                      onChanged: (val) async {
                        await ref
                            .read(profileRepositoryProvider)
                            .updateProfile(userId: p.id, showLastSeen: val);
                        ref.invalidate(currentProfileProvider);
                      },
                    ),
                    const Divider(height: 1),
                    SwitchListTile(
                      secondary: const Icon(Icons.contact_phone_outlined),
                      title: const Text('Allow Phone Discovery'),
                      subtitle: const Text(
                        'Allow contacts to match with you via hashed phone',
                      ),
                      value: p.allowPhoneDiscovery,
                      onChanged: (val) async {
                        await ref
                            .read(profileRepositoryProvider)
                            .updateProfile(
                              userId: p.id,
                              allowPhoneDiscovery: val,
                            );
                        ref.invalidate(currentProfileProvider);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Logout Button
              OutlinedButton.icon(
                icon: const Icon(Icons.logout_rounded, color: Colors.red),
                label: const Text(
                  'Sign Out',
                  style: TextStyle(color: Colors.red),
                ),
                onPressed: () async {
                  await ref.read(authRepositoryProvider).signOut();
                  if (context.mounted) {
                    context.go(RouteNames.login);
                  }
                },
              ),
            ],
          );
        },
      ),
    );
  }
}
