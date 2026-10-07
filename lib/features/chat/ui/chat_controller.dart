import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/providers.dart';
import '../../conversations/data/conversation_repository.dart';
import '../../conversations/domain/conversation.dart';
import '../../conversations/ui/conversation_list_controller.dart';
import '../data/message_repository.dart';
import '../data/presence_service.dart';
import '../domain/message.dart';

class ChatState {
  const ChatState({
    this.messages = const [],
    this.reactions = const {},
    this.members = const [],
    this.loading = true,
    this.error,
    this.loadingMore = false,
    this.hasMore = false,
    this.typers = const {},
    this.firstUnreadId,
    this.removed = false,
  });

  /// Oldest first.
  final List<Message> messages;

  /// By message id, in the order they were added.
  final Map<String, List<Reaction>> reactions;
  final List<ConversationMember> members;
  final bool loading;
  final Object? error;
  final bool loadingMore;
  final bool hasMore;

  /// Other people typing right now.
  final Set<String> typers;

  /// First message that was unread when the chat opened ("New" divider).
  final String? firstUnreadId;

  /// I was removed from (or left) this conversation while it was open.
  final bool removed;

  ConversationMember? member(String userId) {
    for (final m in members) {
      if (m.userId == userId) return m;
    }
    return null;
  }

  ChatState copyWith({
    List<Message>? messages,
    Map<String, List<Reaction>>? reactions,
    List<ConversationMember>? members,
    bool? loading,
    Object? error,
    bool clearError = false,
    bool? loadingMore,
    bool? hasMore,
    Set<String>? typers,
    String? firstUnreadId,
    bool? removed,
  }) => ChatState(
    messages: messages ?? this.messages,
    reactions: reactions ?? this.reactions,
    members: members ?? this.members,
    loading: loading ?? this.loading,
    error: clearError ? null : (error ?? this.error),
    loadingMore: loadingMore ?? this.loadingMore,
    hasMore: hasMore ?? this.hasMore,
    typers: typers ?? this.typers,
    firstUnreadId: firstUnreadId ?? this.firstUnreadId,
    removed: removed ?? this.removed,
  );
}

class ChatController extends Notifier<ChatState> {
  ChatController(this.conversationId);

  final String conversationId;

  late String _me;
  TypingSession? _typing;
  Timer? _readTimer;

  MessageRepository get _messages => ref.read(messageRepositoryProvider);
  ConversationRepository get _conversations =>
      ref.read(conversationRepositoryProvider);

  @override
  ChatState build() {
    _me = ref.watch(myUserIdProvider) ?? '';
    final events = ref
        .watch(messageRepositoryProvider)
        .watch(conversationId)
        .listen(_onEvent);
    final typing = ref
        .watch(presenceServiceProvider)
        .openTyping(conversationId);
    _typing = typing;
    final typers = typing.typers.listen((t) {
      if (ref.mounted) state = state.copyWith(typers: t);
    });
    ref.onDispose(() {
      events.cancel();
      typers.cancel();
      typing.close();
      _readTimer?.cancel();
    });
    Future.microtask(_load);
    return const ChatState();
  }

  Future<void> _load() async {
    try {
      final (members, page) = await (
        _conversations.fetchMembers(conversationId),
        _messages.fetchPage(conversationId),
      ).wait;
      final reactions = await _messages.fetchReactions([
        for (final m in page) m.id,
      ]);
      if (!ref.mounted) return;
      final oldestFirst = page.reversed.toList();
      final myRead = _memberIn(members, _me)?.lastReadAt;
      String? firstUnread;
      for (final m in oldestFirst) {
        if (m.senderId != _me &&
            !m.isDeleted &&
            (myRead == null || m.createdAt.isAfter(myRead))) {
          firstUnread = m.id;
          break;
        }
      }
      state = state.copyWith(
        loading: false,
        clearError: true,
        members: members,
        messages: _merge(state.messages, oldestFirst),
        reactions: {...state.reactions, ..._group(reactions)},
        hasMore: page.length == MessageRepository.pageSize,
        firstUnreadId: firstUnread,
        removed: _memberIn(members, _me) == null,
      );
      markRead();
    } catch (e) {
      if (ref.mounted) state = state.copyWith(loading: false, error: e);
    }
  }

  Future<void> retryLoad() async {
    state = state.copyWith(loading: true, clearError: true);
    await _load();
  }

