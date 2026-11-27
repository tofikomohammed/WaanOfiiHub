import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/config/env_config.dart';
import '../../../core/router/route_names.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/data/auth_repository.dart';
import '../../blog/data/blog_repository.dart';
import '../../chat/data/chat_repository.dart';
import '../../profile/data/profile_repository.dart';
import '../../rbac/data/rbac_repository.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  String _getTimeBasedGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final profile = ref.watch(currentProfileProvider).valueOrNull;
    final authUser = ref.watch(authRepositoryProvider).currentUser;
    final convsAsync = ref.watch(conversationsListProvider);
    final blogAsync = ref.watch(blogFeedProvider);
    final perms = ref.watch(myPermissionsProvider).valueOrNull ?? [];
    final canCreatePost = perms.contains('blog.create');

    final displayName =
        profile?.displayName ??
        authUser?.userMetadata?['display_name'] as String? ??
        authUser?.email?.split('@').first ??
        'User';

    final publicId = profile?.publicId ?? 'WOH-PENDING';

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.hub_rounded,
                size: 20,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              EnvConfig.appName,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
            ),
            tooltip: 'Toggle Theme',
            onPressed: () {
              ref.read(themeModeProvider.notifier).toggleTheme();
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Sign Out',
            onPressed: () async {
              await ref.read(authRepositoryProvider).signOut();
              ref.invalidate(currentProfileProvider);
              if (context.mounted) {
                context.go(RouteNames.login);
              }
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(currentProfileProvider);
          ref.invalidate(conversationsListProvider);
          ref.invalidate(blogFeedProvider);
        },
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          children: [
            // 1. Hero User Greeting Card
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? [
                          theme.colorScheme.surfaceContainerHighest,
                          theme.colorScheme.surface,
                        ]
                      : [
                          theme.colorScheme.primaryContainer.withAlpha(200),
                          theme.colorScheme.primaryContainer.withAlpha(70),
                        ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: theme.colorScheme.outline.withAlpha(51),
                ),
              ),
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Stack(
                        children: [
                          CircleAvatar(
                            radius: 26,
                            backgroundColor: theme.colorScheme.primary,
                            foregroundColor: Colors.white,
                            child: Text(
                              displayName.isNotEmpty
                                  ? displayName[0].toUpperCase()
                                  : 'U',
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          PositionedDirectional(
                            end: 0,
                            bottom: 0,
                            child: Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: Colors.green,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: theme.scaffoldBackgroundColor,
                                  width: 2,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${_getTimeBasedGreeting()},',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurface.withAlpha(
                                  179,
                                ),
                              ),
                            ),
                            Text(
                              displayName,
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      // Public ID Pill with copy
                      InkWell(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: publicId));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Copied Public ID: $publicId'),
                              duration: const Duration(seconds: 2),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surface,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withAlpha(15),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                publicId,
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                Icons.copy_rounded,
                                size: 13,
                                color: theme.colorScheme.primary,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Quick Stats Row
                  Row(
                    children: [
                      Expanded(
                        child: _buildMetricTile(
                          context,
                          icon: Icons.chat_bubble_rounded,
                          label: 'Messages',
                          value: convsAsync.maybeWhen(
                            data: (c) => '${c.length} Active',
                            orElse: () => 'Live',
                          ),
                          onTap: () => context.go(RouteNames.chat),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildMetricTile(
                          context,
                          icon: Icons.article_rounded,
                          label: 'Blog Posts',
                          value: blogAsync.maybeWhen(
                            data: (b) => '${b.length} Published',
                            orElse: () => 'Feed',
                          ),
                          onTap: () => context.go(RouteNames.blog),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildMetricTile(
                          context,
                          icon: Icons.verified_user_rounded,
                          label: 'Role',
                          value: perms.contains('roles.manage')
                              ? 'Admin'
                              : 'Member',
                          onTap: () => context.go(RouteNames.profile),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // 2. Direct Messages / Users Vertical List (Requirement 2)
            _buildUsersVerticalList(context, ref),
            const SizedBox(height: 24),

            // 3. Quick Action Buttons
            Text(
              'Quick Actions',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildActionChip(
                    context,
                    icon: Icons.chat_rounded,
                    label: 'New Message',
                    color: Colors.teal,
                    onTap: () => context.push('/contacts/search'),
                  ),
                  const SizedBox(width: 8),
                  if (canCreatePost) ...[
                    _buildActionChip(
                      context,
                      icon: Icons.post_add_rounded,
                      label: 'Create Post',
                      color: Colors.blue,
                      onTap: () => context.push('/blog/create'),
                    ),
                    const SizedBox(width: 8),
                    _buildActionChip(
                      context,
                      icon: Icons.drafts_outlined,
                      label: 'My Drafts',
                      color: Colors.deepOrange,
                      onTap: () => context.push('/blog/drafts'),
                    ),
                    const SizedBox(width: 8),
                  ],
                  _buildActionChip(
                    context,
                    icon: Icons.contact_phone_rounded,
                    label: 'Sync Contacts',
                    color: Colors.indigo,
                    onTap: () => context.go(RouteNames.contacts),
                  ),
                  const SizedBox(width: 8),
                  _buildActionChip(
                    context,
                    icon: Icons.person_rounded,
                    label: 'Edit Profile',
                    color: Colors.purple,
                    onTap: () => context.push('/profile/edit'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 3. Recent Chats Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.chat_bubble_outline_rounded,
                      size: 20,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Recent Chats',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: () => context.go(RouteNames.chat),
                  child: const Text('View All'),
                ),
              ],
            ),
            convsAsync.when(
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (err, stack) => const SizedBox.shrink(),
              data: (convs) {
                if (convs.isEmpty) {
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.forum_outlined,
                            size: 36,
                            color: Colors.grey,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'No conversations yet',
                            style: theme.textTheme.titleSmall,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Find a friend by Public ID or phone number to chat.',
                            style: theme.textTheme.bodySmall,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            onPressed: () => context.push('/contacts/search'),
                            icon: const Icon(Icons.search, size: 16),
                            label: const Text('Find People'),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final previewList = convs.take(3).toList();
                return Card(
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: previewList.length,
                    separatorBuilder: (context, index) =>
                        const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final c = previewList[index];
                      final time = c.lastMessageAt != null
                          ? DateFormat.jm().format(c.lastMessageAt!)
                          : '';

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: theme.colorScheme.primaryContainer,
                          child: Icon(
                            c.type == 'community'
                                ? Icons.hub_rounded
                                : (c.type == 'group'
                                      ? Icons.group_rounded
                                      : Icons.person_rounded),
                            color: theme.colorScheme.primary,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          c.title,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          c.lastMessageText ?? 'No messages yet',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(time, style: theme.textTheme.bodySmall),
                            if (c.unreadCount > 0)
                              Badge.count(count: c.unreadCount),
                          ],
                        ),
                        onTap: () => context.push('/chat/${c.id}'),
                      );
                    },
                  ),
                );
              },
            ),
            const SizedBox(height: 24),

            // 4. Latest From Blog Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.article_outlined,
                      size: 20,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Latest Posts',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: () => context.go(RouteNames.blog),
                  child: const Text('View All'),
                ),
              ],
            ),
            blogAsync.when(
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (err, stack) => const SizedBox.shrink(),
              data: (posts) {
                if (posts.isEmpty) {
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.newspaper_outlined,
                            size: 36,
                            color: Colors.grey,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'No published posts yet',
                            style: theme.textTheme.titleSmall,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Articles, news and podcasts will appear here once published.',
                            style: theme.textTheme.bodySmall,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final previewPosts = posts.take(3).toList();
                return Column(
                  children: previewPosts.map((post) {
                    final dateStr = post.publishedAt != null
                        ? DateFormat.yMMMd().format(post.publishedAt!)
                        : '';

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () => context.push('/blog/${post.id}'),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (post.coverUrl != null &&
                                post.coverUrl!.isNotEmpty)
                              CachedNetworkImage(
                                imageUrl: post.coverUrl!,
                                width: 100,
                                height: 100,
                                fit: BoxFit.cover,
                                errorWidget: (context, url, error) => Container(
                                  width: 100,
                                  height: 100,
                                  color:
                                      theme.colorScheme.surfaceContainerHighest,
                                  child: const Icon(Icons.image_not_supported),
                                ),
                              )
                            else
                              Container(
                                width: 100,
                                height: 100,
                                color: theme.colorScheme.primaryContainer,
                                child: Icon(
                                  post.type == 'audio'
                                      ? Icons.podcasts_rounded
                                      : Icons.article_rounded,
                                  color: theme.colorScheme.primary,
                                  size: 36,
                                ),
                              ),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: theme
                                                .colorScheme
                                                .primaryContainer,
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                          ),
                                          child: Text(
                                            post.type.toUpperCase(),
                                            style: TextStyle(
                                              fontSize: 9,
                                              fontWeight: FontWeight.bold,
                                              color: theme.colorScheme.primary,
                                            ),
                                          ),
                                        ),
                                        const Spacer(),
                                        Text(
                                          dateStr,
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(fontSize: 10),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      post.title,
                                      style: theme.textTheme.titleSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        Icon(
                                          post.isLikedByMe
                                              ? Icons.favorite
                                              : Icons.favorite_border,
                                          size: 14,
                                          color: post.isLikedByMe
                                              ? Colors.red
                                              : null,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          '${post.likesCount}',
                                          style: const TextStyle(fontSize: 11),
                                        ),
                                        const SizedBox(width: 12),
                                        const Icon(
                                          Icons.mode_comment_outlined,
                                          size: 14,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          '${post.commentsCount}',
                                          style: const TextStyle(fontSize: 11),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricTile(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Icon(icon, size: 20, color: theme.colorScheme.primary),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionChip(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ActionChip(
      avatar: CircleAvatar(
        backgroundColor: color.withAlpha(40),
        child: Icon(icon, size: 14, color: color),
      ),
      label: Text(label),
      onPressed: onTap,
    );
  }

  Widget _buildUsersVerticalList(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(allUsersProvider);
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(
                  Icons.people_alt_rounded,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Community Members',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.refresh_rounded, size: 20),
              tooltip: 'Refresh users',
              onPressed: () => ref.invalidate(allUsersProvider),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          'Select any user below to start a private 1-on-1 chat:',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 10),
        usersAsync.when(
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: CircularProgressIndicator(),
            ),
          ),
          error: (err, _) => Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.amber),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text('Unable to load users list at the moment.'),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: () => ref.invalidate(allUsersProvider),
                  ),
                ],
              ),
            ),
          ),
          data: (users) {
            if (users.isEmpty) {
              return Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: theme.colorScheme.outlineVariant),
                ),
                child: const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Icon(Icons.person_outline, color: Colors.grey),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'No other users registered yet. Invite friends to start chatting!',
                          style: TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: users.length,
              separatorBuilder: (context, index) => const SizedBox(height: 6),
              itemBuilder: (context, index) {
                final user = users[index];
                return Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: theme.colorScheme.outlineVariant),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 2,
                    ),
                    leading: CircleAvatar(
                      radius: 20,
                      backgroundColor: theme.colorScheme.primaryContainer,
                      foregroundColor: theme.colorScheme.primary,
                      child: Text(
                        user.displayName.isNotEmpty
                            ? user.displayName[0].toUpperCase()
                            : 'U',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    title: Row(
                      children: [
                        Flexible(
                          child: Text(
                            user.displayName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.secondaryContainer
                                .withAlpha(128),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            user.publicId,
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSecondaryContainer,
                            ),
                          ),
                        ),
                      ],
                    ),
                    subtitle: Text(
                      user.about != null && user.about!.isNotEmpty
                          ? user.about!
                          : (user.phoneE164 ?? 'Tap to chat privately'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    trailing: FilledButton.tonalIcon(
                      style: FilledButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                      ),
                      icon: const Icon(
                        Icons.chat_bubble_outline_rounded,
                        size: 15,
                      ),
                      label: const Text('Chat'),
                      onPressed: () async {
                        final convId = await ref
                            .read(chatRepositoryProvider)
                            .startDirectChat(user.id);
                        if (convId != null && context.mounted) {
                          unawaited(context.push('/chat/$convId'));
                        }
                      },
                    ),
                    onTap: () async {
                      final convId = await ref
                          .read(chatRepositoryProvider)
                          .startDirectChat(user.id);
                      if (convId != null && context.mounted) {
                        unawaited(context.push('/chat/$convId'));
                      }
                    },
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }
}
