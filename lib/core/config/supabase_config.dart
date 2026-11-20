import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'env_config.dart';
import '../errors/app_exception.dart';

/// Flag tracking whether Supabase client was successfully initialized.
bool _isSupabaseInitialized = false;

bool get isSupabaseInitialized => _isSupabaseInitialized;

/// Initializes Supabase if credentials are present.
/// If credentials are missing, it does not crash so developers can see the
/// setup guidance screen.
Future<void> initSupabase() async {
  if (!EnvConfig.isConfigured) {
    debugPrint(
      '⚠️ [SupabaseConfig] SUPABASE_URL or SUPABASE_ANON_KEY not set. '
      'Run with --dart-define-from-file=env.json to connect to Supabase.',
    );
    _isSupabaseInitialized = false;
    return;
  }

  try {
    await Supabase.initialize(
      url: EnvConfig.supabaseUrl,
      anonKey: EnvConfig.supabaseAnonKey,
      authOptions: const FlutterAuthClientOptions(autoRefreshToken: true),
    );
    _isSupabaseInitialized = true;
    debugPrint('✅ [SupabaseConfig] Supabase successfully initialized.');
  } catch (e, stack) {
    _isSupabaseInitialized = false;
    debugPrint('❌ [SupabaseConfig] Failed to initialize Supabase: $e\n$stack');
  }
}

/// Riverpod provider for the initialized SupabaseClient.
final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  if (!_isSupabaseInitialized) {
    throw const ConfigurationException(
      'Supabase is not initialized. Please verify your env.json configuration.',
    );
  }
  return Supabase.instance.client;
});
