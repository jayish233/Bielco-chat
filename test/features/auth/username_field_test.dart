import 'dart:async';

import 'package:chatapp/core/providers.dart';
import 'package:chatapp/features/auth/ui/username_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fakes.dart';
import '../../support/pump.dart';

Future<FakeProfileRepository> _pump(
  WidgetTester t,
  TextEditingController controller, {
  String? currentUsername,
}) async {
  final profiles = FakeProfileRepository();
  await pumpRelay(
    t,
    UsernameField(controller: controller, currentUsername: currentUsername),
    overrides: [profileRepositoryProvider.overrideWithValue(profiles)],
  );
  return profiles;
}

void main() {
  testWidgets('current username (case-insensitive) is never checked', (
    t,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    final profiles = await _pump(t, controller, currentUsername: 'priya');

    await t.enterText(find.byType(TextField), 'Priya');
    await t.pump(const Duration(milliseconds: 400));
    await t.pump();

    expect(profiles.availabilityCalls, isEmpty);
    expect(find.textContaining('is available'), findsNothing);
    expect(find.text('That username is taken.'), findsNothing);
  });

  testWidgets('stale availability response is ignored', (t) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    final profiles = await _pump(t, controller);
    final first = Completer<bool>();
    profiles.availabilityGates['first'] = first;
    profiles.takenUsernames = {'second'};

    await t.enterText(find.byType(TextField), 'first');
    await t.pump(const Duration(milliseconds: 400));
    expect(profiles.availabilityCalls, ['first']);

    await t.enterText(find.byType(TextField), 'second');
    await t.pump(const Duration(milliseconds: 400));
    await t.pump();
    expect(find.text('That username is taken.'), findsOneWidget);

    // The first (now stale) check finally reports "available".
    first.complete(true);
    await t.pump();

    expect(find.text('@first is available'), findsNothing);
    expect(find.text('That username is taken.'), findsOneWidget);
  });
}
