import 'package:flutter/foundation.dart';

/// Build-time configuration, supplied via
/// `--dart-define-from-file=env/local.json`.
abstract final class Env {
  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
  );
}

/// Local Supabase API on this machine (iOS simulator, web, desktop).
const String localSupabaseUrl = 'http://127.0.0.1:54331';

/// Android emulator alias for the host machine.
const String localAndroidSupabaseUrl = 'http://10.0.2.2:54331';

/// Anon key printed by `supabase start` for the local demo project.
/// Not a hosted secret.
const String localSupabaseAnonKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0';

/// Values after applying the debug local-stack fallback.
class ResolvedEnv {
  const ResolvedEnv({required this.url, required this.anonKey});

  final String url;
  final String anonKey;
}

/// Uses dart-defines when present. In debug, empty values fall back to the
/// local stack so a plain `flutter run` still boots. Release stays strict.
ResolvedEnv resolveEnv({
  String url = Env.supabaseUrl,
  String anonKey = Env.supabaseAnonKey,
  bool debug = kDebugMode,
  TargetPlatform? platform,
  bool isWeb = kIsWeb,
}) {
  var resolvedUrl = url;
  var resolvedKey = anonKey;
  if (debug) {
    if (resolvedUrl.isEmpty) {
      final onAndroid =
          !isWeb &&
          (platform ?? defaultTargetPlatform) == TargetPlatform.android;
      resolvedUrl = onAndroid ? localAndroidSupabaseUrl : localSupabaseUrl;
    }
    if (resolvedKey.isEmpty) {
      resolvedKey = localSupabaseAnonKey;
    }
  }
  return ResolvedEnv(url: resolvedUrl, anonKey: resolvedKey);
}

String get resolvedSupabaseUrl => resolveEnv().url;
String get resolvedSupabaseAnonKey => resolveEnv().anonKey;

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

/// Public base URL of the web app, used to build invite links.
/// Override with `"APP_URL": "https://…"` in the env file.
abstract final class AppLinks {
  static const String baseUrl = String.fromEnvironment(
    'APP_URL',
    defaultValue: 'http://localhost:3000',
  );

  static String invite(String token) => '$baseUrl/#/join/$token';

  /// Pulls the token out of a pasted invite link (or a bare token).
  static String? tokenFrom(String input) {
    final s = input.trim();
    final m = RegExp(r'join/([A-Za-z0-9]+)').firstMatch(s);
    if (m != null) return m.group(1);
    return RegExp(r'^[A-Za-z0-9]{16,64}$').hasMatch(s) ? s : null;
  }
}
