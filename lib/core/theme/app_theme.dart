import 'package:flutter/material.dart';

import 'relay_metrics.dart';
import 'relay_palette.dart';
import 'tokens.dart';

ThemeData buildRelayTheme(
  Brightness brightness, {
  required TargetPlatform platform,
  required bool isWeb,
}) {
  final p =
      brightness == Brightness.dark ? RelayPalette.dark : RelayPalette.light;
  final metrics = RelayMetrics.forPlatform(platform, isWeb: isWeb);

  TextStyle style(
    double size,
    FontWeight weight, {
    double tracking = 0,
    double? height,
    Color? color,
  }) =>
      TextStyle(
        fontFamily: RelayFonts.sans,
        fontSize: size,
        fontWeight: weight,
        letterSpacing: tracking * size,
        height: height,
        color: color ?? p.ink,
      );

  final textTheme = TextTheme(
    displayLarge: style(52, FontWeight.w600, tracking: -0.035, height: 1.05),
    headlineLarge: style(32, FontWeight.w600, tracking: -0.03),
    titleMedium: style(17, FontWeight.w600, tracking: -0.02),
    bodyLarge: style(16, FontWeight.w400, height: 1.5),
    bodyMedium: style(15, FontWeight.w400, height: 1.5),
    bodySmall:
        style(13, FontWeight.w400, height: 1.45, color: p.textMuted),
    labelLarge: style(14, FontWeight.w500),
    labelSmall:
        style(12, FontWeight.w500, tracking: 0.04, color: p.textMuted),
  );

  final colorScheme = ColorScheme(
    brightness: brightness,
    primary: p.ink,
    onPrimary: p.onInk,
    secondary: p.accent,
    onSecondary: RelayColors.surface,
    error: p.danger,
    onError: RelayColors.surface,
    surface: p.background,
    onSurface: p.ink,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    platform: platform,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: p.background,
    canvasColor: p.background,
    fontFamily: RelayFonts.sans,
    textTheme: textTheme,
    dividerColor: p.hairline,
    extensions: [p, metrics],
  );
}

extension RelayThemeX on BuildContext {
  RelayPalette get palette => Theme.of(this).extension<RelayPalette>()!;
  RelayMetrics get metrics => Theme.of(this).extension<RelayMetrics>()!;
}
