import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/tokens.dart';

class FormErrorBanner extends StatelessWidget {
  const FormErrorBanner({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: RelaySpace.s4,
          vertical: RelaySpace.s3,
        ),
        decoration: BoxDecoration(
          color: p.danger.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(RelayRadius.lg),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.error_outline, size: 18, color: p.dangerText),
            const SizedBox(width: RelaySpace.s2),
            Expanded(
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: p.dangerText),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
