import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/app_failure.dart';
import '../../../core/format.dart';
import '../../../core/providers.dart';
import '../../../core/router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/ui/relay_avatar.dart';
import '../../../core/ui/relay_button.dart';
import '../../../core/ui/skeleton.dart';
import '../../conversations/domain/conversation.dart';
import '../../conversations/ui/chat_list_pane.dart' show OfflineBanner;
import '../../conversations/ui/conversation_list_controller.dart';
import '../domain/message.dart';
import 'chat_controller.dart';
import 'widgets/composer.dart';
import 'widgets/message_actions.dart';
import 'widgets/message_bubble.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({
    super.key,
    required this.conversationId,
    this.embedded = false,
  });

  final String conversationId;

  /// In the wide split view: no back button.
  final bool embedded;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _scroll = ScrollController();
  ReplyPreview? _replyTo;
  Message? _editing;
  bool _showJump = false;
  bool _askedForList = false;

  String get _id => widget.conversationId;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(ChatScreen old) {
    super.didUpdateWidget(old);
    if (old.conversationId != widget.conversationId) {
      _replyTo = null;
      _editing = null;
      _askedForList = false;
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    final pos = _scroll.position;
    // reverse: true → maxScrollExtent is the oldest end.
    if (pos.pixels > pos.maxScrollExtent - 400) {
      ref.read(chatControllerProvider(_id).notifier).loadMore();
    }
    final jump = pos.pixels > 600;
    if (jump != _showJump) setState(() => _showJump = jump);
  }

  void _toast(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _sendText(String text) async {
    final chat = ref.read(chatControllerProvider(_id).notifier);
    final editing = _editing;
    if (editing != null) {
      setState(() => _editing = null);
      try {
        await chat.edit(editing.id, text);
      } catch (e) {
        _toast(mapAppError(e).message);
      }
      return;
    }
    final reply = _replyTo;
    setState(() => _replyTo = null);
    await chat.send(text: text, replyTo: reply);
    _toBottom();
  }

  Future<void> _sendAttachment(OutgoingAttachment a) async {
    final reply = _replyTo;
    setState(() => _replyTo = null);
    await ref
        .read(chatControllerProvider(_id).notifier)
        .send(attachment: a, replyTo: reply);
    _toBottom();
  }

  void _toBottom() {
    if (_scroll.hasClients) {
      _scroll.animateTo(
        0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _actions(Message m, bool mine) async {
    final chat = ref.read(chatControllerProvider(_id).notifier);
    final sent = m.sendState == SendState.sent;
    final live = sent && !m.isDeleted;
    final result = await showMessageActions(
      context,
      canReact: live,
      canReply: live,
      canCopy: !m.isDeleted && (m.body ?? '').isNotEmpty,
      canEdit: live && mine && (m.body ?? '').isNotEmpty,
      canDelete: mine && !m.isDeleted,
      canRetry: m.sendState == SendState.failed,
    );
    if (result == null || !mounted) return;
    if (result.emoji case final e?) {
      await chat.toggleReaction(m.id, e);
      return;
    }
    switch (result.action) {
      case MessageAction.reply:
        setState(() {
          _editing = null;
          _replyTo = ReplyPreview.of(m);
        });
      case MessageAction.copy:
        await Clipboard.setData(ClipboardData(text: m.body ?? ''));
        _toast('Copied');
      case MessageAction.edit:
        setState(() {
          _replyTo = null;
          _editing = m;
        });
      case MessageAction.delete:
        if (!sent) {
          chat.discard(m.id);
          return;
        }
        if (!await confirmDelete(context)) return;
        try {
          await chat.delete(m.id);
        } catch (e) {
          _toast(mapAppError(e).message);
        }
      case MessageAction.retry:
        await chat.retry(m.id);
      case null:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(chatControllerProvider(_id));
    final summary = ref.watch(conversationProvider(_id));
    final myId = ref.watch(myUserIdProvider) ?? '';
    final online = ref.watch(onlineUsersProvider).asData?.value ?? const {};

    if (summary == null && !_askedForList && !state.loading) {
      // Just created / joined: the list hasn't caught up yet.
      _askedForList = true;
      Future.microtask(
        () => ref.read(conversationListProvider.notifier).refresh(),
      );
    }

    final isGroup =
        summary?.isGroup ?? (state.members.length > 2 || state.members.isEmpty);
    final other = [
      for (final m in state.members)
        if (m.userId != myId) m,
    ];
    final dmPeer = !isGroup && other.isNotEmpty ? other.first.profile : null;
    final title = summary?.title ?? dmPeer?.displayName ?? 'Chat';

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: widget.embedded
            ? null
            : IconButton(
                tooltip: 'Back',
                icon: const Icon(Icons.arrow_back),
                onPressed: () =>
                    context.canPop() ? context.pop() : context.go(Routes.home),
              ),
        titleSpacing: widget.embedded ? RelaySpace.s4 : 0,
        title: InkWell(
          onTap: isGroup ? () => context.push(Routes.groupInfo(_id)) : null,
          borderRadius: BorderRadius.circular(RelayRadius.md),
          child: Row(
            children: [
              if (isGroup)
                GroupAvatar(name: title, size: 36)
              else
                RelayAvatar(
                  name: title,
                  seed: dmPeer?.id ?? summary?.avatarSeed ?? _id,
                  imageUrl: dmPeer?.avatarUrl ?? summary?.otherUser?.avatarUrl,
                  size: 36,
                  online: dmPeer != null && online.contains(dmPeer.id)
                      ? true
                      : null,
                ),
              const SizedBox(width: RelaySpace.s3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
                    _Subtitle(
                      state: state,
                      myId: myId,
                      isGroup: isGroup,
                      online: online,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          if (isGroup)
            IconButton(
              tooltip: 'Group info',
              icon: const Icon(Icons.info_outline),
              onPressed: () => context.push(Routes.groupInfo(_id)),
            ),
          const SizedBox(width: RelaySpace.s2),
        ],
      ),
      body: Column(
        children: [
          const OfflineBanner(),
          Expanded(child: _body(state, summary, myId, isGroup, title)),
          if (state.removed)
            _RemovedBanner(isGroup: isGroup)
          else if (!state.loading && state.error == null)
            Composer(
              onSendText: _sendText,
              onSendAttachment: _sendAttachment,
              onTyping: () =>
                  ref.read(chatControllerProvider(_id).notifier).typing(),
              replyTo: _replyTo,
              onCancelReply: () => setState(() => _replyTo = null),
              editing: _editing,
              onCancelEdit: () => setState(() => _editing = null),
            ),
        ],
      ),
    );
  }

  Widget _body(
    ChatState state,
    ConversationSummary? summary,
    String myId,
    bool isGroup,
    String title,
  ) {
    if (state.loading) return const _BubbleSkeleton();
    if (state.error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(RelaySpace.s6),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  mapAppError(state.error!).message,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: RelaySpace.s4),
                RelayButton(
                  label: 'Try again',
                  variant: RelayButtonVariant.secondary,
                  onPressed: () => ref
                      .read(chatControllerProvider(_id).notifier)
                      .retryLoad(),
                ),
              ],
            ),
          ),
        ),
      );
    }
    if (state.messages.isEmpty) {
      return _EmptyChat(
        isGroup: isGroup,
        title: title,
        canInvite: summary?.isAdmin ?? false,
        onInvite: () => context.push(Routes.groupInfo(_id)),
      );
    }

    final items = _buildItems(state, myId, isGroup);
    return Stack(
      children: [
        ListView.builder(
          controller: _scroll,
          reverse: true,
          padding: const EdgeInsets.only(bottom: RelaySpace.s3),
          itemCount: items.length,
          itemBuilder: (_, i) => items[i],
        ),
        if (_showJump)
          Positioned(
            right: RelaySpace.s4,
            bottom: RelaySpace.s4,
            child: IconButton.filled(
              tooltip: 'Jump to latest',
              style: IconButton.styleFrom(
                backgroundColor: context.palette.surface,
                foregroundColor: context.palette.ink,
                side: BorderSide(color: context.palette.border),
              ),
              onPressed: _toBottom,
              icon: const Icon(Icons.arrow_downward),
            ),
          ),
      ],
    );
  }

  /// Newest first (the list is reversed).
  List<Widget> _buildItems(ChatState state, String myId, bool isGroup) {
    final chat = ref.read(chatControllerProvider(_id).notifier);
    final msgs = state.messages;
    final others = [
      for (final m in state.members)
        if (m.userId != myId) m,
    ];

    List<ConversationMember> readersOf(Message m) => [
      for (final o in others)
        if (o.lastReadAt != null && !o.lastReadAt!.isBefore(m.createdAt)) o,
    ];

    String? lastMineId;
    for (var i = msgs.length - 1; i >= 0; i--) {
      final m = msgs[i];
      if (m.senderId == myId && m.sendState == SendState.sent && !m.isDeleted) {
        lastMineId = m.id;
        break;
      }
    }

    bool sameRun(Message a, Message b) =>
        a.senderId == b.senderId &&
        isSameDay(a.createdAt, b.createdAt) &&
        b.createdAt.difference(a.createdAt).abs() < const Duration(minutes: 5);

    final out = <Widget>[];
    if (state.typers.isNotEmpty) {
      out.add(
        const Padding(
          key: ValueKey('typing'),
          padding: EdgeInsets.fromLTRB(RelaySpace.s4, RelaySpace.s2, 0, 0),
          child: Align(alignment: Alignment.centerLeft, child: TypingDots()),
        ),
      );
    }
    for (var i = msgs.length - 1; i >= 0; i--) {
      final m = msgs[i];
      final older = i > 0 ? msgs[i - 1] : null;
      final newer = i < msgs.length - 1 ? msgs[i + 1] : null;
      final mine = m.senderId == myId;
      final first = older == null || !sameRun(older, m) || older.isDeleted;
      final last = newer == null || !sameRun(m, newer) || newer.isDeleted;

      ReadMark? mark;
      String? seen;
      if (mine) {
        if (m.sendState == SendState.sending) {
          mark = ReadMark.sending;
        } else if (m.sendState == SendState.sent) {
          final readers = readersOf(m);
          final all = others.isNotEmpty && readers.length == others.length;
          mark = (isGroup ? all : readers.isNotEmpty)
              ? ReadMark.read
              : ReadMark.sent;
          if (m.id == lastMineId && readers.isNotEmpty) {
            seen = !isGroup
                ? 'Seen'
                : all
                ? 'Seen by everyone'
                : 'Seen by ${readers.length}';
          }
        }
      }

      out.add(
        MessageRow(
          key: ValueKey(m.id),
          message: m,
          mine: mine,
          myId: myId,
          showSender: isGroup,
          firstInRun: first,
          lastInRun: last,
          reactions: state.reactions[m.id] ?? const [],
          readMark: mark,
          seenLabel: seen,
          onActions: () => _actions(m, mine),
          onRetry: () => chat.retry(m.id),
          onReaction: (e) => chat.toggleReaction(m.id, e),
        ),
      );
      if (m.id == state.firstUnreadId) {
        out.add(const NewMessagesDivider(key: ValueKey('new-divider')));
      }
      if (older == null || !isSameDay(older.createdAt, m.createdAt)) {
        out.add(
          DateDivider(
            key: ValueKey('day-${m.createdAt.toIso8601String()}'),
            day: m.createdAt,
          ),
        );
      }
    }
    if (state.loadingMore) {
      out.add(
        const Padding(
          key: ValueKey('loading-more'),
          padding: EdgeInsets.all(RelaySpace.s4),
          child: Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
      );
    }
    return out;
  }
}

class _Subtitle extends StatelessWidget {
  const _Subtitle({
    required this.state,
    required this.myId,
    required this.isGroup,
    required this.online,
  });

  final ChatState state;
  final String myId;
  final bool isGroup;
  final Set<String> online;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final style = Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 12);
    String firstName(String id) =>
        (state.member(id)?.profile.displayName ?? 'Someone').split(' ').first;

    final typers = state.typers.toList();
    if (typers.isNotEmpty) {
      final text = switch (typers.length) {
        1 => '${firstName(typers[0])} is typing…',
        2 => '${firstName(typers[0])} and ${firstName(typers[1])} are typing…',
        _ => '${typers.length} people are typing…',
      };
      return Text(text, style: style?.copyWith(color: p.accent));
    }
    final String text;
    if (isGroup) {
      final count = state.members.length;
      final on = state.members
          .where((m) => m.userId != myId && online.contains(m.userId))
          .length;
      text = count == 0
          ? ''
          : '$count member${count == 1 ? '' : 's'}${on > 0 ? ' · $on online' : ''}';
    } else {
      final peer = state.members.where((m) => m.userId != myId).firstOrNull;
      if (peer == null) {
        text = '';
      } else if (online.contains(peer.userId)) {
        text = 'Online';
      } else if (peer.profile.lastSeenAt != null) {
        text = lastSeen(peer.profile.lastSeenAt!);
      } else {
        text = '@${peer.profile.username}';
      }
    }
    if (text.isEmpty) return const SizedBox.shrink();
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: style,
    );
  }
}

