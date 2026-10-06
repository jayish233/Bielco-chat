import 'package:chatapp/core/env.dart';
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
}
