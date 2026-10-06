import 'package:flutter/material.dart';

import 'tokens.dart';

/// Semantic color roles, resolved per brightness.
@immutable
class RelayPalette extends ThemeExtension<RelayPalette> {
  const RelayPalette({
    required this.background,
    required this.surface,
    required this.surfaceAlt,
    required this.ink,
    required this.onInk,
    required this.textSecondary,
    required this.textMuted,
    required this.textSubtle,
    required this.placeholder,
    required this.border,
    required this.borderStrong,
    required this.hairline,
    required this.fillMuted,
    required this.accent,
    required this.accentStrong,
    required this.accentSoft,
    required this.online,
    required this.away,
    required this.danger,
    required this.dangerText,
  });

  final Color background;
  final Color surface;
  final Color surfaceAlt;
  final Color ink;
  final Color onInk;
  final Color textSecondary;
  final Color textMuted;
  final Color textSubtle;
  final Color placeholder;
  final Color border;
  final Color borderStrong;
  final Color hairline;
  final Color fillMuted;
  final Color accent;
  final Color accentStrong;
  final Color accentSoft;
  final Color online;
  final Color away;
  final Color danger;
  final Color dangerText;

  static const RelayPalette light = RelayPalette(
    background: RelayColors.surface,
    surface: RelayColors.surface,
    surfaceAlt: RelayColors.surfaceAlt,
    ink: RelayColors.ink,
    onInk: RelayColors.surface,
    textSecondary: RelayColors.textSecondary,
    textMuted: RelayColors.textMuted,
    textSubtle: RelayColors.textSubtle,
    placeholder: RelayColors.placeholder,
    border: RelayColors.border,
    borderStrong: RelayColors.borderStrong,
    hairline: RelayColors.hairline,
    fillMuted: RelayColors.fillMuted,
    accent: RelayColors.accent,
    accentStrong: RelayColors.accentStrong,
    accentSoft: RelayColors.accentSoft,
    online: RelayColors.online,
    away: RelayColors.away,
    danger: RelayColors.danger,
    dangerText: RelayColors.dangerText,
  );

  static const RelayPalette dark = RelayPalette(
    background: RelayColors.ink,
    surface: RelayColors.darkSurface,
    surfaceAlt: Color(0xFF111113),
    ink: Color(0xFFF4F4F5),
    onInk: RelayColors.ink,
    textSecondary: Color(0xFFD4D4D8),
    textMuted: RelayColors.darkTextMuted,
    textSubtle: Color(0xFFA1A1A8),
    placeholder: RelayColors.placeholder,
    border: RelayColors.darkBorder,
    borderStrong: Color(0xFF3A3A40),
    hairline: Color(0xFF24242A),
    fillMuted: Color(0xFF1F1F23),
    accent: RelayColors.accent,
    accentStrong: Color(0xFF8FA6FF),
    accentSoft: Color(0xFF1A2250),
    online: RelayColors.online,
    away: RelayColors.away,
    danger: RelayColors.danger,
    dangerText: Color(0xFFF28B82),
  );

  @override
  RelayPalette copyWith({
    Color? background,
    Color? surface,
    Color? surfaceAlt,
    Color? ink,
    Color? onInk,
    Color? textSecondary,
    Color? textMuted,
    Color? textSubtle,
    Color? placeholder,
    Color? border,
    Color? borderStrong,
    Color? hairline,
    Color? fillMuted,
    Color? accent,
    Color? accentStrong,
    Color? accentSoft,
    Color? online,
    Color? away,
    Color? danger,
    Color? dangerText,
  }) =>
      RelayPalette(
        background: background ?? this.background,
        surface: surface ?? this.surface,
        surfaceAlt: surfaceAlt ?? this.surfaceAlt,
        ink: ink ?? this.ink,
        onInk: onInk ?? this.onInk,
        textSecondary: textSecondary ?? this.textSecondary,
        textMuted: textMuted ?? this.textMuted,
        textSubtle: textSubtle ?? this.textSubtle,
        placeholder: placeholder ?? this.placeholder,
        border: border ?? this.border,
        borderStrong: borderStrong ?? this.borderStrong,
        hairline: hairline ?? this.hairline,
        fillMuted: fillMuted ?? this.fillMuted,
        accent: accent ?? this.accent,
        accentStrong: accentStrong ?? this.accentStrong,
        accentSoft: accentSoft ?? this.accentSoft,
        online: online ?? this.online,
        away: away ?? this.away,
        danger: danger ?? this.danger,
        dangerText: dangerText ?? this.dangerText,
      );

  @override
  RelayPalette lerp(ThemeExtension<RelayPalette>? other, double t) {
    if (other is! RelayPalette) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return RelayPalette(
      background: l(background, other.background),
      surface: l(surface, other.surface),
      surfaceAlt: l(surfaceAlt, other.surfaceAlt),
      ink: l(ink, other.ink),
      onInk: l(onInk, other.onInk),
      textSecondary: l(textSecondary, other.textSecondary),
      textMuted: l(textMuted, other.textMuted),
      textSubtle: l(textSubtle, other.textSubtle),
      placeholder: l(placeholder, other.placeholder),
      border: l(border, other.border),
      borderStrong: l(borderStrong, other.borderStrong),
      hairline: l(hairline, other.hairline),
      fillMuted: l(fillMuted, other.fillMuted),
      accent: l(accent, other.accent),
      accentStrong: l(accentStrong, other.accentStrong),
      accentSoft: l(accentSoft, other.accentSoft),
      online: l(online, other.online),
      away: l(away, other.away),
      danger: l(danger, other.danger),
      dangerText: l(dangerText, other.dangerText),
    );
  }
}
