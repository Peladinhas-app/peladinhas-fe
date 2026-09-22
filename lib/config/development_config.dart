class DevelopmentConfig {
  const DevelopmentConfig._();

  static const apiBaseUrl = String.fromEnvironment(
    'BACKEND_API_BASE_URL',
    defaultValue: 'http://localhost:8080/api/v1',
  );

  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');

  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  static bool get hasSupabaseConfig {
    return supabaseUrl.trim().isNotEmpty && supabaseAnonKey.trim().isNotEmpty;
  }
}
