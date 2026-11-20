import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/supabase_config.dart';
import '../../../core/models/user_profile.dart';

class ProfileRepository {
  final SupabaseClient? _client;

  ProfileRepository(this._client);

  Future<UserProfile?> getProfile(String userId) async {
    if (_client == null) return null;
    final res = await _client
        .from('profiles')
        .select()
        .eq('id', userId)
        .maybeSingle();

    if (res == null) return null;
    return UserProfile.fromJson(res);
  }

  Future<List<UserProfile>> getAllUsers({int limit = 100}) async {
    final client = _client;
    if (client == null) return [];
    final currentUserId = client.auth.currentUser?.id;
    var query = client
        .from('profiles')
        .select()
        .eq('is_banned', false);

    if (currentUserId != null) {
      query = query.neq('id', currentUserId);
    }

    final res = await query
        .order('created_at', ascending: false)
        .limit(limit);

    return (res as List).map((e) => UserProfile.fromJson(e)).toList();
  }

  Future<void> updateProfile({
    required String userId,
    String? displayName,
    String? username,
    String? about,
    String? avatarUrl,
    bool? showLastSeen,
    bool? allowPhoneDiscovery,
  }) async {
    if (_client == null) return;
    final updates = <String, dynamic>{
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (displayName != null) updates['display_name'] = displayName;
    if (username != null) updates['username'] = username;
    if (about != null) updates['about'] = about;
    if (avatarUrl != null) updates['avatar_url'] = avatarUrl;
    if (showLastSeen != null) updates['show_last_seen'] = showLastSeen;
    if (allowPhoneDiscovery != null) {
      updates['allow_phone_discovery'] = allowPhoneDiscovery;
    }

    await _client.from('profiles').update(updates).eq('id', userId);
  }
}

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  final client = isSupabaseInitialized
      ? ref.watch(supabaseClientProvider)
      : null;
  return ProfileRepository(client);
});

final currentProfileProvider = FutureProvider<UserProfile?>((ref) async {
  final client = isSupabaseInitialized
      ? ref.watch(supabaseClientProvider)
      : null;
  final uid = client?.auth.currentUser?.id;
  if (uid == null) return null;
  return ref.watch(profileRepositoryProvider).getProfile(uid);
});

final allUsersProvider = FutureProvider<List<UserProfile>>((ref) async {
  return ref.watch(profileRepositoryProvider).getAllUsers();
});
