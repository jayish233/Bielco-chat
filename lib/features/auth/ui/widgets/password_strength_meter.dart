import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/tokens.dart';

/// Four-segment password strength bar; [score] is 0–4.
class PasswordStrengthMeter extends StatelessWidget {
  const PasswordStrengthMeter({super.key, required this.score});

  final int score;

  static const _labels = ['none', 'weak', 'fair', 'good', 'strong'];

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final clamped = score.clamp(0, 4);
    return Semantics(
      label: 'Password strength ${_labels[clamped]}',
      excludeSemantics: true,
      child: Row(
        children: [
          for (var i = 0; i < 4; i++) ...[
            if (i > 0) const SizedBox(width: RelaySpace.s1),
            Expanded(
              child: Container(
                height: 4,
                decoration: BoxDecoration(
                  color: i < clamped ? p.ink : p.fillMuted,
                  borderRadius: BorderRadius.circular(RelayRadius.pill),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
