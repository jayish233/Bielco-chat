import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/app_failure.dart';
import '../../../core/env.dart';
import '../../../core/providers.dart';
import '../../../core/router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/ui/relay_avatar.dart';
import '../../../core/ui/relay_button.dart';
import '../../../core/ui/relay_text_field.dart';
import '../../people/ui/people_list.dart' show PersonTile;
import '../../people/ui/people_screen.dart' show openDm;
import '../domain/conversation.dart';
import 'conversation_list_controller.dart';
import 'new_chat_screen.dart' show AddMembersScreen;

final groupMembersProvider = FutureProvider.autoDispose
    .family<List<ConversationMember>, String>(
      (ref, id) => ref.watch(conversationRepositoryProvider).fetchMembers(id),
    );

class GroupInfoScreen extends ConsumerStatefulWidget {
  const GroupInfoScreen({super.key, required this.conversationId});

  final String conversationId;

  @override
  ConsumerState<GroupInfoScreen> createState() => _GroupInfoScreenState();
}

class _GroupInfoScreenState extends ConsumerState<GroupInfoScreen> {
  String? _inviteLink;
  bool _inviteBusy = false;

  String get _id => widget.conversationId;

  void _toast(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }

  Future<void> _run(Future<void> Function() action, {String? done}) async {
    try {
      await action();
      ref.invalidate(groupMembersProvider(_id));
      await ref.read(conversationListProvider.notifier).refresh();
      if (done != null) _toast(done);
    } catch (e) {
      _toast(mapAppError(e).message);
    }
  }

  Future<void> _rename(String current) async {
    final controller = TextEditingController(text: current);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename group'),
        content: RelayTextField(label: 'Group name', controller: controller),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.isEmpty || name == current) return;
    await _run(
      () => ref.read(conversationRepositoryProvider).renameGroup(_id, name),
    );
  }

  Future<void> _createLink({bool reset = false}) async {
    setState(() => _inviteBusy = true);
    try {
      final repo = ref.read(conversationRepositoryProvider);
      if (reset) await repo.revokeInvites(_id);
      final token = await repo.createInvite(_id);
      if (mounted) setState(() => _inviteLink = AppLinks.invite(token));
      if (reset) _toast('Old link reset. Share the new one.');
    } catch (e) {
      _toast(mapAppError(e).message);
    } finally {
      if (mounted) setState(() => _inviteBusy = false);
    }
  }

  Future<void> _addPeople(List<ConversationMember> members) async {
    final added = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => AddMembersScreen(
          conversationId: _id,
          existing: {for (final m in members) m.userId},
        ),
      ),
    );
    if (added == true) {
      ref.invalidate(groupMembersProvider(_id));
      _toast('Added to the group');
    }
  }

  Future<void> _memberActions(ConversationMember m, bool iAmAdmin) async {
    final repo = ref.read(conversationRepositoryProvider);
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.chat_bubble_outline),
              title: Text('Message ${m.profile.displayName}'),
              onTap: () => Navigator.pop(context, 'message'),
            ),
            if (iAmAdmin)
              ListTile(
                leading: const Icon(Icons.shield_outlined),
                title: Text(m.isAdmin ? 'Remove as admin' : 'Make admin'),
                onTap: () => Navigator.pop(context, 'role'),
              ),
            if (iAmAdmin)
              ListTile(
                leading: Icon(
                  Icons.person_remove_outlined,
                  color: context.palette.dangerText,
                ),
                title: Text(
                  'Remove from group',
                  style: TextStyle(color: context.palette.dangerText),
                ),
                onTap: () => Navigator.pop(context, 'remove'),
              ),
            const SizedBox(height: RelaySpace.s2),
          ],
        ),
      ),
    );
    if (!mounted) return;
    switch (choice) {
      case 'message':
        await openDm(context, ref, m.profile);
      case 'role':
        await _run(
          () => repo.setRole(
            _id,
            m.userId,
            m.isAdmin ? MemberRole.member : MemberRole.admin,
          ),
        );
      case 'remove':
        await _run(
          () => repo.removeMember(_id, m.userId),
          done: '${m.profile.displayName} was removed',
        );
    }
  }

  Future<void> _leave(String myId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave group?'),
        content: const Text(
          'You’ll stop getting messages from this group. '
          'Someone will need to add you again to rejoin.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: context.palette.dangerText,
            ),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(conversationRepositoryProvider).removeMember(_id, myId);
      await ref.read(conversationListProvider.notifier).refresh();
      if (mounted) context.go(Routes.home);
    } catch (e) {
      _toast(mapAppError(e).message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final members = ref.watch(groupMembersProvider(_id));
    final summary = ref.watch(conversationProvider(_id));
    final myId = ref.watch(myUserIdProvider) ?? '';
    final online = ref.watch(onlineUsersProvider).asData?.value ?? const {};
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    final name = summary?.name ?? 'Group';

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go(Routes.chat(_id)),
        ),
        title: const Text('Group info'),
      ),
      body: members.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(RelaySpace.s6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(mapAppError(e).message, textAlign: TextAlign.center),
                const SizedBox(height: RelaySpace.s4),
                RelayButton(
                  label: 'Try again',
                  variant: RelayButtonVariant.secondary,
                  onPressed: () => ref.invalidate(groupMembersProvider(_id)),
                ),
              ],
            ),
          ),
        ),
        data: (list) {
          final me = list.where((m) => m.userId == myId).firstOrNull;
          final iAmAdmin = me?.isAdmin ?? false;
          final sorted = [...list]
            ..sort((a, b) {
              if (a.isAdmin != b.isAdmin) return a.isAdmin ? -1 : 1;
              return a.profile.displayName.toLowerCase().compareTo(
                b.profile.displayName.toLowerCase(),
              );
            });
          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: ListView(
                padding: const EdgeInsets.only(bottom: RelaySpace.s8),
                children: [
                  const SizedBox(height: RelaySpace.s6),
                  Center(
                    child: GroupAvatar(name: name, size: 72, highlighted: true),
                  ),
                  const SizedBox(height: RelaySpace.s3),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(
                          name,
                          textAlign: TextAlign.center,
                          style: text.headlineLarge?.copyWith(fontSize: 24),
                        ),
                      ),
                      if (iAmAdmin)
                        IconButton(
                          tooltip: 'Rename group',
                          icon: const Icon(Icons.edit_outlined, size: 20),
                          onPressed: () => _rename(name),
                        ),
                    ],
                  ),
                  Text(
                    '${list.length} member${list.length == 1 ? '' : 's'}',
                    textAlign: TextAlign.center,
                    style: text.bodySmall,
                  ),
                  if (iAmAdmin) ...[
                    const SizedBox(height: RelaySpace.s6),
                    _InviteCard(
                      link: _inviteLink,
                      busy: _inviteBusy,
                      onCreate: () => _createLink(),
                      onReset: () => _createLink(reset: true),
                      onCopy: () async {
                        await Clipboard.setData(
                          ClipboardData(text: _inviteLink!),
                        );
                        _toast('Invite link copied');
                      },
                    ),
                  ],
                  const SizedBox(height: RelaySpace.s6),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: RelaySpace.s4,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text('MEMBERS', style: text.labelSmall),
                        ),
                        if (iAmAdmin)
                          TextButton.icon(
                            onPressed: () => _addPeople(list),
                            icon: const Icon(Icons.person_add_alt, size: 18),
                            label: const Text('Add people'),
                          ),
                      ],
                    ),
                  ),
                  for (final m in sorted)
                    PersonTile(
                      person: m.profile,
                      online: online.contains(m.userId),
                      subtitle: m.userId == myId
                          ? 'You · @${m.profile.username}'
                          : '@${m.profile.username}',
                      onTap: m.userId == myId
                          ? null
                          : () => _memberActions(m, iAmAdmin),
                      trailing: RolePill(role: m.role),
                    ),
                  const SizedBox(height: RelaySpace.s6),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: RelaySpace.s4,
                    ),
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: p.dangerText,
                        side: BorderSide(color: p.border),
                        minimumSize: const Size.fromHeight(48),
                      ),
                      onPressed: () => _leave(myId),
                      icon: const Icon(Icons.logout),
                      label: const Text('Leave group'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Admin: solid ink. Member: muted fill.
class RolePill extends StatelessWidget {
  const RolePill({super.key, required this.role});

  final MemberRole role;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final admin = role == MemberRole.admin;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: admin ? Colors.transparent : p.fillMuted,
        border: admin ? Border.all(color: p.ink) : null,
        borderRadius: BorderRadius.circular(RelayRadius.pill),
      ),
      child: Text(
        admin ? 'Admin' : 'Member',
        style: TextStyle(
          fontFamily: RelayFonts.sans,
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: admin ? p.ink : p.textSecondary,
        ),
      ),
    );
  }
}

