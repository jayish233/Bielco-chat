import 'dart:async';

import 'package:chatapp/core/providers.dart';
import 'package:chatapp/core/router.dart';
import 'package:chatapp/core/theme/app_theme.dart';
import 'package:chatapp/core/ui/relay_button.dart';
import 'package:chatapp/features/auth/data/auth_repository.dart';
import 'package:chatapp/features/auth/domain/auth_failure.dart';
import 'package:chatapp/features/profile/domain/profile.dart';
import 'package:chatapp/features/profile/ui/profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../support/fakes.dart';

const _ada = Profile(id: 'u1', username: 'ada', displayName: 'Ada L');

Future<(FakeAuthRepository, FakeProfileRepository)> _pump(
  WidgetTester t, {
  Profile? profile = _ada,
  Object? loadError,
}) async {
  t.view.physicalSize = const Size(600, 1200);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  final auth = FakeAuthRepository()..currentEmail = 'ada@example.com';
  final profiles = FakeProfileRepository(profile: profile)
    ..loadError = loadError;
  addTearDown(auth.dispose);
  final router = GoRouter(
    initialLocation: Routes.profile,
    routes: [
      GoRoute(path: Routes.profile, builder: (_, _) => const ProfileScreen()),
      GoRoute(
        path: Routes.home,
        builder: (_, _) => const Scaffold(body: Text('HOME PAGE')),
      ),
    ],
  );
  addTearDown(router.dispose);
  await t.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        profileRepositoryProvider.overrideWithValue(profiles),
        authStatusProvider.overrideWith(
          (_) => Stream.value(AuthStatus.signedIn),
        ),
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
  return (auth, profiles);
}

Finder _field(int i) => find.byType(TextField).at(i);

Finder _save() => find.widgetWithText(RelayButton, 'Save changes');

bool _saveEnabled(WidgetTester t) =>
    t.widget<RelayButton>(_save()).onPressed != null;

void main() {
  testWidgets('shows current profile values', (t) async {
    await _pump(t);
    expect(find.text('Profile'), findsOneWidget);
    expect(t.widget<TextField>(_field(0)).controller!.text, 'Ada L');
    expect(t.widget<TextField>(_field(1)).controller!.text, 'ada');
    expect(t.widget<TextField>(_field(2)).controller!.text, 'ada@example.com');
    expect(t.widget<TextField>(_field(2)).readOnly, isTrue);
  });

  testWidgets('save disabled until a change', (t) async {
    await _pump(t);
    expect(_saveEnabled(t), isFalse);
    await t.enterText(_field(0), 'Ada Lovelace');
    await t.pump();
    expect(_saveEnabled(t), isTrue);
    await t.enterText(_field(0), 'Ada L');
    await t.pump();
    expect(_saveEnabled(t), isFalse);
  });

  testWidgets('saves display name only, then resets baseline', (t) async {
    final (_, profiles) = await _pump(t);
    await t.enterText(_field(0), 'New Name');
    await t.pump();
    await t.tap(_save());
    await t.pumpAndSettle();

    expect(profiles.updateCalls, [(displayName: 'New Name', username: null)]);
    expect(find.text('Profile updated'), findsOneWidget);
    expect(_saveEnabled(t), isFalse);
    expect(t.widget<TextField>(_field(0)).controller!.text, 'New Name');
  });

  testWidgets('taken username error on save', (t) async {
    final (_, profiles) = await _pump(t);
    profiles.nextError = const AuthFailure(AuthFailureCode.usernameTaken);
    await t.enterText(_field(1), 'grace');
    await t.pump();
    await t.tap(_save());
    await t.pumpAndSettle();

    expect(profiles.updateCalls, [(displayName: null, username: 'grace')]);
    expect(find.text('That username is taken.'), findsOneWidget);
    expect(find.text('Profile updated'), findsNothing);
  });

  testWidgets('empty name is rejected without saving', (t) async {
    final (_, profiles) = await _pump(t);
    await t.enterText(_field(0), '  ');
    await t.pump();
    await t.tap(_save());
    await t.pumpAndSettle();
    expect(profiles.updateCalls, isEmpty);
    expect(find.text('Enter your name.'), findsOneWidget);
  });

  testWidgets('other failures show a banner', (t) async {
    final (_, profiles) = await _pump(t);
    profiles.nextError = const AuthFailure(AuthFailureCode.network);
    await t.enterText(_field(0), 'New Name');
    await t.pump();
    await t.tap(_save());
    await t.pumpAndSettle();
    expect(
      find.text(const AuthFailure(AuthFailureCode.network).message),
      findsOneWidget,
    );
  });

  testWidgets('sign out calls repository', (t) async {
    final (auth, _) = await _pump(t);
    await t.tap(find.text('Sign out'));
    await t.pumpAndSettle();
    expect(auth.signOutCalls, 1);
  });

  testWidgets('back goes home when it cannot pop', (t) async {
    await _pump(t);
    await t.tap(find.byTooltip('Back'));
    await t.pumpAndSettle();
    expect(find.text('HOME PAGE'), findsOneWidget);
  });

  testWidgets('load error offers retry', (t) async {
    final (_, profiles) = await _pump(t, loadError: StateError('boom'));
    expect(find.text('Couldn’t load your profile.'), findsOneWidget);
    profiles.loadError = null;
    await t.tap(find.text('Try again'));
    await t.pumpAndSettle();
    expect(find.text('Couldn’t load your profile.'), findsNothing);
    expect(t.widget<TextField>(_field(0)).controller!.text, 'Ada L');
  });

  testWidgets('shows skeleton while loading', (t) async {
    final gate = Completer<void>();
    t.view.physicalSize = const Size(600, 1200);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
          profileRepositoryProvider.overrideWithValue(FakeProfileRepository()),
          myProfileProvider.overrideWith((_) => gate.future.then((_) => _ada)),
        ],
        child: MaterialApp(
          theme: buildRelayTheme(
            Brightness.light,
            platform: TargetPlatform.iOS,
            isWeb: false,
          ),
          home: const ProfileScreen(),
        ),
      ),
    );
    await t.pump();
    expect(find.byType(TextField), findsNothing);
    expect(find.byKey(const ValueKey('profile-skeleton')), findsOneWidget);
    gate.complete();
    await t.pumpAndSettle();
  });
}
