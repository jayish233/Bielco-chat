/// Build-time configuration, supplied via
/// `--dart-define-from-file=env/local.json`.
abstract final class Env {
  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
  );
}

/// Throws a [StateError] with setup instructions if a value is missing.
void checkEnv({required String url, required String anonKey}) {
  if (url.isEmpty || anonKey.isEmpty) {
    throw StateError(
      'Missing SUPABASE_URL / SUPABASE_ANON_KEY. Run the app with '
      '--dart-define-from-file=env/local.json '
      '(copy env/example.json to start).',
    );
  }
}
