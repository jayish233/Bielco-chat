import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants.dart';
import '../../../core/providers.dart';
import '../../../core/router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/ui/relay_avatar.dart';

/// Milestone 2 replaces the body with the chat list.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(myProfileProvider).asData?.value;
    final name = profile?.displayName ?? '';
    final seed =
        profile?.id ?? ref.watch(authRepositoryProvider).currentUserId ?? '';
    final palette = context.palette;
    return Scaffold(
      appBar: AppBar(
        title: const Text(appName),
        actions: [
          IconButton(
            tooltip: 'Your profile',
            onPressed: () => context.push(Routes.profile),
            icon: RelayAvatar(name: name, seed: seed, size: 32),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'No conversations yet',
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Chats with your group will show up here.',
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: palette.textSecondary),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
