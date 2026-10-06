import 'dart:math' as math;
import 'dart:ui';

import 'package:chatapp/core/theme/relay_metrics.dart';
import 'package:flutter_test/flutter_test.dart';

/// WCAG 2.x contrast ratio between two opaque colors.
double contrastRatio(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = math.max(la, lb);
  final lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

Matcher hasMetrics(
  double controlHeight,
  double controlRadius,
  double iconButtonSize,
  bool circularAvatars,
) => isA<RelayMetrics>()
    .having((m) => m.controlHeight, 'controlHeight', controlHeight)
    .having((m) => m.controlRadius, 'controlRadius', controlRadius)
    .having((m) => m.iconButtonSize, 'iconButtonSize', iconButtonSize)
    .having((m) => m.circularAvatars, 'circularAvatars', circularAvatars);
