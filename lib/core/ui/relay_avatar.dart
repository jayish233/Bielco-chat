import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/tokens.dart';

/// Up to two initials: first letters of the first and second words.
String initialsFor(String name) {
  final words = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .toList();
  if (words.isEmpty) return '?';
  final first = String.fromCharCode(words.first.runes.first).toUpperCase();
  if (words.length == 1) return first;
  return first + String.fromCharCode(words[1].runes.first).toUpperCase();
}

/// Stable tint for [seed]: sum of UTF-16 code units modulo the tint count.
Color avatarTintFor(String seed) {
  final sum = seed.codeUnits.fold<int>(0, (a, b) => a + b);
  return RelayColors.avatarTints[sum % RelayColors.avatarTints.length];
}

class RelayAvatar extends StatelessWidget {
  const RelayAvatar({
    super.key,
    required this.name,
    required this.seed,
    this.size = 36,
  });

  final String name;
  final String seed;
  final double size;

  @override
  Widget build(BuildContext context) {
    final circular = context.metrics.circularAvatars;
    return Semantics(
      label: name,
      image: true,
      child: ExcludeSemantics(
        child: SizedBox(
          width: size,
          height: size,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: avatarTintFor(seed),
              borderRadius: BorderRadius.circular(
                circular ? size / 2 : size * 0.3,
              ),
            ),
            child: Center(
              // Tints are light in both themes, so the text stays fixed ink.
              child: Text(
                initialsFor(name),
                style: TextStyle(
                  fontFamily: RelayFonts.sans,
                  fontSize: size * 0.38,
                  fontWeight: FontWeight.w600,
                  color: RelayColors.ink,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
