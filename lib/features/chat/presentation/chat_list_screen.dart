import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../../profile/data/profile_repository.dart';
import '../data/chat_repository.dart';

class ChatListScreen extends ConsumerWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final convsAsync = ref.watch(conversationsListProvider);
    final usersAsync = ref.watch(allUsersProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Messages & Direct Chat'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: () {
              ref.invalidate(conversationsListProvider);
              ref.invalidate(allUsersProvider);
            },
          ),
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'Search Users',
            onPressed: () => context.push('/contacts/search'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(conversationsListProvider);
          ref.invalidate(allUsersProvider);
        },
        child: convsAsync.when(
          loading: () => const LoadingIndicator(message: 'Loading chats...'),
          error: (err, stack) {
            final isMissingTable =
                err.toString().contains('PGRST205') ||
                err.toString().contains('conversation_members') ||
                err.toString().contains('conversations');
            return ErrorView(
              message: isMissingTable
                  ? 'Chat database tables are not created in Supabase yet. Run fix_all.sql in Supabase SQL Editor.'
                  : 'Unable to load conversations',
              technicalDetails: err.toString(),
              onRetry: () => ref.invalidate(conversationsListProvider),
            );
          },
          data: (convs) {
            return ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              children: [
                // 1. Active Chats (if any)
                if (convs.isNotEmpty) ...[
                  Row(
                    children: [
                      Icon(
                        Icons.forum_rounded,
                        size: 18,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Recent Conversations',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ...convs.map((conv) {
                    final timeStr = conv.lastMessageAt != null
                        ? DateFormat.jm().format(conv.lastMessageAt!)
                        : '';
                    return Card(
                      elevation: 0,
                      margin: const EdgeInsets.only(bottom: 6),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: theme.colorScheme.outlineVariant,
                        ),
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: conv.type == 'community'
                              ? Colors.deepPurple.shade100
                              : theme.colorScheme.primaryContainer,
                          child: Icon(
                            conv.type == 'community'
                                ? Icons.hub_rounded
                                : (conv.type == 'group'
                                      ? Icons.group_rounded
                                      : Icons.person_rounded),
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        title: Text(
                          conv.title,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          conv.lastMessageText ?? 'No messages yet',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            if (timeStr.isNotEmpty)
                              Text(
                                timeStr,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontSize: 11,
                                ),
                              ),
                            if (conv.unreadCount > 0) ...[
                              const SizedBox(height: 4),
                              Badge.count(count: conv.unreadCount),
                            ],
                          ],
                        ),
                        onTap: () => context.push('/chat/${conv.id}'),
                      ),
                    );
                  }),
                  const Divider(height: 28),
                ],

                // 2. Vertical list of registered users for 1-on-1 direct chat
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.person_search_rounded,
                          size: 18,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          convs.isEmpty
                              ? 'Select a User to Chat'
                              : 'All Users (Start Direct Chat)',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh, size: 18),
                      tooltip: 'Refresh users list',
                      onPressed: () => ref.invalidate(allUsersProvider),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Tap any user to start a private 1-on-1 peer-to-peer chat:',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 10),
                usersAsync.when(
                  loading: () => const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20.0),
                      child: CircularProgressIndicator(),
                    ),
                  ),
                  error: (err, _) => Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Text(
                      'Unable to load users: $err',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ),
                  data: (users) {
                    if (users.isEmpty) {
                      return Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: theme.colorScheme.outlineVariant,
                          ),
                        ),
                        child: const Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Text(
                            'No other users registered yet. Invite friends to start chatting!',
                            style: TextStyle(fontSize: 13),
                          ),
                        ),
                      );
                    }

                    return ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: users.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 6),
                      itemBuilder: (context, index) {
                        final u = users[index];
                        return Card(
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: theme.colorScheme.outlineVariant,
                            ),
                          ),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor:
                                  theme.colorScheme.primaryContainer,
                              foregroundColor: theme.colorScheme.primary,
                              child: Text(
                                u.displayName.isNotEmpty
                                    ? u.displayName[0].toUpperCase()
                                    : 'U',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            title: Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    u.displayName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
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
                                    u.publicId,
                                    style: TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: theme
                                          .colorScheme
                                          .onSecondaryContainer,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            subtitle: Text(
                              u.about != null && u.about!.isNotEmpty
                                  ? u.about!
                                  : (u.phoneE164 ?? 'Private 1-on-1 chat'),
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
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                              ),
                              icon: const Icon(
                                Icons.chat_bubble_outline_rounded,
                                size: 15,
                              ),
                              label: const Text('Chat'),
                              onPressed: () async {
                                final convId = await ref
                                    .read(chatRepositoryProvider)
                                    .startDirectChat(u.id);
                                if (convId != null && context.mounted) {
                                  unawaited(context.push('/chat/$convId'));
                                }
                              },
                            ),
                            onTap: () async {
                              final convId = await ref
                                  .read(chatRepositoryProvider)
                                  .startDirectChat(u.id);
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
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Search Users',
        onPressed: () => context.push('/contacts/search'),
        child: const Icon(Icons.person_search_rounded),
      ),
    );
  }
}
