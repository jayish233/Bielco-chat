import 'package:flutter/material.dart';

import '../../../core/constants.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/ui/relay_logo.dart';

const double authSplitBreakpoint = 900;

/// Split layout on wide windows (brand panel + form), form only below 900.
class AuthLayout extends StatelessWidget {
  const AuthLayout({super.key, required this.form});

  final Widget form;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= authSplitBreakpoint;
    final formColumn = SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: form,
          ),
        ),
      ),
    );
    if (!wide) return formColumn;
    return Row(
      children: [
        const Expanded(child: _BrandPanel()),
        Expanded(child: formColumn),
      ],
    );
  }
}

class _BrandPanel extends StatelessWidget {
  const _BrandPanel();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      key: const Key('brand-panel'),
      color: RelayColors.ink,
      padding: const EdgeInsets.symmetric(horizontal: 56, vertical: 48),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const RelayLogo(size: 32, inverted: true),
              const SizedBox(width: RelaySpace.s3),
              Text(
                appName,
                style: text.titleLarge?.copyWith(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: RelayColors.surface,
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            'Every conversation, in one calm place.',
            style: text.displayLarge?.copyWith(color: RelayColors.surface),
          ),
          const SizedBox(height: RelaySpace.s4),
          Text(
            'Groups and direct messages for your people — on the web, iOS and Android.',
            style: text.bodyLarge?.copyWith(
              fontSize: 18,
              color: RelayColors.darkTextMuted,
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }
}
