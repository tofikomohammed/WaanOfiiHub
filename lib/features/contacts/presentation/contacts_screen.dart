import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../../chat/data/chat_repository.dart';
import '../data/contacts_repository.dart';

class ContactsScreen extends ConsumerWidget {
  const ContactsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contactsAsync = ref.watch(matchedContactsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Contacts & Sync'),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync_rounded),
            tooltip: 'Sync Contacts',
            onPressed: () => ref.invalidate(matchedContactsProvider),
          ),
          IconButton(
            icon: const Icon(Icons.search_rounded),
            tooltip: 'Search by Public ID',
            onPressed: () => context.push('/contacts/search'),
          ),
        ],
      ),
      body: contactsAsync.when(
        loading: () => const LoadingIndicator(message: 'Matching contacts...'),
        error: (err, _) => ErrorView(
          message: 'Contact permission denied or unable to match contacts.',
          onRetry: () => ref.invalidate(matchedContactsProvider),
        ),
        data: (contacts) {
          if (contacts.isEmpty) {
            return EmptyState(
              icon: Icons.contacts_outlined,
              title: kIsWeb ? 'Find Friends & Chat' : 'No Contacts on WAAN-OFIIHUB',
              subtitle: kIsWeb
                  ? 'Device phone contacts are supported on Android & iOS. On Web, find and connect with friends using their unique Public ID.'
                  : 'Sync your phonebook to find friends or invite them via share link.',
              action: Column(
                children: [
                  ElevatedButton.icon(
                    icon: const Icon(Icons.person_search),
                    label: const Text('Search by Public ID'),
                    onPressed: () => context.push('/contacts/search'),
                  ),
                  if (!kIsWeb) ...[
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.sync),
                      label: const Text('Sync Phone Contacts'),
                      onPressed: () => ref.invalidate(matchedContactsProvider),
                    ),
                  ],
                  const SizedBox(height: 8),
                  TextButton.icon(
                    icon: const Icon(Icons.share_rounded),
                    label: const Text('Invite Friends'),
                    onPressed: () {
                      unawaited(
                        launchUrl(
                          Uri.parse(
                            'sms:?body=Join me on WAAN-OFIIHUB for Blog and Chat!',
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: contacts.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final contact = contacts[index];

              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: theme.colorScheme.primaryContainer,
                  child: Text(
                    contact.displayName.isNotEmpty
                        ? contact.displayName[0].toUpperCase()
                        : 'U',
                  ),
                ),
                title: Text(contact.displayName),
                subtitle: Text(
                  '${contact.publicId} • ${contact.phoneVerified ? 'Verified' : 'Unverified Number'}',
                ),
                trailing: ElevatedButton(
                  onPressed: () async {
                    final convId = await ref
                        .read(chatRepositoryProvider)
                        .startDirectChat(contact.id);
                    if (convId != null && context.mounted) {
                      unawaited(context.push('/chat/$convId'));
                    }
                  },
                  child: const Text('Message'),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