  Future<void> loadMore() async {
    if (state.loading || state.loadingMore || !state.hasMore) return;
    Message? oldest;
    for (final m in state.messages) {
      if (m.sendState == SendState.sent) {
        oldest = m;
        break;
      }
    }
    if (oldest == null) return;
    state = state.copyWith(loadingMore: true);
    try {
      final page = await _messages.fetchPage(
        conversationId,
        before: oldest.createdAt,
      );
      final reactions = await _messages.fetchReactions([
        for (final m in page) m.id,
      ]);
      if (!ref.mounted) return;
      state = state.copyWith(
        loadingMore: false,
        messages: _merge(state.messages, page),
        reactions: {...state.reactions, ..._group(reactions)},
        hasMore: page.length == MessageRepository.pageSize,
      );
    } catch (_) {
      if (ref.mounted) state = state.copyWith(loadingMore: false);
    }
  }

  // Sending -------------------------------------------------------------------

  Future<void> send({
    String? text,
    ReplyPreview? replyTo,
    OutgoingAttachment? attachment,
  }) async {
    final body = text?.trim();
    if ((body == null || body.isEmpty) && attachment == null) return;
    _typing?.stopped();
    final local = Message(
      id: const Uuid().v4(),
      conversationId: conversationId,
      senderId: _me,
      sender: state.member(_me)?.profile,
      body: (body == null || body.isEmpty) ? null : body,
      replyTo: replyTo,
      createdAt: DateTime.now(),
      sendState: SendState.sending,
      pending: attachment,
      attachment: attachment == null
          ? null
          : Attachment(
              path: '',
              kind: attachment.kind,
              name: attachment.name,
              size: attachment.bytes.length,
              durationMs: attachment.durationMs,
              waveform: attachment.waveform,
              width: attachment.width,
              height: attachment.height,
            ),
    );
    _upsert(local);
    await _deliver(local);
  }

  Future<void> _deliver(Message local) async {
    try {
      final saved = await _messages.send(
        OutgoingMessage(
          id: local.id,
          conversationId: conversationId,
          body: local.body,
          replyToId: local.replyTo?.id,
          attachment: local.pending,
        ),
      );
      if (ref.mounted) _upsert(saved);
    } catch (_) {
      if (!ref.mounted) return;
      // Realtime may already have delivered the stored row.
      final current = _find(local.id);
      if (current == null || current.sendState == SendState.sending) {
        _upsert(local.copyWith(sendState: SendState.failed));
      }
    }
  }

  Future<void> retry(String messageId) async {
    final m = _find(messageId);
    if (m == null || m.sendState != SendState.failed) return;
    final again = m.copyWith(sendState: SendState.sending);
    _upsert(again);
    await _deliver(again);
  }

  void discard(String messageId) {
    final m = _find(messageId);
    if (m == null || m.sendState == SendState.sent) return;
    state = state.copyWith(
      messages: [
        for (final x in state.messages)
          if (x.id != messageId) x,
      ],
    );
  }

  // Editing -------------------------------------------------------------------

  /// Optimistic; restores the old text and rethrows on failure.
  Future<void> edit(String messageId, String body) async {
    final before = _find(messageId);
    final text = body.trim();
    if (before == null || text.isEmpty || text == before.body) return;
    _upsert(before.copyWith(body: text, editedAt: DateTime.now()));
    try {
      await _messages.edit(messageId, text);
    } catch (_) {
      if (ref.mounted) _upsert(before);
      rethrow;
    }
  }

  /// Optimistic; restores the message and rethrows on failure.
  Future<void> delete(String messageId) async {
    final before = _find(messageId);
    if (before == null) return;
    if (before.sendState != SendState.sent) return discard(messageId);
    _upsert(
      Message(
        id: before.id,
        conversationId: before.conversationId,
        senderId: before.senderId,
        sender: before.sender,
        createdAt: before.createdAt,
        deletedAt: DateTime.now(),
      ),
    );
    final reactions = state.reactions[messageId];
    state = state.copyWith(reactions: {...state.reactions}..remove(messageId));
    try {
      await _messages.delete(before);
    } catch (_) {
      if (ref.mounted) {
        _upsert(before);
        if (reactions != null) {
          state = state.copyWith(
            reactions: {...state.reactions, messageId: reactions},
          );
        }
      }
      rethrow;
    }
  }

  // Reactions -----------------------------------------------------------------

