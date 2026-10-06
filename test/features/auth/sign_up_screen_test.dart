import 'package:chatapp/core/providers.dart';
import 'package:chatapp/core/router.dart';
import 'package:chatapp/core/theme/app_theme.dart';
import 'package:chatapp/core/ui/form_error_banner.dart';
import 'package:chatapp/features/auth/data/auth_repository.dart';
import 'package:chatapp/features/auth/domain/auth_failure.dart';
import 'package:chatapp/features/auth/ui/sign_up_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../support/fakes.dart';

Future<(FakeAuthRepository, FakeProfileRepository)> _pump(
  WidgetTester t,
) async {
  t.view.physicalSize = const Size(600, 1200);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  final auth = FakeAuthRepository();
  final profiles = FakeProfileRepository();
  addTearDown(auth.dispose);
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, _) => const SignUpScreen()),
      GoRoute(
        path: Routes.signIn,
        builder: (_, _) => const Scaffold(body: Text('SIGN IN PAGE')),
      ),
    ],
  );
  addTearDown(router.dispose);
  await t.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        profileRepositoryProvider.overrideWithValue(profiles),
      ],
      child: MaterialApp.router(
        theme: buildRelayTheme(
          Brightness.light,
          platform: TargetPlatform.iOS,
          isWeb: false,
        ),
        routerConfig: router,
      ),
    ),
  );
  await t.pump();
  return (auth, profiles);
}

// Field order: name, username, email, password.
Future<void> _enter(WidgetTester t, int i, String text) async {
  await t.enterText(find.byType(TextField).at(i), text);
  await t.pump();
}

Future<void> _fillAll(WidgetTester t) async {
  await _enter(t, 0, ' Priya Shah ');
  await _enter(t, 1, ' @Priya ');
  await _enter(t, 2, ' priya@example.com ');
  await _enter(t, 3, 'Relaypass24');
}

Future<void> _tapCreate(WidgetTester t) async {
  final b = find.text('Create account');
  await t.ensureVisible(b);
  await t.tap(b);
  await t.pump();
  await t.pump();
}

void main() {
  testWidgets('strength meter follows the password', (t) async {
    await _pump(t);
    await _enter(t, 3, 'Relaypass24');
    expect(find.bySemanticsLabel('Password strength good'), findsOneWidget);
  });

  testWidgets('username shows availability after debounce', (t) async {
    await _pump(t);
    await _enter(t, 1, 'Priya');
    expect(find.text('@priya is available'), findsNothing);
    await t.pump(const Duration(milliseconds: 400));
    await t.pump();
    expect(find.text('@priya is available'), findsOneWidget);
  });

  testWidgets('taken username shows field error', (t) async {
    final (_, profiles) = await _pump(t);
    profiles.takenUsernames = {'priya'};
    await _enter(t, 1, 'priya');
    await t.pump(const Duration(milliseconds: 400));
    await t.pump();
    expect(find.text('That username is taken.'), findsOneWidget);
    expect(find.text('@priya is available'), findsNothing);
  });

  testWidgets('invalid format shows format error without availability check', (
    t,
  ) async {
    final (_, profiles) = await _pump(t);
    profiles.takenUsernames = {'ab!'};
    await _enter(t, 1, 'ab!');
    await t.pump(const Duration(milliseconds: 400));
    await t.pump();
    expect(find.text('Use 3–20 letters, numbers or underscores.'), findsOne);
    expect(find.text('That username is taken.'), findsNothing);
  });

  testWidgets('server-side username race lands on the username field', (
    t,
  ) async {
    final (auth, _) = await _pump(t);
    await _fillAll(t);
    await t.pump(const Duration(milliseconds: 400));
    await t.pump();
    auth.nextError = const AuthFailure(AuthFailureCode.usernameTaken);
    await _tapCreate(t);
    expect(find.text('That username is taken.'), findsOneWidget);
    expect(find.byType(FormErrorBanner), findsNothing);
    // Editing the username clears it.
    await _enter(t, 1, 'priya2');
    expect(find.text('That username is taken.'), findsNothing);
  });

  testWidgets('other failures use the banner', (t) async {
    final (auth, _) = await _pump(t);
    await _fillAll(t);
    auth.nextError = const AuthFailure(AuthFailureCode.emailTaken);
    await _tapCreate(t);
    expect(find.byType(FormErrorBanner), findsOneWidget);
  });

  testWidgets('valid form calls signUp with normalized values', (t) async {
    final (auth, _) = await _pump(t);
    await _fillAll(t);
    await _tapCreate(t);
    expect(auth.signUpCalls, hasLength(1));
    final c = auth.signUpCalls.single;
    expect(c.username, 'priya');
    expect(c.email, 'priya@example.com');
    expect(c.password, 'Relaypass24');
    expect(c.displayName, 'Priya Shah');
  });

  testWidgets('invalid form does not call signUp', (t) async {
    final (auth, _) = await _pump(t);
    await _tapCreate(t);
    expect(auth.signUpCalls, isEmpty);
    expect(find.text('Enter your name.'), findsOneWidget);
  });

  testWidgets('email confirmation state', (t) async {
    final (auth, _) = await _pump(t);
    auth.signUpResult = const SignUpResult(needsEmailConfirmation: true);
    await _fillAll(t);
    await _tapCreate(t);
    expect(find.text('Check your inbox'), findsOneWidget);
    expect(find.text('Confirm your email, then sign in.'), findsOneWidget);
    await t.tap(find.text('Back to sign in'));
    await t.pumpAndSettle();
    expect(find.text('SIGN IN PAGE'), findsOneWidget);
  });
}
