import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/supabase_config.dart';

class AuthRepository {
  final SupabaseClient? _client;

  AuthRepository(this._client);

  User? get currentUser => _client?.auth.currentUser;

  Stream<AuthState>? get authStateChanges => _client?.auth.onAuthStateChange;

  Future<AuthResponse?> signIn({
    required String email,
    required String password,
  }) async {
    if (_client == null) return null;
    return await _client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<AuthResponse?> signUp({
    required String email,
    required String password,
    required String displayName,
    String? phoneE164,
    String? phoneHash,
  }) async {
    if (_client == null) return null;
    return await _client.auth.signUp(
      email: email.trim(),
      password: password,
      data: {
        'display_name': displayName.trim(),
        if (phoneE164 != null) 'phone_e164': phoneE164.trim(),
        if (phoneHash != null) 'phone_hash': phoneHash.trim(),
      },
    );
  }

  Future<void> signOut() async {
    await _client?.auth.signOut();
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final client = isSupabaseInitialized
      ? ref.watch(supabaseClientProvider)
      : null;
  return AuthRepository(client);
});