  Future<void> toggleReaction(String messageId, String emoji) async {
    final mine = Reaction(messageId: messageId, userId: _me, emoji: emoji);
    final had = state.reactions[messageId]?.contains(mine) ?? false;
    had ? _removeReaction(mine) : _addReaction(mine);
    try {
      had
          ? await _messages.removeReaction(messageId, emoji)
          : await _messages.addReaction(messageId, emoji);
    } catch (_) {
      if (!ref.mounted) return;
      had ? _addReaction(mine) : _removeReaction(mine);
    }
  }

  void _addReaction(Reaction r) {
    final list = state.reactions[r.messageId] ?? const [];
    if (list.contains(r)) return;
    state = state.copyWith(
      reactions: {
        ...state.reactions,
        r.messageId: [...list, r],
      },
    );
  }

  void _removeReaction(Reaction r) {
    final list = state.reactions[r.messageId];
    if (list == null || !list.contains(r)) return;
    state = state.copyWith(
      reactions: {
        ...state.reactions,
        r.messageId: [
          for (final x in list)
            if (x != r) x,
        ],
      },
    );
  }

  // Typing + read state -------------------------------------------------------

  void typing() => _typing?.typing();

  void stoppedTyping() => _typing?.stopped();

  /// Marks the conversation read (debounced), only while the app is in front.
  void markRead() {
    _readTimer?.cancel();
    _readTimer = Timer(const Duration(milliseconds: 600), () async {
      final life = WidgetsBinding.instance.lifecycleState;
      if (life != null && life != AppLifecycleState.resumed) return;
      if (!ref.mounted || state.removed) return;
      ref
          .read(conversationListProvider.notifier)
          .markReadLocally(conversationId);
      try {
        await _conversations.markRead(conversationId);
      } catch (_) {
        // Retried on the next open or message.
      }
    });
  }

  // Realtime ------------------------------------------------------------------

  Future<void> _onEvent(ChatEvent event) async {
    try {
      switch (event) {
        case MessageChanged(:final messageId):
          final m = await _messages.fetchMessage(messageId);
          if (m == null || !ref.mounted) return;
          _upsert(m);
          if (m.senderId != _me) markRead();
        case ReactionAdded(:final reaction):
          if (_find(reaction.messageId) != null) _addReaction(reaction);
        case ReactionRemoved(:final reaction):
          _removeReaction(reaction);
        case MembersChanged():
          final members = await _conversations.fetchMembers(conversationId);
          if (!ref.mounted) return;
          state = state.copyWith(
            members: members,
            removed: _memberIn(members, _me) == null,
          );
        case Resubscribed():
          final page = await _messages.fetchPage(conversationId);
          final reactions = await _messages.fetchReactions([
            for (final m in page) m.id,
          ]);
          if (!ref.mounted) return;
          state = state.copyWith(
            messages: _merge(state.messages, page),
            reactions: {...state.reactions, ..._group(reactions)},
          );
      }
    } catch (_) {
      // A missed live update is recovered on the next resubscribe or open.
    }
  }

  // Helpers -------------------------------------------------------------------

  Message? _find(String id) {
    for (final m in state.messages) {
      if (m.id == id) return m;
    }
    return null;
  }

  void _upsert(Message m) {
    state = state.copyWith(messages: _merge(state.messages, [m]));
  }

  static ConversationMember? _memberIn(
    List<ConversationMember> members,
    String id,
  ) {
    for (final m in members) {
      if (m.userId == id) return m;
    }
    return null;
  }

  static List<Message> _merge(List<Message> existing, List<Message> incoming) {
    final byId = {for (final m in existing) m.id: m};
    for (final m in incoming) {
      byId[m.id] = m;
    }
    return byId.values.toList()..sort((a, b) {
      // Unsent messages stay at the bottom, in the order they were written.
      final pa = a.sendState != SendState.sent;
      final pb = b.sendState != SendState.sent;
      if (pa != pb) return pa ? 1 : -1;
      final c = a.createdAt.compareTo(b.createdAt);
      return c != 0 ? c : a.id.compareTo(b.id);
    });
  }

  static Map<String, List<Reaction>> _group(List<Reaction> reactions) {
    final out = <String, List<Reaction>>{};
    for (final r in reactions) {
      (out[r.messageId] ??= []).add(r);
    }
    return out;
  }
}

final chatControllerProvider = NotifierProvider.autoDispose
    .family<ChatController, ChatState, String>(ChatController.new);
