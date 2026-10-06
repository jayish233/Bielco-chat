import 'package:chatapp/core/theme/tokens.dart';
import 'package:chatapp/core/ui/relay_avatar.dart';
import 'package:chatapp/core/ui/relay_button.dart';
import 'package:chatapp/core/ui/relay_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/pump.dart';

void main() {
  testWidgets('primary button uses platform control height', (t) async {
    await pumpRelay(
      t,
      RelayButton(label: 'Sign in', onPressed: () {}),
      platform: TargetPlatform.iOS,
    );
    expect(t.getSize(find.byType(RelayButton)).height, 54);
    await pumpRelay(
      t,
      RelayButton(label: 'Sign in', onPressed: () {}),
      platform: TargetPlatform.android,
    );
    expect(t.getSize(find.byType(RelayButton)).height, 56);
  });

  testWidgets(
    'loading button ignores taps and keeps its label for screen readers',
    (t) async {
      var taps = 0;
      await pumpRelay(
        t,
        RelayButton(label: 'Sign in', onPressed: () => taps++, loading: true),
      );
      await t.tap(find.byType(RelayButton));
      expect(taps, 0);
      expect(find.bySemanticsLabel('Sign in'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    },
  );

  testWidgets('password field toggles visibility with labelled 44px button', (
    t,
  ) async {
    await pumpRelay(t, const RelayTextField(label: 'Password', obscure: true));
    expect(t.widget<TextField>(find.byType(TextField)).obscureText, isTrue);
    expect(
      t.getSize(find.byTooltip('Show password')).width,
      greaterThanOrEqualTo(44),
    );
    await t.tap(find.byTooltip('Show password'));
    await t.pump();
    expect(t.widget<TextField>(find.byType(TextField)).obscureText, isFalse);
    expect(find.byTooltip('Hide password'), findsOneWidget);
  });

  testWidgets('error text renders under the field', (t) async {
    await pumpRelay(
      t,
      const RelayTextField(label: 'Email', errorText: 'Enter your email.'),
    );
    expect(find.text('Enter your email.'), findsOneWidget);
  });

  test('initials', () {
    expect(initialsFor('Aisha Khan'), 'AK');
    expect(initialsFor('priya'), 'P');
    expect(initialsFor('Mary Jane Watson'), 'MJ');
    expect(initialsFor('   '), '?');
  });

  test('avatar tint is stable and from the 5 token tints', () {
    expect(avatarTintFor('user-1'), avatarTintFor('user-1'));
    expect(RelayColors.avatarTints, contains(avatarTintFor('anything')));
  });

  testWidgets('avatar is a circle on Android, rounded square elsewhere', (
    t,
  ) async {
    BorderRadius radius() {
      final box = t.widget<DecoratedBox>(
        find.descendant(
          of: find.byType(RelayAvatar),
          matching: find.byType(DecoratedBox),
        ),
      );
      return (box.decoration as BoxDecoration).borderRadius! as BorderRadius;
    }

    await pumpRelay(
      t,
      const RelayAvatar(name: 'Aisha Khan', seed: 'a', size: 40),
      platform: TargetPlatform.android,
    );
    expect(radius().topLeft.x, greaterThanOrEqualTo(20));
    await pumpRelay(
      t,
      const RelayAvatar(name: 'Aisha Khan', seed: 'a', size: 40),
      platform: TargetPlatform.iOS,
    );
    expect(radius().topLeft.x, closeTo(12, 0.001));
  });
}
