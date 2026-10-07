import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/format.dart';
import '../../../core/providers.dart';
import '../../../core/router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/ui/relay_avatar.dart';
import '../../../core/ui/relay_button.dart';
import '../../../core/ui/skeleton.dart';
import '../../chat/domain/message.dart';
import '../domain/conversation.dart';
import 'conversation_list_controller.dart';

enum _Filter { all, unread, groups, direct }

/// The list of conversations, with search and filter chips.
class ChatListPane extends ConsumerStatefulWidget {
  const ChatListPane({super.key, this.selectedId});

  /// Highlighted row (wide layout).
  final String? selectedId;

  @override
  ConsumerState<ChatListPane> createState() => _ChatListPaneState();
}

class _ChatListPaneState extends ConsumerState<ChatListPane> {
  final _search = TextEditingController();
  _Filter _filter = _Filter.all;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<ConversationSummary> _apply(List<ConversationSummary> all) {
    final q = _search.text.trim().toLowerCase();
    return [
      for (final c in all)
        if ((q.isEmpty ||
                c.title.toLowerCase().contains(q) ||
                (c.otherUser?.username.contains(q) ?? false)) &&
            switch (_filter) {
              _Filter.all => true,
              _Filter.unread => c.unreadCount > 0,
              _Filter.groups => c.isGroup,
              _Filter.direct => !c.isGroup,
            })
          c,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final list = ref.watch(conversationListProvider);
    final profile = ref.watch(myProfileProvider).asData?.value;
    final myId = ref.watch(myUserIdProvider) ?? '';
    final unread = ref.watch(totalUnreadProvider);
    final p = context.palette;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Chats'),
        actions: [
          IconButton(
            tooltip: 'New chat',
            icon: const Icon(Icons.edit_square),
            onPressed: () => context.push(Routes.newChat),
          ),
          IconButton(
            tooltip: 'Your profile',
            onPressed: () => context.push(Routes.profile),
            icon: RelayAvatar(
              name: profile?.displayName ?? '',
              seed: profile?.id ?? myId,
              imageUrl: profile?.avatarUrl,
              size: 32,
            ),
          ),
          const SizedBox(width: RelaySpace.s2),
        ],
      ),
      body: Column(
        children: [
          const OfflineBanner(),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              RelaySpace.s4,
              RelaySpace.s3,
              RelaySpace.s4,
              RelaySpace.s2,
            ),
            child: SearchField(
              controller: _search,
              hint: 'Search chats',
              onChanged: (_) => setState(() {}),
            ),
          ),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: RelaySpace.s4),
              children: [
                for (final f in _Filter.values)
                  Padding(
                    padding: const EdgeInsets.only(right: RelaySpace.s2),
                    child: ChoiceChip(
                      label: Text(switch (f) {
                        _Filter.all => 'All',
                        _Filter.unread =>
                          unread > 0 ? 'Unread · $unread' : 'Unread',
                        _Filter.groups => 'Groups',
                        _Filter.direct => 'Direct',
                      }),
                      selected: _filter == f,
                      onSelected: (_) => setState(() => _filter = f),
                      labelStyle: TextStyle(
                        color: _filter == f ? p.onInk : p.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: list.when(
              loading: () => const _ListSkeleton(),
              error: (e, _) => _ListError(
                onRetry: () => ref.invalidate(conversationListProvider),
              ),
              data: (all) {
                if (all.isEmpty) return const _EmptyList();
                final shown = _apply(all);
                if (shown.isEmpty) {
                  return Center(
                    child: Text(
                      'No chats match.',
                      style: Theme.of(context).textTheme.bodyMedium
                          ?.copyWith(color: p.textMuted),
                    ),
                  );
                }
                return RefreshIndicator(
                  onRefresh: () =>
                      ref.read(conversationListProvider.notifier).refresh(),
                  child: ListView.builder(
                    itemCount: shown.length,
                    itemBuilder: (_, i) => ConversationTile(
                      conversation: shown[i],
                      myId: myId,
                      selected: shown[i].id == widget.selectedId,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class ConversationTile extends ConsumerWidget {
  const ConversationTile({
    super.key,
    required this.conversation,
    required this.myId,
    this.selected = false,
  });

  final ConversationSummary conversation;
  final String myId;
  final bool selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = conversation;
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    final unread = c.unreadCount > 0;
    final other = c.otherUser;
    final online = other == null
        ? null
        : ref.watch(onlineUsersProvider).asData?.value.contains(other.id);
    final avatar = c.isGroup
        ? GroupAvatar(name: c.title, size: 52, highlighted: unread)
        : RelayAvatar(
            name: c.title,
            seed: c.avatarSeed,
            imageUrl: other?.avatarUrl,
            size: 52,
            online: online == true ? true : null,
          );
    return Material(
      color: selected ? p.fillMuted : Colors.transparent,
      child: InkWell(
        onTap: () => context.go(Routes.chat(c.id)),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: RelaySpace.s4,
            vertical: RelaySpace.s3,
          ),
          child: Row(
            children: [
              avatar,
              const SizedBox(width: RelaySpace.s3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            c.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: text.bodyLarge?.copyWith(
                              fontWeight: unread
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(width: RelaySpace.s2),
                        Text(
                          listTime(c.sortTime),
                          style: text.bodySmall?.copyWith(
                            color: unread ? p.accent : p.textSubtle,
                            fontWeight: unread ? FontWeight.w500 : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Expanded(
                          child: _Preview(conversation: c, myId: myId),
                        ),
                        if (unread) ...[
                          const SizedBox(width: RelaySpace.s2),
                          UnreadBadge(count: c.unreadCount),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "You: …", "Maya: …", "📷 Photo", "Message deleted", or a hint when empty.
String previewText(ConversationSummary c, String myId) {
  final m = c.lastMessage;
  if (m == null) {
    return c.isGroup ? 'Group created. Say hi 👋' : 'Say hi 👋';
  }
  final String content;
  if (m.deleted) {
    content = 'Message deleted';
  } else if ((m.body ?? '').isNotEmpty) {
    content = m.body!.replaceAll('\n', ' ');
  } else {
    content = switch (m.attachmentKind) {
      AttachmentKind.image => '📷 Photo',
      AttachmentKind.audio => '🎤 Voice note',
      AttachmentKind.file => '📎 File',
      null => '',
    };
  }
  if (m.senderId == myId) return 'You: $content';
  if (c.isGroup && m.senderName != null) {
    return '${m.senderName!.split(' ').first}: $content';
  }
  return content;
}

class _Preview extends StatelessWidget {
  const _Preview({required this.conversation, required this.myId});

  final ConversationSummary conversation;
  final String myId;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final unread = conversation.unreadCount > 0;
    return Text(
      previewText(conversation, myId),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
        color: unread ? p.textSecondary : p.textSubtle,
        fontStyle: conversation.lastMessage?.deleted == true
            ? FontStyle.italic
            : null,
      ),
    );
  }
}

class _EmptyList extends StatelessWidget {
  const _EmptyList();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(RelaySpace.s6),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'No conversations yet',
                style: text.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: RelaySpace.s2),
              Text(
                'Chats with your group will show up here.',
                style: text.bodyMedium?.copyWith(
                  color: context.palette.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: RelaySpace.s5),
              RelayButton(
                label: 'Start a chat',
                onPressed: () => context.push(Routes.newChat),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ListError extends StatelessWidget {
  const _ListError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(RelaySpace.s6),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Couldn’t load your chats.',
                style: Theme.of(context).textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: RelaySpace.s4),
              RelayButton(
                label: 'Try again',
                variant: RelayButtonVariant.secondary,
                onPressed: onRetry,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ListSkeleton extends StatelessWidget {
  const _ListSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: const ValueKey('chat-list-skeleton'),
      physics: const NeverScrollableScrollPhysics(),
      children: [
        for (var i = 0; i < 6; i++)
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: RelaySpace.s4,
              vertical: RelaySpace.s3,
            ),
            child: Row(
              children: [
                const SkeletonBlock(width: 52, height: 52),
                const SizedBox(width: RelaySpace.s3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SkeletonBlock(width: 120.0 + (i % 3) * 30, height: 14),
                      const SizedBox(height: RelaySpace.s2),
                      const SkeletonBlock(height: 12),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Search input used by lists (chats, people).
class SearchField extends StatelessWidget {
  const SearchField({
    super.key,
    required this.controller,
    required this.hint,
    this.onChanged,
    this.autofocus = false,
  });

  final TextEditingController controller;
  final String hint;
  final ValueChanged<String>? onChanged;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final radius = BorderRadius.circular(RelayRadius.lg);
    return TextField(
      controller: controller,
      onChanged: onChanged,
      autofocus: autofocus,
      textInputAction: TextInputAction.search,
      style: Theme.of(context).textTheme.bodyLarge,
      decoration: InputDecoration(
        isDense: true,
        hintText: hint,
        hintStyle: TextStyle(color: p.placeholder),
        prefixIcon: Icon(Icons.search, color: p.textMuted, size: 20),
        filled: true,
        fillColor: p.fillMuted,
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
        border: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: p.accent, width: 2),
        ),
      ),
    );
  }
}

/// Shown while the realtime connection is down.
class OfflineBanner extends ConsumerWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connected = ref.watch(connectionProvider).asData?.value ?? true;
    if (connected) return const SizedBox.shrink();
    final p = context.palette;
    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        color: p.fillMuted,
        padding: const EdgeInsets.symmetric(
          horizontal: RelaySpace.s4,
          vertical: RelaySpace.s2,
        ),
        child: Row(
          children: [
            Icon(Icons.cloud_off, size: 16, color: p.textSecondary),
            const SizedBox(width: RelaySpace.s2),
            Expanded(
              child: Text(
                'You’re offline. Reconnecting…',
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: p.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
