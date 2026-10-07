// End-to-end on a real device/desktop against the local stack:
//   flutter test integration_test -d macos --dart-define-from-file=env/local.json
import 'package:chatapp/core/env.dart';
import 'package:chatapp/main.dart' as app;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../test_integration/support/test_admin.dart';

const _pw = 'relaypass24';

String _s() {
  final n = DateTime.now().microsecondsSinceEpoch.toString();
  return n.substring(n.length - 8);
}

final _admin = TestAdmin();

Future<SupabaseClient> _user(String username, String name) async {
  await _admin.allow('$username@example.com');
  final c = SupabaseClient(
    resolveEnv().url,
    resolveEnv().anonKey,
    authOptions: const AuthClientOptions(authFlowType: AuthFlowType.implicit),
  );
  await c.auth.signUp(
    email: '$username@example.com',
    password: _pw,
    data: {'username': username, 'display_name': name},
  );
  return c;
}

Future<void> _waitFor(WidgetTester t, Finder f, {int seconds = 15}) async {
  final end = DateTime.now().add(Duration(seconds: seconds));
  while (DateTime.now().isBefore(end)) {
    await t.pump(const Duration(milliseconds: 200));
    if (f.evaluate().isNotEmpty) return;
  }
  final shown = [
    for (final e in find.byType(Text).evaluate()) (e.widget as Text).data,
  ];
  throw TestFailure('Timed out waiting for $f. On screen: $shown');
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('sign in, open a DM, reply, and receive a live message', (
    t,
  ) async {
    final s = _s();
    final adaName = 'ada_$s';
    // Ada signs up out of band; signing in happens through the UI below.
    final adaSetup = await _user(adaName, 'Ada E2E');
    final adaId = adaSetup.auth.currentUser!.id;
    await adaSetup.dispose();

    final grace = await _user('grace_$s', 'Grace E2E');
    final dm = await grace.rpc(
      'get_or_create_dm',
      params: {'other_user_id': adaId},
    ) as String;
    await grace.from('messages').insert({
      'conversation_id': dm,
      'body': 'Hello from Grace',
    });

    await app.main();
    await t.pumpAndSettle();

    // A previous run's session persists on disk: sign out through the UI.
    final end = DateTime.now().add(const Duration(seconds: 10));
    while (DateTime.now().isBefore(end) &&
        find.text('Welcome back').evaluate().isEmpty &&
        find.byTooltip('Your profile').evaluate().isEmpty) {
      await t.pump(const Duration(milliseconds: 200));
    }
    if (find.byTooltip('Your profile').evaluate().isNotEmpty) {
      await t.tap(find.byTooltip('Your profile').first);
      await _waitFor(t, find.text('Sign out'));
      await t.tap(find.text('Sign out'));
    }
    await _waitFor(t, find.text('Welcome back'));
    await t.enterText(
      find.widgetWithText(TextField, 'Email').evaluate().isEmpty
          ? find.byType(TextField).at(0)
          : find.widgetWithText(TextField, 'Email'),
      '$adaName@example.com',
    );
    await t.enterText(find.byType(TextField).at(1), _pw);
    await t.tap(find.text('Sign in'));

    await _waitFor(t, find.text('Grace E2E'));
    expect(find.text('Hello from Grace'), findsOneWidget);
    await t.tap(find.text('Grace E2E'));
    await _waitFor(t, find.text('New'));

    // Reply through the composer.
    final composer = find.byType(TextField).last;
    await t.enterText(composer, 'Hi Grace, from the app');
    await t.pump();
    await t.tap(find.byTooltip('Send'));
    await _waitFor(t, find.byIcon(Icons.done));

    final rows = await grace
        .from('messages')
        .select('body, sender_id')
        .eq('conversation_id', dm)
        .order('created_at');
    expect(
      rows.map((r) => r['body']),
      contains('Hi Grace, from the app'),
      reason: '$rows',
    );
    expect(
      rows.firstWhere(
        (r) => r['body'] == 'Hi Grace, from the app',
      )['sender_id'],
      adaId,
    );

    // A message from Grace shows up live (realtime).
    await grace.from('messages').insert({
      'conversation_id': dm,
      'body': 'Got it, live!',
    });
    await _waitFor(t, find.text('Got it, live!'));

    // Grace reads → Ada's message shows as read.
    await grace.rpc('mark_read', params: {'conv': dm});
    await _waitFor(t, find.byIcon(Icons.done_all));

    // Optional: keep the final screen up for screenshots (HOLD_SECONDS=10).
    const hold = int.fromEnvironment('HOLD_SECONDS');
    for (var i = 0; i < hold * 5; i++) {
      await t.pump(const Duration(milliseconds: 200));
    }
    await grace.dispose();
    await _admin.cleanUp();
  });
}
