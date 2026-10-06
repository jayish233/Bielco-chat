import 'package:chatapp/core/theme/app_theme.dart';
import 'package:chatapp/core/theme/relay_metrics.dart';
import 'package:chatapp/core/theme/relay_palette.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/theme_matchers.dart';

void main() {
  test('light palette mirrors tokens', () {
    final t = buildRelayTheme(
      Brightness.light,
      platform: TargetPlatform.iOS,
      isWeb: false,
    );
    final p = t.extension<RelayPalette>()!;
    expect(p.ink, const Color(0xFF0B0B0C));
    expect(p.accent, const Color(0xFF2B50F5));
    expect(t.scaffoldBackgroundColor, const Color(0xFFFFFFFF));
    expect(t.textTheme.bodyMedium!.fontFamily, 'Geist');
  });

  test('dark palette inverts ground and keeps cobalt', () {
    final p = buildRelayTheme(
      Brightness.dark,
      platform: TargetPlatform.android,
      isWeb: false,
    ).extension<RelayPalette>()!;
    expect(p.background, const Color(0xFF0B0B0C));
    expect(p.surface, const Color(0xFF17171A));
    expect(p.accent, const Color(0xFF2B50F5));
  });

  test('metrics per platform', () {
    expect(
      RelayMetrics.forPlatform(TargetPlatform.iOS, isWeb: true).controlHeight,
      48,
    ); // web wins
    expect(
      RelayMetrics.forPlatform(TargetPlatform.iOS, isWeb: false),
      hasMetrics(54, 14, 44, false),
    );
    expect(
      RelayMetrics.forPlatform(TargetPlatform.android, isWeb: false),
      hasMetrics(56, 999, 48, true),
    );
    expect(
      RelayMetrics.forPlatform(TargetPlatform.macOS, isWeb: false),
      hasMetrics(48, 12, 40, false),
    );
  });

  for (final b in Brightness.values) {
    test('text colors meet 4.5:1 on background and surface ($b)', () {
      final p = buildRelayTheme(
        b,
        platform: TargetPlatform.iOS,
        isWeb: false,
      ).extension<RelayPalette>()!;
      for (final fg in [
        p.ink,
        p.textSecondary,
        p.textMuted,
        p.textSubtle,
        p.dangerText,
        p.accentStrong,
      ]) {
        expect(contrastRatio(fg, p.background), greaterThanOrEqualTo(4.5));
        expect(contrastRatio(fg, p.surface), greaterThanOrEqualTo(4.5));
      }
    });
  }

  test('palette equality follows its colors', () {
    expect(RelayPalette.light, RelayPalette.light.copyWith());
    expect(RelayPalette.light.hashCode, RelayPalette.light.copyWith().hashCode);
    expect(RelayPalette.light, isNot(equals(RelayPalette.dark)));
    expect(
      RelayPalette.light.copyWith(accent: const Color(0xFF000000)),
      isNot(equals(RelayPalette.light)),
    );
  });
}
