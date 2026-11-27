import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/supabase_config.dart';
import '../models/contact_match.dart';

class ContactsRepository {
  final SupabaseClient? _client;
  static const _salt = 'woh_phone_salt_v1';

  ContactsRepository(this._client);

  String hashPhoneNumber(String rawPhone) {
    final clean = rawPhone.trim().replaceAll(RegExp(r'[^0-9+]'), '');
    final bytes = utf8.encode('$_salt:$clean');
    return sha256.convert(bytes).toString();
  }

  Future<List<ContactMatch>> syncContacts() async {
    if (_client == null || kIsWeb) {
      // Browser environment does not have access to device phone contacts
      return [];
    }

    try {
      final hasPerm = await FlutterContacts.permissions.has(
        PermissionType.read,
      );
      if (!hasPerm) {
        final status = await FlutterContacts.permissions.request(
          PermissionType.read,
        );
        if (status != PermissionStatus.granted &&
            status != PermissionStatus.limited) {
          return [];
        }
      }

      final contacts = await FlutterContacts.getAll(
        properties: {ContactProperty.phone},
      );
      final hashes = <String>{};

      for (final c in contacts) {
        for (final phone in c.phones) {
          if (phone.number.isNotEmpty) {
            hashes.add(hashPhoneNumber(phone.number));
          }
        }
      }

      if (hashes.isEmpty) return [];

      final res = await _client.rpc(
        'match_contacts',
        params: {'hashes': hashes.take(500).toList()},
      );

      return (res as List).map((e) => ContactMatch.fromJson(e)).toList();
    } catch (_) {
      // Gracefully return empty list when contact permission is denied or unsupported
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    if (_client == null) return [];
    final res = await _client.rpc(
      'search_users_by_query',
      params: {'query_text': query.trim()},
    );
    return List<Map<String, dynamic>>.from(res);
  }
}

final contactsRepositoryProvider = Provider<ContactsRepository>((ref) {
  final client = isSupabaseInitialized
      ? ref.watch(supabaseClientProvider)
      : null;
  return ContactsRepository(client);
});

final matchedContactsProvider = FutureProvider<List<ContactMatch>>((ref) async {
  return ref.watch(contactsRepositoryProvider).syncContacts();
});