class _EmptyChat extends StatelessWidget {
  const _EmptyChat({
    required this.isGroup,
    required this.title,
    required this.canInvite,
    required this.onInvite,
  });

  final bool isGroup;
  final String title;
  final bool canInvite;
  final VoidCallback onInvite;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(RelaySpace.s6),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Say hi 👋', style: text.titleMedium),
              const SizedBox(height: RelaySpace.s2),
              Text(
                isGroup
                    ? 'This is the start of $title.'
                    : 'This is the start of your chat with $title.',
                textAlign: TextAlign.center,
                style: text.bodyMedium?.copyWith(
                  color: context.palette.textSecondary,
                ),
              ),
              if (isGroup && canInvite) ...[
                const SizedBox(height: RelaySpace.s5),
                RelayButton(
                  label: 'Invite people',
                  variant: RelayButtonVariant.secondary,
                  onPressed: onInvite,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _RemovedBanner extends StatelessWidget {
  const _RemovedBanner({required this.isGroup});

  final bool isGroup;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return SafeArea(
      top: false,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(RelaySpace.s4),
        decoration: BoxDecoration(
          color: p.fillMuted,
          border: Border(top: BorderSide(color: p.hairline)),
        ),
        child: Text(
          isGroup
              ? 'You’re no longer a member of this group.'
              : 'You can’t send messages in this chat.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: p.textSecondary),
        ),
      ),
    );
  }
}

class _BubbleSkeleton extends StatelessWidget {
  const _BubbleSkeleton();

  @override
  Widget build(BuildContext context) {
    const widths = [180.0, 240.0, 140.0, 220.0, 160.0];
    return ListView(
      key: const ValueKey('chat-skeleton'),
      reverse: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(RelaySpace.s4),
      children: [
        for (var i = 0; i < widths.length; i++)
          Align(
            alignment: i.isEven ? Alignment.centerRight : Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(bottom: RelaySpace.s3),
              child: SkeletonBlock(
                width: widths[i],
                height: 40,
                radius: RelayRadius.bubble,
              ),
            ),
          ),
      ],
    );
  }
}