/// Black "Invite with a link" card.
class _InviteCard extends StatelessWidget {
  const _InviteCard({
    required this.link,
    required this.busy,
    required this.onCreate,
    required this.onReset,
    required this.onCopy,
  });

  final String? link;
  final bool busy;
  final VoidCallback onCreate;
  final VoidCallback onReset;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    const fg = RelayColors.surface;
    final muted = fg.withValues(alpha: 0.7);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: RelaySpace.s4),
      padding: const EdgeInsets.all(RelaySpace.s5),
      decoration: BoxDecoration(
        color: RelayColors.ink,
        borderRadius: BorderRadius.circular(RelayRadius.bubble),
        border: Border.all(color: context.palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Invite with a link',
            style: TextStyle(
              fontFamily: RelayFonts.sans,
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: fg,
            ),
          ),
          const SizedBox(height: RelaySpace.s1),
          Text(
            'Anyone with the link can join after signing in.',
            style: TextStyle(
              fontFamily: RelayFonts.sans,
              fontSize: 14,
              color: muted,
            ),
          ),
          const SizedBox(height: RelaySpace.s4),
          if (link == null)
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: fg,
                foregroundColor: RelayColors.ink,
                minimumSize: const Size.fromHeight(44),
              ),
              onPressed: busy ? null : onCreate,
              child: Text(busy ? 'Creating…' : 'Create invite link'),
            )
          else ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(RelaySpace.s3),
              decoration: BoxDecoration(
                color: RelayColors.ink2,
                borderRadius: BorderRadius.circular(RelayRadius.lg),
              ),
              child: SelectableText(
                link!,
                style: const TextStyle(
                  fontFamily: RelayFonts.mono,
                  fontSize: 13,
                  color: fg,
                ),
              ),
            ),
            const SizedBox(height: RelaySpace.s3),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: fg,
                      foregroundColor: RelayColors.ink,
                      minimumSize: const Size.fromHeight(44),
                    ),
                    onPressed: onCopy,
                    icon: const Icon(Icons.copy, size: 18),
                    label: const Text('Copy link'),
                  ),
                ),
                const SizedBox(width: RelaySpace.s2),
                TextButton(
                  style: TextButton.styleFrom(foregroundColor: fg),
                  onPressed: busy ? null : onReset,
                  child: const Text('Reset link'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
