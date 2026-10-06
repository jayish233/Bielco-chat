import 'package:chatapp/features/auth/domain/validators.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('validateEmail', () {
    expect(validateEmail('  priya@example.com '), isNull);
    expect(validateEmail('   '), 'Enter your email.');
    expect(validateEmail('priya@'), 'Enter a valid email address.');
  });
  test('validatePassword', () {
    const m = 'Use 8+ characters with a letter and a number.';
    expect(validatePassword('password'), m);
    expect(validatePassword('12345678'), m);
    expect(validatePassword('abc123'), m);
    expect(validatePassword('relaypass24'), isNull);
  });
  test('passwordStrength', () {
    expect(
      [
        passwordStrength(''),
        passwordStrength('relaypass'),
        passwordStrength('relaypass24'),
        passwordStrength('Relaypass24'),
        passwordStrength('Relaypass24!'),
      ],
      [0, 1, 2, 3, 4],
    );
  });
  test('usernames', () {
    const m = 'Use 3–20 letters, numbers or underscores.';
    expect(normalizeUsername(' @Priya_S '), 'priya_s');
    expect(validateUsername('priya_s'), isNull);
    expect(validateUsername('pr'), m);
    expect(validateUsername('priya.s'), m);
    expect(validateUsername('a' * 21), m);
  });
  test('validateDisplayName', () {
    expect(validateDisplayName('  '), 'Enter your name.');
    expect(validateDisplayName('x' * 51), 'Keep it under 50 characters.');
    expect(validateDisplayName('Priya'), isNull);
  });
}
