import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/supabase_config.dart';

class RbacRepository {
  final SupabaseClient? _client;

  RbacRepository(this._client);

  Future<List<String>> getMyPermissions() async {
    if (_client == null) return [];
    try {
      final res = await _client.rpc('my_permissions');
      if (res is List) {
        return res.map((e) => e.toString()).toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getRoles() async {
    if (_client == null) return [];
    final res = await _client.from('roles').select().order('name');
    return List<Map<String, dynamic>>.from(res);
  }

  Future<void> assignRole(String userId, String roleKey) async {
    if (_client == null) return;
    await _client.rpc(
      'assign_user_role',
      params: {'target_user_id': userId, 'role_key': roleKey},
    );
  }

  Future<void> revokeRole(String userId, String roleKey) async {
    if (_client == null) return;
    await _client.rpc(
      'revoke_user_role',
      params: {'target_user_id': userId, 'role_key': roleKey},
    );
  }

  Future<void> setBanStatus(String userId, bool banned, String reason) async {
    if (_client == null) return;
    await _client.rpc(
      'set_user_ban_status',
      params: {
        'target_user_id': userId,
        'ban_state': banned,
        'ban_reason': reason,
      },
    );
  }
}

final rbacRepositoryProvider = Provider<RbacRepository>((ref) {
  final client = isSupabaseInitialized
      ? ref.watch(supabaseClientProvider)
      : null;
  return RbacRepository(client);
});

final myPermissionsProvider = FutureProvider<List<String>>((ref) async {
  return ref.watch(rbacRepositoryProvider).getMyPermissions();
});

extension PermissionCheck on WidgetRef {
  bool can(String permissionKey) {
    final perms = watch(myPermissionsProvider).valueOrNull ?? [];
    return perms.contains(permissionKey);
  }
}
