// Runs against the local Supabase stack:
//   flutter test test_integration --dart-define-from-file=env/local.json
import 'dart:typed_data';

import 'package:chatapp/core/app_failure.dart';
import 'package:chatapp/core/env.dart';
import 'package:chatapp/features/auth/data/supabase_auth_repository.dart';
import 'package:chatapp/features/chat/data/message_repository.dart';
import 'package:chatapp/features/chat/data/supabase_message_repository.dart';
import 'package:chatapp/features/chat/data/supabase_presence_service.dart';
import 'package:chatapp/features/chat/domain/message.dart';
import 'package:chatapp/features/conversations/data/supabase_conversation_repository.dart';
import 'package:chatapp/features/conversations/domain/conversation.dart';
import 'package:chatapp/features/people/data/supabase_people_repository.dart';
import 'package:chatapp/features/profile/data/supabase_profile_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import 'support/test_admin.dart';

const _pw = 'relaypass24';

class _User {
  _User(this.client, this.id, this.username);

  final SupabaseClient client;
  final String id;
  final String username;

  late final conversations = SupabaseConversationRepository(client);
  late final messages = SupabaseMessageRepository(client);
  late final people = SupabasePeopleRepository(client);
  late final profiles = SupabaseProfileRepository(client);
  late final presence = SupabasePresenceService(client);
}

String _s() {
  final n = DateTime.now().microsecondsSinceEpoch.toString();
  return n.substring(n.length - 10);
}

final _admin = TestAdmin();

Future<_User> _signUp(String name) async {
  final client = SupabaseClient(
    Env.supabaseUrl,
    Env.supabaseAnonKey,
    authOptions: const AuthClientOptions(authFlowType: AuthFlowType.implicit),
  );
  final auth = SupabaseAuthRepository(client);
  final username = '${name}_${_s()}';
  final email = '$username@example.com';
  await _admin.allow(email);
  await auth.signUp(
    email: email,
    password: _pw,
    username: username,
    displayName: '${name[0].toUpperCase()}${name.substring(1)} Test',
  );
  return _User(client, auth.currentUserId!, username);
}

OutgoingMessage _text(String conv, String body, {String? replyTo}) =>
    OutgoingMessage(
      id: const Uuid().v4(),
      conversationId: conv,
      body: body,
      replyToId: replyTo,
    );

