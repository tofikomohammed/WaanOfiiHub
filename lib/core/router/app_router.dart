import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../config/env_config.dart';
import '../../features/admin/presentation/admin_media_screen.dart';
import '../../features/admin/presentation/admin_screen.dart';
import '../../features/admin/presentation/audit_logs_screen.dart';
import '../../features/admin/presentation/roles_management_screen.dart';
import '../../features/admin/presentation/users_management_screen.dart';
import '../../features/auth/presentation/auth_state.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/blog/presentation/blog_create_screen.dart';
import '../../features/blog/presentation/blog_detail_screen.dart';
import '../../features/blog/presentation/blog_edit_screen.dart';
import '../../features/blog/presentation/blog_feed_screen.dart';
import '../../features/blog/presentation/my_drafts_screen.dart';
import '../../features/chat/presentation/chat_conversation_screen.dart';
import '../../features/chat/presentation/chat_list_screen.dart';
import '../../features/chat/presentation/create_group_screen.dart';
import '../../features/contacts/presentation/contacts_screen.dart';
import '../../features/contacts/presentation/user_search_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/profile/presentation/edit_profile_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../widgets/app_shell.dart';
import '../widgets/unconfigured_screen.dart';
import 'route_names.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authNotifier = ref.watch(authNotifierProvider);

  return GoRouter(
    initialLocation: RouteNames.home,
    refreshListenable: authNotifier,
    redirect: (context, state) {
      if (!EnvConfig.isConfigured) {
        if (state.uri.path != RouteNames.unconfigured) {
          return RouteNames.unconfigured;
        }
        return null;
      }

      final isLoggedIn = authNotifier.isAuthenticated;
      final isAuthRoute =
          state.uri.path == RouteNames.login ||
          state.uri.path == RouteNames.register;

      // Unauthenticated users are redirected directly to login
      if (!isLoggedIn) {
        if (!isAuthRoute) {
          return RouteNames.login;
        }
        return null;
      }

      // Authenticated users visiting login/register go to Home
      if (isAuthRoute) {
        return RouteNames.home;
      }

      return null;
    },
    routes: [
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: RouteNames.home,
            builder: (context, state) => const HomeScreen(),
          ),
          GoRoute(
            path: RouteNames.blog,
            builder: (context, state) => const BlogFeedScreen(),
          ),
          GoRoute(
            path: RouteNames.chat,
            builder: (context, state) => const ChatListScreen(),
          ),
          GoRoute(
            path: RouteNames.contacts,
            builder: (context, state) => const ContactsScreen(),
          ),
          GoRoute(
            path: RouteNames.profile,
            builder: (context, state) => const ProfileScreen(),
          ),
          GoRoute(
            path: RouteNames.admin,
            builder: (context, state) => const AdminScreen(),
          ),
        ],
      ),
      // Blog sub-routes
      GoRoute(
        path: '/blog/create',
        builder: (context, state) => const BlogCreateScreen(),
      ),
      GoRoute(
        path: '/blog/drafts',
        builder: (context, state) => const MyDraftsScreen(),
      ),
      GoRoute(
        path: '/blog/edit/:id',
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return BlogEditScreen(postId: id);
        },
      ),
      GoRoute(
        path: '/blog/:id',
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return BlogDetailScreen(postId: id);
        },
      ),
      // Chat sub-routes
      GoRoute(
        path: '/chat/create-group',
        builder: (context, state) => const CreateGroupScreen(),
      ),
      GoRoute(
        path: '/chat/:id',
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return ChatConversationScreen(conversationId: id);
        },
      ),
      // Contacts sub-routes
      GoRoute(
        path: '/contacts/search',
        builder: (context, state) => const UserSearchScreen(),
      ),
      // Profile sub-routes
      GoRoute(
        path: '/profile/edit',
        builder: (context, state) => const EditProfileScreen(),
      ),
      // Admin sub-routes
      GoRoute(
        path: '/admin/users',
        builder: (context, state) => const UsersManagementScreen(),
      ),
      GoRoute(
        path: '/admin/roles',
        builder: (context, state) => const RolesManagementScreen(),
      ),
      GoRoute(
        path: '/admin/audit',
        builder: (context, state) => const AuditLogsScreen(),
      ),
      GoRoute(
        path: '/admin/media',
        builder: (context, state) => const AdminMediaScreen(),
      ),
      // Auth routes
      GoRoute(
        path: RouteNames.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: RouteNames.register,
        builder: (context, state) => const RegisterScreen(),
      ),
      // Unconfigured fallback
      GoRoute(
        path: RouteNames.unconfigured,
        builder: (context, state) => const UnconfiguredScreen(),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      appBar: AppBar(title: const Text('Page Not Found')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.orange),
            const SizedBox(height: 16),
            Text('404 - Page Not Found',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(state.uri.toString()),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => context.go(RouteNames.home),
              child: const Text('Back to Home'),
            ),
          ],
        ),
      ),
    ),
  );
});
