class AppConfig {
  static const supabaseUrl =
      String.fromEnvironment('SUPABASE_URL');

  static const supabaseAnonKey =
      String.fromEnvironment('SUPABASE_ANON_KEY');

  static const geminiApiKey =
      String.fromEnvironment('GEMINI_API_KEY');

  static const oauthRedirectUrl =
      String.fromEnvironment('OAUTH_REDIRECT_URL');
}