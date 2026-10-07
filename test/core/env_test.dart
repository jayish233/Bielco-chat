import 'package:chatapp/core/env.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('checkEnv throws a helpful error when values are missing', () {
    expect(
      () => checkEnv(url: '', anonKey: 'k'),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('--dart-define-from-file=env/local.json'),
        ),
      ),
    );
  });

  test('checkEnv throws when anon key is missing', () {
    expect(() => checkEnv(url: 'http://x', anonKey: ''), throwsStateError);
  });

  test('checkEnv accepts configured values', () {
    checkEnv(url: 'http://127.0.0.1:54331', anonKey: 'k');
  });

  test('resolveEnv falls back to the local stack in debug', () {
    final env = resolveEnv(
      url: '',
      anonKey: '',
      debug: true,
      platform: TargetPlatform.iOS,
      isWeb: false,
    );
    expect(env.url, localSupabaseUrl);
    expect(env.anonKey, localSupabaseAnonKey);
    checkEnv(url: env.url, anonKey: env.anonKey);
  });

  test('resolveEnv uses the Android emulator host in debug', () {
    final env = resolveEnv(
      url: '',
      anonKey: '',
      debug: true,
      platform: TargetPlatform.android,
      isWeb: false,
    );
    expect(env.url, localAndroidSupabaseUrl);
  });

  test('resolveEnv keeps 127.0.0.1 for Android web in debug', () {
    final env = resolveEnv(
      url: '',
      anonKey: '',
      debug: true,
      platform: TargetPlatform.android,
      isWeb: true,
    );
    expect(env.url, localSupabaseUrl);
  });

  test('resolveEnv leaves empty values in release', () {
    final env = resolveEnv(
      url: '',
      anonKey: '',
      debug: false,
      platform: TargetPlatform.iOS,
    );
    expect(env.url, isEmpty);
    expect(env.anonKey, isEmpty);
    expect(
      () => checkEnv(url: env.url, anonKey: env.anonKey),
      throwsStateError,
    );
  });

  test('resolveEnv keeps explicit dart-defines over the fallback', () {
    final env = resolveEnv(
      url: 'https://example.supabase.co',
      anonKey: 'hosted-key',
      debug: true,
      platform: TargetPlatform.android,
    );
    expect(env.url, 'https://example.supabase.co');
    expect(env.anonKey, 'hosted-key');
  });
}
