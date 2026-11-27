import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../chat/data/chat_repository.dart';
import '../../profile/data/profile_repository.dart';
import '../data/contacts_repository.dart';

class UserSearchScreen extends ConsumerStatefulWidget {
  const UserSearchScreen({super.key});

  @override
  ConsumerState<UserSearchScreen> createState() => _UserSearchScreenState();
}

class _UserSearchScreenState extends ConsumerState<UserSearchScreen> {
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _results = [];
  bool _isSearching = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _handleSearch(String query) async {
    final q = query.trim();
    if (q.isEmpty) {
      setState(() => _results = []);
      return;
    }

    setState(() => _isSearching = true);
    try {
      final res = await ref.read(contactsRepositoryProvider).searchUsers(q);
      setState(() => _results = res);
    } catch (_) {}
    setState(() => _isSearching = false);
  }

  @override
  Widget build(BuildContext context) {
    final allUsersAsync = ref.watch(allUsersProvider);
    final isQueryEmpty = _searchController.text.trim().isEmpty;

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          autofocus: false,
          decoration: const InputDecoration(
            hintText: 'Search by Public ID (WOH-...) or Name',
            border: InputBorder.none,
          ),
          onChanged: (val) => unawaited(_handleSearch(val)),
        ),
        actions: [
          if (_searchController.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear_rounded),
              onPressed: () {
                _searchController.clear();
                setState(() => _results = []);
              },
            ),
        ],
      ),
      body: _isSearching
          ? const Center(child: CircularProgressIndicator())
          : !isQueryEmpty
          ? (_results.isEmpty
                ? const Center(child: Text('No matching users found.'))
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _results.length,
                    separatorBuilder: (context, index) =>
                        const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final u = _results[index];
                      final name = u['display_name'] as String? ?? 'User';
                      final publicId = u['public_id'] as String? ?? '';
                      final uid = u['id'] as String;

                      return ListTile(
                        leading: CircleAvatar(
                          child: Text(
                            name.isNotEmpty ? name[0].toUpperCase() : 'U',
                          ),
                        ),
                        title: Text(
                          name,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text('ID: $publicId'),
                        trailing: FilledButton.tonalIcon(
                          icon: const Icon(
                            Icons.chat_bubble_outline_rounded,
                            size: 16,
                          ),
                          label: const Text('Chat'),
                          onPressed: () async {
                            final convId = await ref
                                .read(chatRepositoryProvider)
                                .startDirectChat(uid);
                            if (convId != null && context.mounted) {
                              unawaited(context.push('/chat/$convId'));
                            }
                          },
                        ),
                        onTap: () async {
                          final convId = await ref
                              .read(chatRepositoryProvider)
                              .startDirectChat(uid);
                          if (convId != null && context.mounted) {
                            unawaited(context.push('/chat/$convId'));
                          }
                        },
                      );
                    },
                  ))
          : allUsersAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('Error: $err')),
              data: (users) {
                if (users.isEmpty) {
                  return const Center(
                    child: Text('No other users registered yet.'),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: users.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final u = users[index];
                    return ListTile(
                      leading: CircleAvatar(
                        child: Text(
                          u.displayName.isNotEmpty
                              ? u.displayName[0].toUpperCase()
                              : 'U',
                        ),
                      ),
                      title: Text(
                        u.displayName,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text('ID: ${u.publicId}'),
                      trailing: FilledButton.tonalIcon(
                        icon: const Icon(
                          Icons.chat_bubble_outline_rounded,
                          size: 16,
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
                    );
                  },
                );
              },
            ),
    );
  }
}
