import 'dart:async';

import 'package:chatapp/core/providers.dart';
import 'package:chatapp/core/router.dart';
import 'package:chatapp/core/theme/app_theme.dart';
import 'package:chatapp/features/auth/domain/auth_failure.dart';
import 'package:chatapp/features/auth/ui/sign_in_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../support/fakes.dart';

Future<FakeAuthRepository> _pump(
  WidgetTester t, {
  Size size = const Size(600, 900),
}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  final auth = FakeAuthRepository();
  addTearDown(auth.dispose);
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, _) => const SignInScreen()),
      GoRoute(
        path: Routes.signUp,
        builder: (_, _) => const Scaffold(body: Text('SIGN UP PAGE')),
      ),
    ],
  );
  addTearDown(router.dispose);
  await t.pumpWidget(
    ProviderScope(
      overrides: [authRepositoryProvider.overrideWithValue(auth)],
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
  return auth;
}

Future<void> _fill(WidgetTester t, String email, String password) async {
  await t.enterText(find.byType(TextField).at(0), email);
  await t.pump();
  await t.enterText(find.byType(TextField).at(1), password);
  await t.pump();
}

void main() {
  testWidgets('empty submit shows field errors and does not call auth', (
    t,
  ) async {
    final auth = await _pump(t);
    await t.tap(find.text('Sign in'));
    await t.pump();
    expect(find.text('Enter your email.'), findsOneWidget);
    expect(
      find.text('Use 8+ characters with a letter and a number.'),
      findsOneWidget,
    );
    expect(auth.signInCalls, isEmpty);
  });

  testWidgets('field errors are hidden before the first submit', (t) async {
    await _pump(t);
    expect(find.text('Enter your email.'), findsNothing);
  });

  testWidgets('submits trimmed email', (t) async {
    final auth = await _pump(t);
    await _fill(t, '  Priya@Example.com ', 'password1');
    await t.tap(find.text('Sign in'));
    await t.pump();
    expect(auth.signInCalls.single.email, 'Priya@Example.com');
    expect(auth.signInCalls.single.password, 'password1');
  });

  testWidgets('wrong password shows banner', (t) async {
    final auth = await _pump(t);
    auth.nextError = const AuthFailure(AuthFailureCode.invalidCredentials);
    await _fill(t, 'a@b.co', 'password1');
    await t.tap(find.text('Sign in'));
    await t.pump();
    expect(find.text('Email or password is incorrect.'), findsOneWidget);
  });

  testWidgets('network failure shows message and re-enables button', (t) async {
    final auth = await _pump(t);
    auth.nextError = const AuthFailure(AuthFailureCode.network);
    await _fill(t, 'a@b.co', 'password1');
    await t.tap(find.text('Sign in'));
    await t.pump();
    expect(
      find.text('Can’t reach the server. Check your connection and try again.'),
      findsOneWidget,
    );
    await t.tap(find.text('Sign in'));
    await t.pump();
    expect(auth.signInCalls, hasLength(2));
  });

  testWidgets('double tap sends one request', (t) async {
    final auth = await _pump(t);
    final gate = Completer<void>();
    auth.signInGate = gate;
    await _fill(t, 'a@b.co', 'password1');
    await t.tap(find.text('Sign in'));
    await t.pump();
    // The label is replaced by a spinner while submitting; tap the button.
    await t.tap(find.byType(InkWell).first, warnIfMissed: false);
    await t.pump();
    expect(auth.signInCalls, hasLength(1));
    gate.complete();
    await t.pump();
  });

  testWidgets('brand panel only at >=900px', (t) async {
    await _pump(t, size: const Size(1200, 800));
    expect(find.byKey(const Key('brand-panel')), findsOneWidget);
    expect(find.text('Every conversation, in one calm place.'), findsOneWidget);

    await _pump(t, size: const Size(600, 900));
    expect(find.byKey(const Key('brand-panel')), findsNothing);
  });

  testWidgets('create account link goes to sign-up', (t) async {
    await _pump(t);
    await t.ensureVisible(find.text('Create account'));
    await t.tap(find.text('Create account'));
    await t.pumpAndSettle();
    expect(find.text('SIGN UP PAGE'), findsOneWidget);
  });
}
