import 'package:flutter/painting.dart';

/// Design tokens mirrored from `tokens.json`. Single source of truth in code.
abstract final class RelayColors {
  static const Color ink = Color(0xFF0B0B0C);
  static const Color ink2 = Color(0xFF26262B);
  static const Color textSecondary = Color(0xFF3A3A40);
  static const Color textMuted = Color(0xFF5E5E66);
  static const Color textSubtle = Color(0xFF6B6B72);
  static const Color placeholder = Color(0xFF8A8A91);
  static const Color borderStrong = Color(0xFFD4D4D8);
  static const Color border = Color(0xFFE4E4E7);
  static const Color hairline = Color(0xFFECECEE);
  static const Color fillMuted = Color(0xFFF1F1F3);
  static const Color surfaceAlt = Color(0xFFFAFAF9);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color accent = Color(0xFF2B50F5);
  static const Color accentStrong = Color(0xFF1F3FD1);
  static const Color accentSoft = Color(0xFFEEF1FF);
  static const Color online = Color(0xFF12A150);
  static const Color away = Color(0xFFE5A50A);
  static const Color danger = Color(0xFFC4281C);
  static const Color dangerText = Color(0xFFB02418);
  static const Color darkSurface = Color(0xFF17171A);
  static const Color darkBorder = Color(0xFF2A2A2F);
  static const Color darkTextMuted = Color(0xFFB4B4BB);
  static const Color darkSurfaceAlt = Color(0xFF111113);
  static const Color darkInk = Color(0xFFF4F4F5);
  static const Color darkTextSecondary = Color(0xFFD4D4D8);
  static const Color darkTextSubtle = Color(0xFFA1A1A8);
  static const Color darkBorderStrong = Color(0xFF3A3A40);
  static const Color darkHairline = Color(0xFF24242A);
  static const Color darkFillMuted = Color(0xFF1F1F23);
  static const Color darkAccentStrong = Color(0xFF8FA6FF);
  static const Color darkAccentSoft = Color(0xFF1A2250);

  /// Not in tokens.css; chosen for contrast on dark surfaces.
  static const Color darkDangerText = Color(0xFFF28B82);

  static const List<Color> avatarTints = [
    Color(0xFFDDE6F7),
    Color(0xFFE3EFE6),
    Color(0xFFE8E4DC),
    Color(0xFFF4E3DA),
    Color(0xFFECE3F3),
  ];
}

abstract final class RelaySpace {
  static const double s1 = 4;
  static const double s2 = 8;
  static const double s3 = 12;
  static const double s4 = 16;
  static const double s5 = 20;
  static const double s6 = 24;
  static const double s8 = 32;
  static const double s10 = 40;
  static const double s12 = 48;
  static const double s14 = 56;
}

abstract final class RelayRadius {
  static const double sm = 6;
  static const double md = 10;
  static const double lg = 12;
  static const double xl = 14;
  static const double xxl = 16;
  static const double bubble = 20;
  static const double pill = 999;
}

abstract final class RelayFonts {
  static const String sans = 'Geist';
  static const String sansMedium = 'GeistMedium';
  static const String sansSemiBold = 'GeistSemiBold';
  static const String mono = 'GeistMono';
  static const String monoMedium = 'GeistMonoMedium';

  /// One file per family so iOS/Impeller cannot paint Regular under a
  /// heavier face (that doubled every glyph as "Relayout" / "Emaill").
  static String sansFor(FontWeight weight) {
    if (weight.value >= 600) return sansSemiBold;
    if (weight.value >= 500) return sansMedium;
    return sans;
  }

  static String monoFor(FontWeight weight) {
    if (weight.value >= 500) return monoMedium;
    return mono;
  }
}
