import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

enum RelayButtonVariant { primary, secondary }

/// Full-width button sized and shaped by the platform [RelayMetrics].
class RelayButton extends StatelessWidget {
  const RelayButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = RelayButtonVariant.primary,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final RelayButtonVariant variant;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final m = context.metrics;
    final primary = variant == RelayButtonVariant.primary;
    final enabled = onPressed != null && !loading;
    final fg = primary ? p.onInk : p.ink;
    final radius = BorderRadius.circular(m.controlRadius);
    // Android outlines use the stronger placeholder grey.
    final borderColor = m.circularAvatars ? p.placeholder : p.border;

    final content = loading
        ? SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: fg),
          )
        : Text(
            label,
            style: Theme.of(context).textTheme.bodyLarge
                ?.copyWith(color: fg, fontWeight: FontWeight.w600),
          );

    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      onTap: enabled ? onPressed : null,
      child: ExcludeSemantics(
        child: Opacity(
          opacity: onPressed == null ? 0.5 : 1,
          child: SizedBox(
            width: double.infinity,
            height: m.controlHeight,
            child: Material(
              color: primary ? p.ink : p.surface,
              shape: RoundedRectangleBorder(
                borderRadius: radius,
                side: primary
                    ? BorderSide.none
                    : BorderSide(color: borderColor),
              ),
              child: InkWell(
                borderRadius: radius,
                onTap: enabled ? onPressed : null,
                child: Center(child: content),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
