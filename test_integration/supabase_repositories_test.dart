// Runs against the local Supabase stack:
//   flutter test test_integration --dart-define-from-file=env/local.json
import 'package:chatapp/core/env.dart';
import 'package:chatapp/features/auth/data/supabase_auth_repository.dart';
import 'package:chatapp/features/auth/domain/auth_failure.dart';
import 'package:chatapp/features/auth/data/auth_repository.dart';
import 'package:chatapp/features/profile/data/supabase_profile_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _pw = 'relaypass24';

SupabaseClient _client([String? url]) => SupabaseClient(
  url ?? Env.supabaseUrl,
  Env.supabaseAnonKey,
  authOptions: const AuthClientOptions(authFlowType: AuthFlowType.implicit),
);

Matcher _failure(AuthFailureCode code) =>
    throwsA(isA<AuthFailure>().having((e) => e.code, 'code', code));

String _n() => DateTime.now().microsecondsSinceEpoch.toString();

// Usernames are capped at 20 chars.
String _s() {
  final n = _n();
  return n.substring(n.length - 10);
}

void main() {
  late SupabaseClient client;
  late SupabaseAuthRepository auth;
  late SupabaseProfileRepository profiles;

  setUp(() {
    client = _client();
    auth = SupabaseAuthRepository(client);
    profiles = SupabaseProfileRepository(client);
  });
  tearDown(() => client.dispose());

  Future<({String email, String username})> register([String? username]) async {
    final n = _n();
    final email = 'm1-$n@example.com';
    final u = username ?? 'user_${_s()}';
    await auth.signUp(
      email: email,
      password: _pw,
      username: u,
      displayName: 'Test $n',
    );
    return (email: email, username: u.toLowerCase());
  }

  test('signUp signs in and creates the profile', () async {
    final n = _n();
    final s = _s();
    final res = await auth.signUp(
      email: ' m1-$n@example.com ',
      password: _pw,
      username: '@Priya_$s',
      displayName: 'Priya $n',
    );
    expect(res.needsEmailConfirmation, isFalse);
    expect(auth.currentStatus, AuthStatus.signedIn);
    expect(auth.currentUserId, isNotNull);
    expect(auth.currentEmail, 'm1-$n@example.com');
    final p = await profiles.fetchMyProfile();
    expect(p.username, 'priya_$s');
    expect(p.displayName, 'Priya $n');
  });

  test('signUp with existing email -> emailTaken', () async {
    final u = await register();
    await auth.signOut();
    await expectLater(
      auth.signUp(
        email: u.email,
        password: _pw,
        username: 'other_${_s()}',
        displayName: 'Dup',
      ),
      _failure(AuthFailureCode.emailTaken),
    );
  });

  test(
    'signUp with taken username (case-insensitive) -> usernameTaken',
    () async {
      final s = _s();
      await register('priya_x$s');
      await auth.signOut();
      await expectLater(
        auth.signUp(
          email: 'm1-${_n()}@example.com',
          password: _pw,
          username: 'Priya_X$s',
          displayName: 'Dup',
        ),
        _failure(AuthFailureCode.usernameTaken),
      );
    },
  );

  test(
    'signIn wrong password -> invalidCredentials; messy email works',
    () async {
      final u = await register();
      await auth.signOut();
      await expectLater(
        auth.signIn(email: u.email, password: 'wrongpass99'),
        _failure(AuthFailureCode.invalidCredentials),
      );
      await auth.signIn(email: '  ${u.email.toUpperCase()} ', password: _pw);
      expect(auth.currentStatus, AuthStatus.signedIn);
    },
  );

  test('isUsernameAvailable works while signed out', () async {
    final u = await register();
    await auth.signOut();
    expect(auth.currentStatus, AuthStatus.signedOut);
    expect(await profiles.isUsernameAvailable(u.username), isFalse);
    expect(
      await profiles.isUsernameAvailable('@${u.username.toUpperCase()}'),
      isFalse,
    );
    expect(await profiles.isUsernameAvailable('fresh_${_s()}'), isTrue);
  });

  test('updateMyProfile with taken username -> usernameTaken', () async {
    final other = await register();
    await auth.signOut();
    await register();
    await expectLater(
      profiles.updateMyProfile(username: other.username),
      _failure(AuthFailureCode.usernameTaken),
    );
    final p = await profiles.updateMyProfile(displayName: 'Renamed');
    expect(p.displayName, 'Renamed');
  });

  test('statusChanges emits signedOut after signOut', () async {
    await register();
    final next = auth.statusChanges().first;
    await auth.signOut();
    expect(await next, AuthStatus.signedOut);
  });

  test('unreachable server -> network', () async {
    final bad = _client('http://127.0.0.1:1');
    addTearDown(bad.dispose);
    await expectLater(
      SupabaseAuthRepository(bad).signIn(email: 'a@example.com', password: _pw),
      _failure(AuthFailureCode.network),
    );
  });

  test(
    'real duplicate-username race (pre-check bypassed) -> usernameTaken',
    () async {
      final name = 'race_${_s()}';
      final other = _client();
      addTearDown(other.dispose);
      await other.auth.signUp(
        email: 'm1-${_n()}@example.com',
        password: _pw,
        data: {'username': name, 'display_name': 'First'},
      );
      Object? error;
      try {
        await client.auth.signUp(
          email: 'm1-${_n()}@example.com',
          password: _pw,
          data: {'username': name, 'display_name': 'Second'},
        );
      } catch (e) {
        error = e;
      }
      expect(error, isNotNull);
      expect(mapAuthError(error!).code, AuthFailureCode.usernameTaken);
    },
  );
}
