import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/data/auth_repository.dart';
import '../../features/profile/data/profile_repository.dart';
import '../router/route_names.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// Responsive application shell matching the design.html floating dark sidebar
class AppShell extends ConsumerWidget {
  final Widget child;

  const AppShell({super.key, required this.child});

  int _calculateSelectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    if (location == RouteNames.home || location == '/') return 0;
    if (location.startsWith(RouteNames.blog) &&
        !location.startsWith('/blog/bookmarks')) {
      return 1;
    }
    if (location.startsWith(RouteNames.chat)) return 2;
    if (location.startsWith('/blog/bookmarks')) return 3;
    if (location.startsWith(RouteNames.profile) ||
        location.startsWith(RouteNames.contacts)) {
      return 4;
    }
    if (location.startsWith(RouteNames.admin)) return 5;
    return 0;
  }

  void _onNavigate(int index, BuildContext context) {
    switch (index) {
      case 0:
        context.go(RouteNames.home);
        break;
      case 1:
        context.go(RouteNames.blog);
        break;
      case 2:
        context.go(RouteNames.chat);
        break;
      case 3:
        context.push('/blog/bookmarks');
        break;
      case 4:
        context.go(RouteNames.profile);
        break;
      case 5:
        context.go(RouteNames.admin);
        break;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedIndex = _calculateSelectedIndex(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final profile = ref.watch(currentProfileProvider).valueOrNull;
    final authUser = ref.watch(authRepositoryProvider).currentUser;

    final displayName =
        profile?.displayName ??
        authUser?.userMetadata?['display_name'] as String? ??
        authUser?.email?.split('@').first ??
        'Tofiko M.';

    final publicId = profile?.publicId ?? 'WOH-2048-1137';

    String userInitials = 'TM';
    if (displayName.trim().isNotEmpty) {
      final parts = displayName.trim().split(RegExp(r'\s+'));
      if (parts.length >= 2) {
        userInitials = '${parts[0][0]}${parts[1][0]}'.toUpperCase();
      } else {
        userInitials = displayName
            .substring(0, displayName.length >= 2 ? 2 : 1)
            .toUpperCase();
      }
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWideScreen = constraints.maxWidth >= 900;

        if (isWideScreen) {
          return Scaffold(
            backgroundColor: AppColors.lightBackground,
            body: Row(
              children: [
                // Floating Dark Forest Green Sidebar (matches design.html)
                Container(
                  width: 250,
                  margin: const EdgeInsets.fromLTRB(16, 16, 0, 16),
                  decoration: BoxDecoration(
                    color: AppColors.sidebarDark,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.12),
                        blurRadius: 18,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 24,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. Logo & App Branding
                      Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: AppColors.accentAmber,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Center(
                              child: Text(
                                'W',
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 21,
                                  color: Color(0xFF1E1E1E),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'WAAN-OFIIHUB',
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  fontSize: 14.5,
                                  letterSpacing: 0.3,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Learn. Share. Grow.',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.sidebarItemText,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),

                      // 2. Navigation Items (matches design.html)
                      _buildSidebarItem(
                        context: context,
                        icon: Icons.home_outlined,
                        label: 'Home',
                        isActive: selectedIndex == 0,
                        onTap: () => _onNavigate(0, context),
                      ),
                      const SizedBox(height: 8),
                      _buildSidebarItem(
                        context: context,
                        icon: Icons.article_outlined,
                        label: 'Blog',
                        isActive: selectedIndex == 1,
                        onTap: () => _onNavigate(1, context),
                      ),
                      const SizedBox(height: 8),
                      _buildSidebarItem(
                        context: context,
                        icon: Icons.chat_bubble_outline_rounded,
                        label: 'Chat',
                        badgeText: '3',
                        isActive: selectedIndex == 2,
                        onTap: () => _onNavigate(2, context),
                      ),
                      const SizedBox(height: 8),
                      _buildSidebarItem(
                        context: context,
                        icon: Icons.bookmark_border_rounded,
                        label: 'Saved posts',
                        isActive: selectedIndex == 3,
                        onTap: () => _onNavigate(3, context),
                      ),
                      const SizedBox(height: 8),
                      _buildSidebarItem(
                        context: context,
                        icon: Icons.notifications_none_rounded,
                        label: 'Notifications',
                        isActive: selectedIndex == 4,
                        onTap: () => _onNavigate(4, context),
                      ),
                      const SizedBox(height: 8),
                      _buildSidebarItem(
                        context: context,
                        icon: Icons.shield_outlined,
                        label: 'Admin center',
                        isActive: selectedIndex == 5,
                        onTap: () => _onNavigate(5, context),
                      ),

                      const Spacer(),

                      // Theme mode toggle button
                      Center(
                        child: TextButton.icon(
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.sidebarItemText,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                          ),
                          icon: Icon(
                            isDark
                                ? Icons.light_mode_outlined
                                : Icons.dark_mode_outlined,
                            size: 16,
                          ),
                          label: Text(
                            isDark ? 'Light Theme' : 'Dark Theme',
                            style: const TextStyle(fontSize: 12),
                          ),
                          onPressed: () {
                            ref.read(themeModeProvider.notifier).toggleTheme();
                          },
                        ),
                      ),
                      const SizedBox(height: 12),

                      // 3. User Profile Card at Bottom (matches design.html)
                      InkWell(
                        onTap: () => context.go(RouteNames.profile),
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 18,
                                backgroundColor: AppColors.accentAmber,
                                child: Text(
                                  userInitials,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 12.5,
                                    color: Color(0xFF1E1E1E),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      displayName,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      publicId,
                                      style: const TextStyle(
                                        color: AppColors.sidebarItemText,
                                        fontSize: 10.5,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Main Workspace / Page Content
                Expanded(child: child),
              ],
            ),
          );
        }

        // Mobile Layout: Screen + Bottom Navigation Bar
        return Scaffold(
          body: child,
          bottomNavigationBar: NavigationBar(
            selectedIndex: selectedIndex.clamp(0, 4),
            onDestinationSelected: (idx) => _onNavigate(idx, context),
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home_rounded),
                label: 'Home',
              ),
              NavigationDestination(
                icon: Icon(Icons.article_outlined),
                selectedIcon: Icon(Icons.article_rounded),
                label: 'Blog',
              ),
              NavigationDestination(
                icon: Icon(Icons.chat_bubble_outline_rounded),
                selectedIcon: Icon(Icons.chat_bubble_rounded),
                label: 'Chat',
              ),
              NavigationDestination(
                icon: Icon(Icons.bookmark_border_rounded),
                selectedIcon: Icon(Icons.bookmark_rounded),
                label: 'Saved',
              ),
              NavigationDestination(
                icon: Icon(Icons.person_outline_rounded),
                selectedIcon: Icon(Icons.person_rounded),
                label: 'Profile',
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSidebarItem({
    required BuildContext context,
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
    String? badgeText,
  }) {
    if (isActive) {
      // Active White Rounded Pill (matches design.html)
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(icon, color: AppColors.primary, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              if (badgeText != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.accentAmber,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    badgeText,
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    }

    // Inactive Item (matches design.html)
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(icon, color: AppColors.sidebarItemText, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: AppColors.sidebarItemText,
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
            ),
            if (badgeText != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.accentAmber,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  badgeText,
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
