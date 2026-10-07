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

/// Corner radius for an avatar of [size] on this platform.
double avatarRadius(BuildContext context, double size) =>
    context.metrics.circularAvatars ? size / 2 : size * 0.3;

class RelayAvatar extends StatelessWidget {
  const RelayAvatar({
    super.key,
    required this.name,
    required this.seed,
    this.size = 36,
    this.imageUrl,
    this.online,
  });

  final String name;
  final String seed;
  final double size;

  /// Photo; falls back to initials while loading or on error.
  final String? imageUrl;

  /// Presence dot: true = online, false = offline ring, null = none.
  final bool? online;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(avatarRadius(context, size));
    final initials = Center(
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
    );
    final url = imageUrl;
    Widget tile = DecoratedBox(
      decoration: BoxDecoration(
        color: avatarTintFor(seed),
        borderRadius: radius,
      ),
      child: url == null
          ? initials
          : ClipRRect(
              borderRadius: radius,
              child: Image.network(
                url,
                width: size,
                height: size,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => initials,
                frameBuilder: (_, child, frame, sync) =>
                    frame == null && !sync ? initials : child,
              ),
            ),
    );
    tile = SizedBox(width: size, height: size, child: tile);
    final isOnline = online;
    if (isOnline != null) {
      tile = Stack(
        clipBehavior: Clip.none,
        children: [
          tile,
          Positioned(
            right: -2,
            bottom: -2,
            child: PresenceDot(online: isOnline, size: size < 40 ? 10 : 14),
          ),
        ],
      );
    }
    return Semantics(
      label: isOnline == true ? '$name, online' : name,
      image: true,
      child: ExcludeSemantics(child: tile),
    );
  }
}

/// Online = green dot; offline = hollow grey ring. Ringed in the surface color.
class PresenceDot extends StatelessWidget {
  const PresenceDot({super.key, required this.online, this.size = 12});

  final bool online;
  final double size;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: online ? p.online : p.background,
        border: Border.all(color: p.background, width: 2),
      ),
      child: online
          ? null
          : DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: p.placeholder, width: 1.5),
              ),
            ),
    );
  }
}

/// A group's avatar: the `#` glyph, solid ink when [highlighted] (unread).
class GroupAvatar extends StatelessWidget {
  const GroupAvatar({
    super.key,
    required this.name,
    this.size = 36,
    this.highlighted = false,
  });

  final String name;
  final double size;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Semantics(
      label: name,
      image: true,
      child: ExcludeSemantics(
        child: Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: highlighted ? p.ink : p.fillMuted,
            borderRadius: BorderRadius.circular(avatarRadius(context, size)),
          ),
          child: Text(
            '#',
            style: TextStyle(
              fontFamily: RelayFonts.mono,
              fontSize: size * 0.42,
              color: highlighted ? p.onInk : p.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

/// Cobalt count pill; hidden at zero. Caps at 99+.
class UnreadBadge extends StatelessWidget {
  const UnreadBadge({super.key, required this.count, this.small = false});

  final int count;
  final bool small;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();
    final h = small ? 18.0 : 22.0;
    return Container(
      constraints: BoxConstraints(minWidth: h),
      height: h,
      padding: EdgeInsets.symmetric(horizontal: small ? 5 : 7),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: context.palette.accent,
        borderRadius: BorderRadius.circular(h / 2),
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        semanticsLabel: '$count unread',
        style: TextStyle(
          fontFamily: RelayFonts.sans,
          color: RelayColors.surface,
          fontSize: small ? 11 : 13,
          fontWeight: FontWeight.w600,
          height: 1,
        ),
      ),
    );
  }
}
