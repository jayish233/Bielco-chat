import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/app_failure.dart';
import '../../../core/providers.dart';
import '../../../core/router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/ui/relay_avatar.dart';
import '../../../core/ui/relay_button.dart';
import '../domain/conversation.dart';
import 'conversation_list_controller.dart';

final invitePreviewProvider = FutureProvider.autoDispose
    .family<InvitePreview?, String>(
      (ref, token) =>
          ref.watch(conversationRepositoryProvider).getInvite(token),
    );

/// Landing page for an invite link: group name, member count, "Join".
class JoinInviteScreen extends ConsumerStatefulWidget {
  const JoinInviteScreen({super.key, required this.token});

  final String token;

  @override
  ConsumerState<JoinInviteScreen> createState() => _JoinInviteScreenState();
}

class _JoinInviteScreenState extends ConsumerState<JoinInviteScreen> {
  bool _joining = false;

  Future<void> _join() async {
    setState(() => _joining = true);
    try {
      final id = await ref
          .read(conversationRepositoryProvider)
          .joinViaInvite(widget.token);
      await ref.read(conversationListProvider.notifier).refresh();
      if (mounted) context.go(Routes.chat(id));
    } catch (e) {
      if (!mounted) return;
      setState(() => _joining = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(mapAppError(e).message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final preview = ref.watch(invitePreviewProvider(widget.token));
    final text = Theme.of(context).textTheme;
    final p = context.palette;

    Widget body(List<Widget> children) => Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(RelaySpace.s6),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Column(mainAxisSize: MainAxisSize.min, children: children),
        ),
      ),
    );

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Close',
          icon: const Icon(Icons.close),
          onPressed: () => context.go(Routes.home),
        ),
        title: const Text('Invite'),
      ),
      body: preview.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => body([
          Text(mapAppError(e).message, textAlign: TextAlign.center),
          const SizedBox(height: RelaySpace.s4),
          RelayButton(
            label: 'Try again',
            variant: RelayButtonVariant.secondary,
            onPressed: () =>
                ref.invalidate(invitePreviewProvider(widget.token)),
          ),
        ]),
        data: (invite) {
          if (invite == null) {
            return body([
              Text('This invite link doesn’t work', style: text.titleMedium),
              const SizedBox(height: RelaySpace.s2),
              Text(
                'It may have been reset by a group admin. Ask them for a new one.',
                textAlign: TextAlign.center,
                style: text.bodyMedium?.copyWith(color: p.textSecondary),
              ),
              const SizedBox(height: RelaySpace.s5),
              RelayButton(
                label: 'Go to chats',
                variant: RelayButtonVariant.secondary,
                onPressed: () => context.go(Routes.home),
              ),
            ]);
          }
          return body([
            GroupAvatar(name: invite.name, size: 72, highlighted: true),
            const SizedBox(height: RelaySpace.s4),
            Text(
              invite.name,
              textAlign: TextAlign.center,
              style: text.headlineLarge?.copyWith(fontSize: 26),
            ),
            const SizedBox(height: RelaySpace.s1),
            Text(
              '${invite.memberCount} member${invite.memberCount == 1 ? '' : 's'}',
              style: text.bodySmall,
            ),
            const SizedBox(height: RelaySpace.s6),
            if (invite.isMember)
              RelayButton(
                label: 'Open group',
                onPressed: () => context.go(Routes.chat(invite.conversationId)),
              )
            else
              RelayButton(
                label: 'Join group',
                loading: _joining,
                onPressed: _join,
              ),
          ]);
        },
      ),
    );
  }
}
