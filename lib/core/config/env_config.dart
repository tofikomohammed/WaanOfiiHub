/// Application environment configuration loaded via --dart-define-from-file=env.json
class EnvConfig {
  EnvConfig._();

  static const String appName = 'WAAN-OFIIHUB';
  static const String appVersion = '1.0.0';

  /// Supabase project URL passed via compile-time environment variable
  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');

  /// Supabase anonymous key passed via compile-time environment variable
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
  );

  /// Indicates if both Supabase URL and anon key are properly configured
  static bool get isConfigured {
    final validUrl =
        supabaseUrl.trim().isNotEmpty &&
        (supabaseUrl.startsWith('https://') ||
            supabaseUrl.startsWith('http://'));
    final validKey = supabaseAnonKey.trim().isNotEmpty;
    return validUrl && validKey;
  }
}