void main() {
  late _User ada, grace, eve;

  setUp(() async {
    ada = await _signUp('ada');
    grace = await _signUp('grace');
    eve = await _signUp('eve');
  });
  tearDown(() async {
    for (final u in [ada, grace, eve]) {
      await u.client.dispose();
    }
    await _admin.cleanUp();
  });
  setUpAll(_admin.sweepLeftovers);
  tearDownAll(_admin.dispose);

  test('people search finds others by username, not me', () async {
    final found = await ada.people.searchPeople(query: grace.username);
    expect(found.map((p) => p.id), [grace.id]);
    final all = await ada.people.searchPeople();
    expect(all.map((p) => p.id), isNot(contains(ada.id)));
  });

  test('DM: one conversation, messages, unread, read receipts', () async {
    final dm = await ada.conversations.getOrCreateDm(grace.id);
    expect(await grace.conversations.getOrCreateDm(ada.id), dm);

    final hello = await ada.messages.send(_text(dm, '  hello grace  '));
    expect(hello.body, 'hello grace');
    expect(hello.sender?.id, ada.id);

    final list = await grace.conversations.fetchConversations();
    final row = list.singleWhere((c) => c.id == dm);
    expect(row.type, ConversationType.direct);
    expect(row.otherUser?.id, ada.id);
    expect(row.unreadCount, 1);
    expect(row.lastMessage?.body, 'hello grace');

    final reply = await grace.messages.send(
      _text(dm, 'hi!', replyTo: hello.id),
    );
    expect(reply.replyTo?.id, hello.id);
    expect(reply.replyTo?.senderName, contains('Ada'));

    await grace.conversations.markRead(dm);
    final after = await grace.conversations.fetchConversations();
    expect(after.singleWhere((c) => c.id == dm).unreadCount, 0);
    final members = await ada.conversations.fetchMembers(dm);
    final graceRead = members
        .singleWhere((m) => m.userId == grace.id)
        .lastReadAt;
    expect(graceRead, isNotNull);
    expect(graceRead!.isBefore(hello.createdAt), isFalse);

    expect(
      await eve.messages.fetchPage(dm),
      isEmpty,
      reason: 'outsider sees nothing',
    );
  });

  test('sending the same id twice returns the stored message', () async {
    final dm = await ada.conversations.getOrCreateDm(grace.id);
    final m = _text(dm, 'once');
    await ada.messages.send(m);
    final again = await ada.messages.send(m);
    expect(again.id, m.id);
    expect(await ada.messages.fetchPage(dm), hasLength(1));
  });

  test('edit, react, delete', () async {
    final dm = await ada.conversations.getOrCreateDm(grace.id);
    final m = await ada.messages.send(_text(dm, 'typo'));
    await ada.messages.edit(m.id, 'fixed');
    final edited = await grace.messages.fetchMessage(m.id);
    expect(edited?.body, 'fixed');
    expect(edited?.isEdited, isTrue);

    await grace.messages.addReaction(m.id, '👍');
    await grace.messages.addReaction(m.id, '👍'); // idempotent
    expect(await ada.messages.fetchReactions([m.id]), hasLength(1));
    await grace.messages.removeReaction(m.id, '👍');
    expect(await ada.messages.fetchReactions([m.id]), isEmpty);

    await expectLater(grace.messages.edit(m.id, 'hijack'), completes);
    expect(
      (await ada.messages.fetchMessage(m.id))?.body,
      'fixed',
      reason: 'RLS silently ignores edits by others',
    );

    await ada.messages.delete(m);
    final gone = await grace.messages.fetchMessage(m.id);
    expect(gone?.isDeleted, isTrue);
    expect(gone?.body, isNull);
  });

  test('groups: create, add, roles, invite links, leave', () async {
    final g = await ada.conversations.createGroup('  Weekend ', [grace.id]);
    final members = await ada.conversations.fetchMembers(g);
    expect(members.map((m) => m.userId).toSet(), {ada.id, grace.id});
    expect(members.singleWhere((m) => m.userId == ada.id).isAdmin, isTrue);

    await expectLater(
      grace.conversations.addMembers(g, [eve.id]),
      throwsA(isA<AppFailure>()),
    );
    await expectLater(
      grace.conversations.createInvite(g),
      throwsA(isA<AppFailure>()),
    );

    final token = await ada.conversations.createInvite(g);
    final preview = await eve.conversations.getInvite(token);
    expect(preview?.name, 'Weekend');
    expect(preview?.isMember, isFalse);
    expect(await eve.conversations.joinViaInvite(token), g);
    expect(
      (await eve.conversations.fetchConversations()).map((c) => c.id),
      contains(g),
    );

    await ada.conversations.revokeInvites(g);
    expect(await eve.conversations.getInvite(token), isNull);

    await ada.conversations.renameGroup(g, 'Weekend trip');
    final row = (await grace.conversations.fetchConversations()).singleWhere(
      (c) => c.id == g,
    );
    expect(row.name, 'Weekend trip');

    await ada.conversations.setRole(g, grace.id, MemberRole.admin);
    await ada.conversations.removeMember(g, ada.id); // leave
    expect(
      (await ada.conversations.fetchConversations()).map((c) => c.id),
      isNot(contains(g)),
    );
    await grace.conversations.removeMember(g, eve.id);
    final left = await grace.conversations.fetchMembers(g);
    expect(left.map((m) => m.userId), [grace.id]);
  });

  test('attachments: members can download, outsiders cannot', () async {
    final dm = await ada.conversations.getOrCreateDm(grace.id);
    final bytes = Uint8List.fromList(List.generate(2048, (i) => i % 256));
    final sent = await ada.messages.send(
      OutgoingMessage(
        id: const Uuid().v4(),
        conversationId: dm,
        attachment: OutgoingAttachment(
          bytes: bytes,
          name: 'notes.bin',
          kind: AttachmentKind.file,
          contentType: 'application/octet-stream',
        ),
      ),
    );
    final a = sent.attachment!;
    expect(a.path, startsWith('$dm/'));
    expect(a.size, 2048);
    expect(a.name, 'notes.bin');

    final url = await grace.messages.attachmentUrl(a.path);
    final res = await http.get(Uri.parse(url));
    expect(res.statusCode, 200);
    expect(res.bodyBytes, bytes);

    await expectLater(
      eve.messages.attachmentUrl(a.path),
      throwsA(isA<AppFailure>()),
    );
    await expectLater(
      eve.client.storage
          .from('attachments')
          .uploadBinary('$dm/evil.bin', bytes),
      throwsA(isA<StorageException>()),
    );
  });

  test('voice note metadata round-trips', () async {
    final dm = await ada.conversations.getOrCreateDm(grace.id);
    final sent = await ada.messages.send(
      OutgoingMessage(
        id: const Uuid().v4(),
        conversationId: dm,
        attachment: OutgoingAttachment(
          bytes: Uint8List(100),
          name: 'voice-note.m4a',
          kind: AttachmentKind.audio,
          contentType: 'audio/mp4',
          durationMs: 4200,
          waveform: const [0.1, 0.5, 0.9],
        ),
      ),
    );
    final read = await grace.messages.fetchMessage(sent.id);
    expect(read?.attachment?.kind, AttachmentKind.audio);
    expect(read?.attachment?.durationMs, 4200);
    expect(read?.attachment?.waveform, [0.1, 0.5, 0.9]);
  });

  test('avatar upload sets a public URL', () async {
    final png = Uint8List.fromList([
      0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, // signature only
    ]);
    final p = await ada.profiles.uploadAvatar(png, extension: 'png');
    expect(p.avatarUrl, contains('/avatars/${ada.id}/'));
    final res = await http.get(Uri.parse(p.avatarUrl!));
    expect(res.statusCode, 200);
  });

  test(
    'realtime: new messages, reactions and list changes arrive live',
    () async {
      final dm = await ada.conversations.getOrCreateDm(grace.id);
      final events = <ChatEvent>[];
      final sub = grace.messages.watch(dm).listen(events.add);
      var listPings = 0;
      final listSub = grace.conversations.listChanges().listen(
        (_) => listPings++,
      );
      await Future<void>.delayed(const Duration(seconds: 3));
      final pingsBefore = listPings;

      final m = await ada.messages.send(_text(dm, 'live?'));
      await ada.messages.addReaction(m.id, '🎉');
      // Realtime checks RLS after the fact: an insert deleted within a few ms
      // is never delivered (the end state is still right). Space them out.
      await Future<void>.delayed(const Duration(seconds: 2));
      await ada.messages.removeReaction(m.id, '🎉');

      final deadline = DateTime.now().add(const Duration(seconds: 10));
      while (DateTime.now().isBefore(deadline) &&
          !(events.any((e) => e is MessageChanged && e.messageId == m.id) &&
              events.any((e) => e is ReactionAdded) &&
              events.any((e) => e is ReactionRemoved))) {
        await Future<void>.delayed(const Duration(milliseconds: 200));
      }
      await sub.cancel();
      await listSub.cancel();

      expect(
        events.whereType<MessageChanged>().map((e) => e.messageId),
        contains(m.id),
      );
      expect(events.whereType<ReactionAdded>().single.reaction.emoji, '🎉');
      expect(
        events.whereType<ReactionRemoved>().single.reaction.messageId,
        m.id,
      );
      expect(listPings, greaterThan(pingsBefore));
    },
  );

  test('presence and typing', () async {
    final online = <Set<String>>[];
    final s1 = ada.presence.watchOnline().listen(online.add);
    final s2 = grace.presence.watchOnline().listen((_) {});
    final dm = await ada.conversations.getOrCreateDm(grace.id);
    final adaTyping = ada.presence.openTyping(dm);
    final graceTyping = grace.presence.openTyping(dm);
    final typers = <Set<String>>[];
    final s3 = graceTyping.typers.listen(typers.add);
    await Future<void>.delayed(const Duration(seconds: 3));
    adaTyping.typing();

    final deadline = DateTime.now().add(const Duration(seconds: 10));
    while (DateTime.now().isBefore(deadline) &&
        !(typers.any((t) => t.contains(ada.id)) &&
            online.any((o) => o.containsAll({ada.id, grace.id})))) {
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
    expect(typers.any((t) => t.contains(ada.id)), isTrue);
    expect(online.any((o) => o.containsAll({ada.id, grace.id})), isTrue);
    await s1.cancel();
    await s2.cancel();
    await s3.cancel();
    await adaTyping.close();
    await graceTyping.close();
  });
}
