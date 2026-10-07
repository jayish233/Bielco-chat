import 'package:chatapp/app.dart';
import 'package:chatapp/core/providers.dart';
import 'package:chatapp/core/router.dart';
import 'package:chatapp/features/auth/data/auth_repository.dart';
import 'package:chatapp/features/profile/domain/profile.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'chat_fakes.dart';
import 'fakes.dart';

final me = person('me', 'Ada Lovelace', username: 'ada');

/// Pumps the whole app, signed in as [me], with chat fakes.
Future<({ChatFakes fakes, GoRouter router, FakeAuthRepository auth})> pumpApp(
  WidgetTester t, {
  ChatFakes? fakes,
  Size size = const Size(400, 860),
  AuthStatus status = AuthStatus.signedIn,
  String? location,
}) async {
  final f = fakes ?? ChatFakes();
  f.messages.me = me.id;
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  final auth = FakeAuthRepository(status: status)..currentUserId = me.id;
  addTearDown(auth.dispose);
  await t.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        profileRepositoryProvider.overrideWithValue(
          FakeProfileRepository(profile: me),
        ),
        ...f.overrides,
      ],
      child: const RelayApp(),
    ),
  );
  final container = ProviderScope.containerOf(t.element(find.byType(RelayApp)));
  final router = container.read(routerProvider);
  if (location != null) router.go(location);
  await t.pumpAndSettle();
  // Let debounced timers (mark-read) fire.
  await t.pump(const Duration(seconds: 1));
  return (fakes: f, router: router, auth: auth);
}

Profile get myProfile => me;
