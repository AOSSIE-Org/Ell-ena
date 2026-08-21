/// Compile-time app configuration via `--dart-define` / `--dart-define-from-file`.
///
/// These values are baked in at build time and are **not** loaded from a bundled
/// `.env` asset. Never pass service-role keys or other server-only secrets here.
///
/// Local / release examples:
/// ```bash
/// flutter run --dart-define-from-file=dart_defines.json
/// flutter build appbundle --release --dart-define-from-file=dart_defines.json
/// ```
class AppConfig {
  AppConfig._();

  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const String supabaseAnonKey =
      String.fromEnvironment('SUPABASE_ANON_KEY');
  static const String geminiApiKey = String.fromEnvironment('GEMINI_API_KEY');
  static const String oauthRedirectUrl = String.fromEnvironment(
    'OAUTH_REDIRECT_URL',
    defaultValue: 'io.supabase.ellena://login-callback/',
  );

  static bool get hasSupabaseConfig =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  static bool get hasGeminiConfig => geminiApiKey.isNotEmpty;

  /// Throws a clear error if required client defines are missing.
  static void ensureClientConfig() {
    final missing = <String>[];
    if (supabaseUrl.isEmpty) missing.add('SUPABASE_URL');
    if (supabaseAnonKey.isEmpty) missing.add('SUPABASE_ANON_KEY');
    if (geminiApiKey.isEmpty) missing.add('GEMINI_API_KEY');
    if (missing.isEmpty) return;

    throw StateError(
      'Missing compile-time config: ${missing.join(', ')}. '
      'Pass them with --dart-define=KEY=value or '
      '--dart-define-from-file=dart_defines.json '
      '(see dart_defines.example.json).',
    );
  }
}
