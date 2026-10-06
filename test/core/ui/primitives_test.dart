import 'dart:ui' show Tristate;

import 'package:chatapp/core/theme/tokens.dart';
import 'package:chatapp/core/ui/relay_avatar.dart';
import 'package:chatapp/core/theme/relay_palette.dart';
import 'package:chatapp/core/ui/relay_button.dart';
import 'package:chatapp/core/ui/relay_logo.dart';
import 'package:chatapp/core/ui/relay_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
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
    expect(t.widget<TextField>(find.byType(TextField)).autocorrect, isFalse);
    expect(
      t.widget<TextField>(find.byType(TextField)).enableSuggestions,
      isFalse,
    );
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

  testWidgets('enabled button exposes a tap action; loading does not', (
    t,
  ) async {
    final h = t.ensureSemantics();
    await pumpRelay(t, RelayButton(label: 'Sign in', onPressed: () {}));
    var n = t.getSemantics(find.byType(RelayButton));
    expect(n.label, 'Sign in');
    expect(n.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
    expect(
      n.getSemanticsData().flagsCollection.isEnabled == Tristate.isTrue,
      isTrue,
    );
    await pumpRelay(
      t,
      RelayButton(label: 'Sign in', onPressed: () {}, loading: true),
    );
    n = t.getSemantics(find.byType(RelayButton));
    expect(n.getSemanticsData().hasAction(SemanticsAction.tap), isFalse);
    expect(
      n.getSemanticsData().flagsCollection.isEnabled == Tristate.isTrue,
      isFalse,
    );
    h.dispose();
  });

  testWidgets('error text is part of the field semantics', (t) async {
    final h = t.ensureSemantics();
    await pumpRelay(
      t,
      const RelayTextField(label: 'Email', errorText: 'Enter your email.'),
    );
    final n = t.getSemantics(find.byType(TextField));
    expect(n.hint, contains('Enter your email.'));
    expect(n.label, contains('Email'));
    h.dispose();
  });

  testWidgets('logo is palette-aware in dark theme', (t) async {
    await pumpRelay(t, const RelayLogo(), brightness: Brightness.dark);
    LogoPainter painter() =>
        t
                .widget<CustomPaint>(
                  find.descendant(
                    of: find.byType(RelayLogo),
                    matching: find.byType(CustomPaint),
                  ),
                )
                .painter!
            as LogoPainter;
    expect(painter().tile, RelayPalette.dark.ink);
    expect(painter().mark, RelayPalette.dark.onInk);
    await pumpRelay(
      t,
      const RelayLogo(inverted: true),
      brightness: Brightness.dark,
    );
    expect(painter().tile, RelayPalette.dark.onInk);
  });
}
