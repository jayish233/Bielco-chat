import 'package:chatapp/core/providers.dart';
import 'package:chatapp/core/router.dart';
import 'package:chatapp/core/theme/app_theme.dart';
import 'package:chatapp/features/auth/domain/auth_failure.dart';
import 'package:chatapp/features/auth/ui/sign_in_screen.dart';
import 'package:chatapp/features/auth/ui/sign_up_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../support/fakes.dart';

Future<FakeAuthRepository> _pump(WidgetTester t, String initial) async {
  t.view.physicalSize = const Size(600, 1400);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  final auth = FakeAuthRepository();
  addTearDown(auth.dispose);
  final router = GoRouter(
    initialLocation: initial,
    routes: [
      GoRoute(path: Routes.signIn, builder: (_, _) => const SignInScreen()),
      GoRoute(path: Routes.signUp, builder: (_, _) => const SignUpScreen()),
    ],
  );
  addTearDown(router.dispose);
  await t.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        profileRepositoryProvider.overrideWithValue(FakeProfileRepository()),
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
  await t.pumpAndSettle();
  return auth;
}

Future<void> _tap(WidgetTester t, String text) async {
  final f = find.text(text);
  await t.ensureVisible(f);
  await t.tap(f);
  await t.pumpAndSettle();
}

void main() {
  testWidgets('sign-in error does not carry over to sign-up', (t) async {
    final auth = await _pump(t, Routes.signIn);
    auth.nextError = const AuthFailure(AuthFailureCode.invalidCredentials);
    await t.enterText(find.byType(TextField).at(0), 'a@example.com');
    await t.enterText(find.byType(TextField).at(1), 'Relaypass24');
    await _tap(t, 'Sign in');
    expect(find.text('Email or password is incorrect.'), findsOneWidget);

    await _tap(t, 'Create account');
    expect(find.byType(SignUpScreen), findsOneWidget);
    expect(find.text('Email or password is incorrect.'), findsNothing);
  });

  testWidgets('sign-up error does not carry over to sign-in', (t) async {
    final auth = await _pump(t, Routes.signUp);
    auth.nextError = const AuthFailure(AuthFailureCode.emailTaken);
    await t.enterText(find.byType(TextField).at(0), 'Priya Shah');
    await t.enterText(find.byType(TextField).at(1), 'priya');
    await t.enterText(find.byType(TextField).at(2), 'p@example.com');
    await t.enterText(find.byType(TextField).at(3), 'Relaypass24');
    await t.pump(const Duration(milliseconds: 400));
    await _tap(t, 'Create account');
    expect(
      find.text('An account with this email already exists.'),
      findsOneWidget,
    );

    await _tap(t, 'Sign in');
    expect(find.byType(SignInScreen), findsOneWidget);
    expect(
      find.text('An account with this email already exists.'),
      findsNothing,
    );
  });
}
