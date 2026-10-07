import 'package:flutter/material.dart';

import 'relay_metrics.dart';
import 'relay_palette.dart';
import 'tokens.dart';

ThemeData buildRelayTheme(
  Brightness brightness, {
  required TargetPlatform platform,
  required bool isWeb,
}) {
  final p = brightness == Brightness.dark
      ? RelayPalette.dark
      : RelayPalette.light;
  final metrics = RelayMetrics.forPlatform(platform, isWeb: isWeb);

  TextStyle style(
    double size,
    FontWeight weight, {
    double tracking = 0,
    double? height,
    Color? color,
  }) => TextStyle(
    fontFamily: RelayFonts.sansFor(weight),
    fontSize: size,
    fontWeight: FontWeight.w400,
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
    bodySmall: style(13, FontWeight.w400, height: 1.45, color: p.textMuted),
    labelLarge: style(14, FontWeight.w500),
    labelSmall: style(12, FontWeight.w500, tracking: 0.04, color: p.textMuted),
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
    onSurfaceVariant: p.textMuted,
    surfaceContainerLowest: p.background,
    surfaceContainerLow: p.surfaceAlt,
    surfaceContainer: p.surface,
    surfaceContainerHigh: p.surface,
    surfaceContainerHighest: p.fillMuted,
    outline: p.borderStrong,
    outlineVariant: p.hairline,
    primaryContainer: p.fillMuted,
    onPrimaryContainer: p.ink,
    secondaryContainer: p.fillMuted,
    onSecondaryContainer: p.ink,
    inverseSurface: p.ink,
    onInverseSurface: p.onInk,
    surfaceTint: Colors.transparent,
  );
  final shape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(RelayRadius.xxl),
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
    dividerTheme: DividerThemeData(color: p.hairline, space: 1, thickness: 1),
    appBarTheme: AppBarTheme(
      backgroundColor: p.background,
      foregroundColor: p.ink,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: textTheme.titleMedium,
      shape: Border(bottom: BorderSide(color: p.hairline)),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: p.surface,
      surfaceTintColor: Colors.transparent,
      shape: shape,
      titleTextStyle: textTheme.titleMedium,
      contentTextStyle: textTheme.bodyMedium,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: p.surface,
      modalBackgroundColor: p.surface,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      dragHandleColor: p.borderStrong,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(RelayRadius.bubble),
        ),
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: p.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(RelayRadius.lg),
        side: BorderSide(color: p.border),
      ),
      textStyle: textTheme.bodyMedium,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: p.ink,
      contentTextStyle: textTheme.bodyMedium?.copyWith(color: p.onInk),
      actionTextColor: p.onInk,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(RelayRadius.lg),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: p.background,
      surfaceTintColor: Colors.transparent,
      indicatorColor: p.fillMuted,
      height: 64,
      labelTextStyle: WidgetStatePropertyAll(
        textTheme.labelSmall?.copyWith(letterSpacing: 0, color: p.ink),
      ),
      iconTheme: WidgetStatePropertyAll(IconThemeData(color: p.ink)),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: p.surface,
      selectedColor: p.ink,
      labelStyle: textTheme.labelLarge?.copyWith(color: p.textSecondary),
      secondaryLabelStyle: textTheme.labelLarge?.copyWith(color: p.onInk),
      side: BorderSide(color: p.border),
      shape: const StadiumBorder(),
      showCheckmark: false,
      checkmarkColor: p.onInk,
    ),
    listTileTheme: ListTileThemeData(
      iconColor: p.textSecondary,
      textColor: p.ink,
      titleTextStyle: textTheme.bodyLarge,
      subtitleTextStyle: textTheme.bodySmall,
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? p.ink : Colors.transparent,
      ),
      checkColor: WidgetStatePropertyAll(p.onInk),
      side: BorderSide(color: p.borderStrong, width: 1.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: p.ink),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: p.ink,
      selectionColor: p.accent.withValues(alpha: 0.25),
      selectionHandleColor: p.accent,
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: p.ink,
        borderRadius: BorderRadius.circular(RelayRadius.sm),
      ),
      textStyle: textTheme.bodySmall?.copyWith(color: p.onInk),
    ),
    extensions: [p, metrics],
  );
}

extension RelayThemeX on BuildContext {
  RelayPalette get palette => Theme.of(this).extension<RelayPalette>()!;
  RelayMetrics get metrics => Theme.of(this).extension<RelayMetrics>()!;
}
