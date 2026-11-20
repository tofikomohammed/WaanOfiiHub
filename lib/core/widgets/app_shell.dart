import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../router/route_names.dart';
import '../theme/app_theme.dart';

/// Responsive application shell supporting BottomNavigationBar (mobile)
/// and NavigationRail (web/desktop/tablet).
class AppShell extends ConsumerWidget {
  final Widget child;

  const AppShell({super.key, required this.child});

  int _calculateSelectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    if (location.startsWith(RouteNames.chat)) return 1;
    if (location.startsWith(RouteNames.contacts)) return 2;
    if (location.startsWith(RouteNames.profile)) return 3;
    if (location.startsWith(RouteNames.admin)) return 4;
    return 0; // Home / Blog
  }

  void _onItemTapped(int index, BuildContext context) {
    switch (index) {
      case 0:
        context.go(RouteNames.home);
        break;
      case 1:
        context.go(RouteNames.chat);
        break;
      case 2:
        context.go(RouteNames.contacts);
        break;
      case 3:
        context.go(RouteNames.profile);
        break;
      case 4:
        context.go(RouteNames.admin);
        break;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedIndex = _calculateSelectedIndex(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    const navDestinations = [
      NavigationDestination(
        icon: Icon(Icons.article_outlined),
        selectedIcon: Icon(Icons.article_rounded),
        label: 'Blog',
      ),
      NavigationDestination(
        icon: Icon(Icons.chat_bubble_outline_rounded),
        selectedIcon: Icon(Icons.chat_bubble_rounded),
        label: 'Chats',
      ),
      NavigationDestination(
        icon: Icon(Icons.people_outline_rounded),
        selectedIcon: Icon(Icons.people_rounded),
        label: 'Contacts',
      ),
      NavigationDestination(
        icon: Icon(Icons.person_outline_rounded),
        selectedIcon: Icon(Icons.person_rounded),
        label: 'Profile',
      ),
      NavigationDestination(
        icon: Icon(Icons.admin_panel_settings_outlined),
        selectedIcon: Icon(Icons.admin_panel_settings_rounded),
        label: 'Admin',
      ),
    ];

    const railDestinations = [
      NavigationRailDestination(
        icon: Icon(Icons.article_outlined),
        selectedIcon: Icon(Icons.article_rounded),
        label: Text('Blog'),
      ),
      NavigationRailDestination(
        icon: Icon(Icons.chat_bubble_outline_rounded),
        selectedIcon: Icon(Icons.chat_bubble_rounded),
        label: Text('Chats'),
      ),
      NavigationRailDestination(
        icon: Icon(Icons.people_outline_rounded),
        selectedIcon: Icon(Icons.people_rounded),
        label: Text('Contacts'),
      ),
      NavigationRailDestination(
        icon: Icon(Icons.person_outline_rounded),
        selectedIcon: Icon(Icons.person_rounded),
        label: Text('Profile'),
      ),
      NavigationRailDestination(
        icon: Icon(Icons.admin_panel_settings_outlined),
        selectedIcon: Icon(Icons.admin_panel_settings_rounded),
        label: Text('Admin'),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWideScreen = constraints.maxWidth >= 720;

        if (isWideScreen) {
          return Scaffold(
            body: Row(
              children: [
                NavigationRail(
                  selectedIndex: selectedIndex,
                  onDestinationSelected: (idx) => _onItemTapped(idx, context),
                  labelType: NavigationRailLabelType.all,
                  leading: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                    child: IconButton(
                      tooltip: 'Toggle Theme',
                      icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
                      onPressed: () {
                        ref.read(themeModeProvider.notifier).toggleTheme();
                      },
                    ),
                  ),
                  destinations: railDestinations,
                ),
                const VerticalDivider(thickness: 1, width: 1),
                Expanded(child: child),
              ],
            ),
          );
        }

        return Scaffold(
          body: child,
          bottomNavigationBar: NavigationBar(
            selectedIndex: selectedIndex,
            onDestinationSelected: (idx) => _onItemTapped(idx, context),
            destinations: navDestinations,
          ),
        );
      },
    );
  }
}
