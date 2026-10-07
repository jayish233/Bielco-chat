import 'package:chatapp/app.dart';
import 'package:chatapp/core/providers.dart';
import 'package:chatapp/features/auth/data/auth_repository.dart';
import 'package:chatapp/features/profile/domain/profile.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/chat_fakes.dart';
import 'support/fakes.dart';

Future<FakeAuthRepository> _pump(WidgetTester t, AuthStatus status) async {
  final auth = FakeAuthRepository(status: status)..currentUserId = 'u1';
  final profiles = FakeProfileRepository(
    profile: const Profile(id: 'u1', username: 'ada', displayName: 'Ada L'),
  );
  addTearDown(auth.dispose);
  await t.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        profileRepositoryProvider.overrideWithValue(profiles),
        ...ChatFakes().overrides,
      ],
      child: const RelayApp(),
    ),
  );
  await t.pumpAndSettle();
  return auth;
}

void main() {
  testWidgets('signed out starts on sign-in; signing in shows home', (t) async {
    final auth = await _pump(t, AuthStatus.signedOut);
    expect(find.text('Welcome back'), findsOneWidget);

    auth.emit(AuthStatus.signedIn);
    await t.pumpAndSettle();

    expect(find.text('No conversations yet'), findsOneWidget);
    expect(
      find.text('Chats with your group will show up here.'),
      findsOneWidget,
    );
  });

  testWidgets('session ending on /profile returns to sign-in', (t) async {
    final auth = await _pump(t, AuthStatus.signedIn);
    expect(find.text('No conversations yet'), findsOneWidget);

    await t.tap(find.byTooltip('Your profile'));
    await t.pumpAndSettle();
    expect(find.text('No conversations yet'), findsNothing);

    auth.emit(AuthStatus.signedOut);
    await t.pumpAndSettle();
    expect(find.text('Welcome back'), findsOneWidget);
  });

  testWidgets('signed-in shell re-checks access with the server', (t) async {
    final auth = await _pump(t, AuthStatus.signedIn);
    expect(auth.revalidateCalls, 1);
  });
}
