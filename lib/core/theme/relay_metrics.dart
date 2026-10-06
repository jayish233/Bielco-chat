import 'package:flutter/material.dart';

/// Platform-specific control sizing (web / iOS / Android).
@immutable
class RelayMetrics extends ThemeExtension<RelayMetrics> {
  const RelayMetrics({
    required this.controlHeight,
    required this.controlRadius,
    required this.iconButtonSize,
    required this.circularAvatars,
  });

  /// Web wins over [platform]; iOS and Android get their own metrics; any
  /// other platform (desktop, Fuchsia) uses the web metrics.
  factory RelayMetrics.forPlatform(
    TargetPlatform platform, {
    required bool isWeb,
  }) {
    if (isWeb) return _web;
    switch (platform) {
      case TargetPlatform.iOS:
        return _ios;
      case TargetPlatform.android:
        return _android;
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
        return _web;
    }
  }

  static const RelayMetrics _web = RelayMetrics(
    controlHeight: 48,
    controlRadius: 12,
    iconButtonSize: 40,
    circularAvatars: false,
  );
  static const RelayMetrics _ios = RelayMetrics(
    controlHeight: 54,
    controlRadius: 14,
    iconButtonSize: 44,
    circularAvatars: false,
  );
  static const RelayMetrics _android = RelayMetrics(
    controlHeight: 56,
    controlRadius: 999,
    iconButtonSize: 48,
    circularAvatars: true,
  );

  final double controlHeight;
  final double controlRadius;
  final double iconButtonSize;
  final bool circularAvatars;

  @override
  RelayMetrics copyWith({
    double? controlHeight,
    double? controlRadius,
    double? iconButtonSize,
    bool? circularAvatars,
  }) => RelayMetrics(
    controlHeight: controlHeight ?? this.controlHeight,
    controlRadius: controlRadius ?? this.controlRadius,
    iconButtonSize: iconButtonSize ?? this.iconButtonSize,
    circularAvatars: circularAvatars ?? this.circularAvatars,
  );

  @override
  RelayMetrics lerp(ThemeExtension<RelayMetrics>? other, double t) {
    if (other is! RelayMetrics) return this;
    double l(double a, double b) => a + (b - a) * t;
    return RelayMetrics(
      controlHeight: l(controlHeight, other.controlHeight),
      controlRadius: l(controlRadius, other.controlRadius),
      iconButtonSize: l(iconButtonSize, other.iconButtonSize),
      circularAvatars: t < 0.5 ? circularAvatars : other.circularAvatars,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is RelayMetrics &&
      other.controlHeight == controlHeight &&
      other.controlRadius == controlRadius &&
      other.iconButtonSize == iconButtonSize &&
      other.circularAvatars == circularAvatars;

  @override
  int get hashCode => Object.hash(
    controlHeight,
    controlRadius,
    iconButtonSize,
    circularAvatars,
  );
}
