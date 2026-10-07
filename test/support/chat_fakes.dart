import 'dart:async';

import 'package:chatapp/core/providers.dart';
import 'package:chatapp/features/chat/data/message_repository.dart';
import 'package:chatapp/features/chat/data/presence_service.dart';
import 'package:chatapp/features/chat/domain/message.dart';
import 'package:chatapp/features/conversations/data/conversation_repository.dart';
import 'package:chatapp/features/conversations/domain/conversation.dart';
import 'package:chatapp/features/people/data/people_repository.dart';
import 'package:chatapp/features/profile/domain/profile.dart';
import 'package:flutter_riverpod/misc.dart' show Override;

class FakeConversationRepository implements ConversationRepository {
  List<ConversationSummary> conversations = [];
  Map<String, List<ConversationMember>> members = {};
  Object? listError;
  final changes = StreamController<void>.broadcast();
  final List<String> markReadCalls = [];
  final List<String> dmCalls = [];
  final List<({String name, List<String> ids})> groupCalls = [];
  String nextConversationId = 'new-conv';
  InvitePreview? invite;
  final List<String> joinCalls = [];

  @override
  Future<List<ConversationSummary>> fetchConversations() async {
    final e = listError;
    if (e != null) throw e;
    return conversations;
  }

  @override
  Stream<void> listChanges() => changes.stream;

  @override
  Future<String> getOrCreateDm(String otherUserId) async {
    dmCalls.add(otherUserId);
    return nextConversationId;
  }

  @override
  Future<String> createGroup(String name, List<String> memberIds) async {
    groupCalls.add((name: name, ids: memberIds));
    return nextConversationId;
  }

  @override
  Future<List<ConversationMember>> fetchMembers(String id) async =>
      members[id] ?? const [];

  @override
  Future<void> renameGroup(String id, String name) async {}

  @override
  Future<void> addMembers(String id, List<String> userIds) async {}

  @override
  Future<void> removeMember(String id, String userId) async {}

  @override
  Future<void> setRole(String id, String userId, MemberRole role) async {}

  @override
  Future<void> markRead(String id) async => markReadCalls.add(id);

  @override
  Future<String> createInvite(String id) async => 'tok123tok123tok123';

  @override
  Future<void> revokeInvites(String id) async {}

  @override
  Future<InvitePreview?> getInvite(String token) async => invite;

  @override
  Future<String> joinViaInvite(String token) async {
    joinCalls.add(token);
    return invite!.conversationId;
  }
}

class FakeMessageRepository implements MessageRepository {
  /// Newest first, per conversation.
  Map<String, List<Message>> pages = {};
  List<Reaction> reactions = [];
  final events = StreamController<ChatEvent>.broadcast();
  final List<OutgoingMessage> sent = [];
  final List<(String, String)> edits = [];
  final List<String> deletes = [];
  final List<(String, String, bool)> reactionCalls = [];

  /// Next send throws this (once).
  Object? sendError;

  /// When set, sends wait on this.
  Completer<void>? sendGate;
  String me = 'me';
  final Map<String, Message> byId = {};

  @override
  Future<List<Message>> fetchPage(String id, {DateTime? before}) async {
    final all = pages[id] ?? const [];
    final older = before == null
        ? all
        : all.where((m) => m.createdAt.isBefore(before)).toList();
    return older.take(MessageRepository.pageSize).toList();
  }

  @override
  Future<Message?> fetchMessage(String id) async => byId[id];

  @override
  Future<Message> send(OutgoingMessage m) async {
    sent.add(m);
    final gate = sendGate;
    if (gate != null) await gate.future;
    final e = sendError;
    if (e != null) {
      sendError = null;
      throw e;
    }
    final a = m.attachment;
    return Message(
      id: m.id,
      conversationId: m.conversationId,
      senderId: me,
      body: m.body,
      createdAt: DateTime.now(),
      attachment: a == null
          ? null
          : Attachment(
              path: '${m.conversationId}/x.${a.extension}',
              kind: a.kind,
              name: a.name,
              size: a.bytes.length,
            ),
    );
  }

  @override
  Future<void> edit(String id, String body) async => edits.add((id, body));

  @override
  Future<void> delete(Message m) async => deletes.add(m.id);

  @override
  Future<List<Reaction>> fetchReactions(List<String> ids) async => [
    for (final r in reactions)
      if (ids.contains(r.messageId)) r,
  ];

  @override
  Future<void> addReaction(String id, String emoji) async =>
      reactionCalls.add((id, emoji, true));

  @override
  Future<void> removeReaction(String id, String emoji) async =>
      reactionCalls.add((id, emoji, false));

  @override
  Future<String> attachmentUrl(String path) async => 'https://x/$path';

  @override
  Stream<ChatEvent> watch(String id) => events.stream;
}

class FakePeopleRepository implements PeopleRepository {
  FakePeopleRepository([this.people = const []]);

  List<Profile> people;

  @override
  Future<List<Profile>> searchPeople({String query = ''}) async {
    final q = query.toLowerCase();
    return [
      for (final p in people)
        if (q.isEmpty ||
            p.displayName.toLowerCase().contains(q) ||
            p.username.contains(q))
          p,
    ];
  }
}

class FakeTypingSession implements TypingSession {
  final controller = StreamController<Set<String>>.broadcast();
  int typingCalls = 0;
  int stopCalls = 0;

  @override
  Stream<Set<String>> get typers => controller.stream;

  @override
  void typing() => typingCalls++;

  @override
  void stopped() => stopCalls++;

  @override
  Future<void> close() async {}
}

class FakePresenceService implements PresenceService {
  final online = StreamController<Set<String>>.broadcast();
  final connection = StreamController<bool>.broadcast();
  final sessions = <String, FakeTypingSession>{};

  @override
  Stream<Set<String>> watchOnline() => online.stream;

  @override
  Stream<bool> watchConnection() => connection.stream;

  @override
  TypingSession openTyping(String id) => sessions[id] = FakeTypingSession();
}

class ChatFakes {
  final conversations = FakeConversationRepository();
  final messages = FakeMessageRepository();
  final people = FakePeopleRepository();
  final presence = FakePresenceService();

  List<Override> get overrides => [
    conversationRepositoryProvider.overrideWithValue(conversations),
    messageRepositoryProvider.overrideWithValue(messages),
    peopleRepositoryProvider.overrideWithValue(people),
    presenceServiceProvider.overrideWithValue(presence),
  ];
}

Profile person(String id, String name, {String? username}) => Profile(
  id: id,
  username: username ?? name.toLowerCase().split(' ').first,
  displayName: name,
);

ConversationMember member(Profile p, {bool admin = false, DateTime? read}) =>
    ConversationMember(
      profile: p,
      role: admin ? MemberRole.admin : MemberRole.member,
      joinedAt: DateTime(2026, 10, 1),
      lastReadAt: read,
    );

Message msg(String id, String conv, Profile sender, String body, DateTime at) =>
    Message(
      id: id,
      conversationId: conv,
      senderId: sender.id,
      sender: sender,
      body: body,
      createdAt: at,
    );
