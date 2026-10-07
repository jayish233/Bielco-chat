import 'package:chatapp/core/router.dart';
import 'package:chatapp/features/chat/data/message_repository.dart';
import 'package:chatapp/features/chat/domain/message.dart';
import 'package:chatapp/features/conversations/domain/conversation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_pump.dart';
import '../../support/chat_fakes.dart';

final grace = person('g', 'Grace Hopper');
final alan = person('a', 'Alan Turing');
final t0 = DateTime.now().subtract(const Duration(minutes: 30));

ConversationSummary dmWithGrace({int unread = 0, String? last}) =>
    ConversationSummary(
      id: 'dm1',
      type: ConversationType.direct,
      createdAt: t0,
      lastMessageAt: t0,
      myRole: MemberRole.member,
      memberCount: 2,
      unreadCount: unread,
      otherUser: grace,
      lastMessage: last == null
          ? null
          : MessagePreview(
              id: 'm1',
              senderId: grace.id,
              senderName: grace.displayName,
              body: last,
              createdAt: t0,
            ),
    );

ConversationSummary group() => ConversationSummary(
  id: 'g1',
  type: ConversationType.group,
  name: 'Weekend',
  createdAt: t0,
  myRole: MemberRole.admin,
  memberCount: 3,
);

ChatFakes seeded({DateTime? graceRead}) {
  final f = ChatFakes();
  f.conversations.conversations = [
    dmWithGrace(unread: 1, last: 'Hi Ada'),
    group(),
  ];
  f.conversations.members['dm1'] = [member(me), member(grace, read: graceRead)];
  f.conversations.members['g1'] = [
    member(me, admin: true),
    member(grace),
    member(alan),
  ];
  f.messages.pages['dm1'] = [msg('m1', 'dm1', grace, 'Hi Ada', t0)];
  return f;
}

void main() {
  testWidgets('chat list shows rows, preview, unread badge and filters', (
    t,
  ) async {
    await pumpApp(t, fakes: seeded());

    expect(find.text('Grace Hopper'), findsOneWidget);
    expect(find.text('Hi Ada'), findsOneWidget);
    expect(find.text('Weekend'), findsOneWidget);
    expect(find.text('Group created. Say hi 👋'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);

    await t.tap(find.text('Groups'));
    await t.pumpAndSettle();
    expect(find.text('Grace Hopper'), findsNothing);
    expect(find.text('Weekend'), findsOneWidget);

    await t.tap(find.text('Unread · 1'));
    await t.pumpAndSettle();
    expect(find.text('Grace Hopper'), findsOneWidget);
    expect(find.text('Weekend'), findsNothing);
  });

  testWidgets('opening a chat shows messages, New divider, and marks read', (
    t,
  ) async {
    final app = await pumpApp(t, fakes: seeded());
    await t.tap(find.text('Grace Hopper'));
    await t.pumpAndSettle();

    expect(find.text('Hi Ada'), findsOneWidget);
    expect(find.text('New'), findsOneWidget);
    expect(find.text('Today'), findsOneWidget);
    await t.pump(const Duration(seconds: 1));
    expect(app.fakes.conversations.markReadCalls, contains('dm1'));
  });

  testWidgets('sending shows the message right away, then it is stored', (
    t,
  ) async {
    final f = seeded();
    await pumpApp(t, fakes: f, location: Routes.chat('dm1'));

    await t.enterText(find.byType(TextField), '  Hello Grace  ');
    await t.pump();
    await t.tap(find.byTooltip('Send'));
    await t.pumpAndSettle();

    expect(find.text('Hello Grace'), findsOneWidget);
    expect(f.messages.sent.single.body, 'Hello Grace');
    expect(f.messages.sent.single.conversationId, 'dm1');
    expect(find.byIcon(Icons.done), findsOneWidget);
    expect(f.presence.sessions['dm1']!.stopCalls, greaterThan(0));
  });

  testWidgets('a failed send can be retried', (t) async {
    final f = seeded();
    f.messages.sendError = Exception('offline');
    await pumpApp(t, fakes: f, location: Routes.chat('dm1'));

    await t.enterText(find.byType(TextField), 'Are you there?');
    await t.pump();
    await t.tap(find.byTooltip('Send'));
    await t.pumpAndSettle();
    expect(find.text('Not sent · Tap to retry'), findsOneWidget);

    await t.tap(find.text('Not sent · Tap to retry'));
    await t.pumpAndSettle();
    expect(find.text('Not sent · Tap to retry'), findsNothing);
    expect(f.messages.sent, hasLength(2));
    expect(
      f.messages.sent[0].id,
      f.messages.sent[1].id,
      reason: 'same id on retry',
    );
  });

  testWidgets('read receipt: Seen once the other person has read it', (
    t,
  ) async {
    final f = seeded(graceRead: DateTime.now().add(const Duration(minutes: 1)));
    f.messages.pages['dm1'] = [
      msg(
        'm2',
        'dm1',
        me,
        'Did you see this?',
        t0.add(const Duration(minutes: 1)),
      ),
      msg('m1', 'dm1', grace, 'Hi Ada', t0),
    ];
    await pumpApp(t, fakes: f, location: Routes.chat('dm1'));

    expect(find.byIcon(Icons.done_all), findsOneWidget);
    expect(find.textContaining('Seen'), findsOneWidget);
  });

  testWidgets('incoming realtime message appears', (t) async {
    final f = seeded();
    await pumpApp(t, fakes: f, location: Routes.chat('dm1'));

    final m = msg('m9', 'dm1', grace, 'Live one', DateTime.now());
    f.messages.byId['m9'] = m;
    f.messages.events.add(const MessageChanged('m9'));
    await t.pumpAndSettle();
    expect(find.text('Live one'), findsOneWidget);
    await t.pump(const Duration(seconds: 1));
    expect(f.conversations.markReadCalls.length, greaterThanOrEqualTo(2));
  });

  testWidgets('typing indicator names the person', (t) async {
    final f = seeded();
    await pumpApp(t, fakes: f, location: Routes.chat('dm1'));

    f.presence.sessions['dm1']!.controller.add({'g'});
    await t.pump();
    await t.pump(const Duration(milliseconds: 50));
    expect(find.text('Grace is typing…'), findsOneWidget);

    f.presence.sessions['dm1']!.controller.add({});
    await t.pump();
    await t.pump(const Duration(milliseconds: 50));
    expect(find.text('Grace is typing…'), findsNothing);
  });

  testWidgets(
    'reacting from the actions sheet adds a pill; tapping it removes it',
    (t) async {
      final f = seeded();
      await pumpApp(t, fakes: f, location: Routes.chat('dm1'));

      await t.longPress(find.text('Hi Ada'));
      await t.pumpAndSettle();
      await t.tap(find.bySemanticsLabel('React 👍'));
      await t.pumpAndSettle();
      expect(f.messages.reactionCalls.single, ('m1', '👍', true));
      expect(find.bySemanticsLabel('👍 1'), findsOneWidget);

      await t.tap(find.bySemanticsLabel('👍 1'));
      await t.pumpAndSettle();
      expect(f.messages.reactionCalls.last, ('m1', '👍', false));
      expect(find.bySemanticsLabel('👍 1'), findsNothing);
    },
  );

  testWidgets('editing my message updates it and marks it Edited', (t) async {
    final f = seeded();
    f.messages.pages['dm1'] = [
      msg('m2', 'dm1', me, 'Typo hree', t0.add(const Duration(minutes: 1))),
      msg('m1', 'dm1', grace, 'Hi Ada', t0),
    ];
    await pumpApp(t, fakes: f, location: Routes.chat('dm1'));

    await t.longPress(find.text('Typo hree'));
    await t.pumpAndSettle();
    await t.tap(find.text('Edit'));
    await t.pumpAndSettle();
    expect(find.text('Editing message'), findsOneWidget);

    await t.enterText(find.byType(TextField), 'Typo here');
    await t.pump();
    await t.tap(find.byTooltip('Save edit'));
    await t.pumpAndSettle();
    expect(f.messages.edits.single, ('m2', 'Typo here'));
    expect(find.text('Typo here'), findsOneWidget);
    expect(find.textContaining('Edited'), findsOneWidget);
  });

  testWidgets('replying quotes the original message', (t) async {
    final f = seeded();
    await pumpApp(t, fakes: f, location: Routes.chat('dm1'));

    await t.longPress(find.text('Hi Ada'));
    await t.pumpAndSettle();
    await t.tap(find.text('Reply'));
    await t.pumpAndSettle();
    expect(find.text('Replying to Grace Hopper'), findsOneWidget);

    await t.enterText(find.byType(TextField), 'Hey!');
    await t.pump();
    await t.tap(find.byTooltip('Send'));
    await t.pumpAndSettle();
    expect(f.messages.sent.single.replyToId, 'm1');
    expect(find.text('Replying to Grace Hopper'), findsNothing);
  });

  testWidgets('empty group invites the admin to add people', (t) async {
    await pumpApp(t, fakes: seeded(), location: Routes.chat('g1'));
    expect(find.text('Say hi 👋'), findsOneWidget);
    expect(find.text('Invite people'), findsOneWidget);
    expect(find.text('3 members'), findsOneWidget);
  });

  testWidgets('wide layout shows the list and the chat side by side', (
    t,
  ) async {
    await pumpApp(t, fakes: seeded(), size: const Size(1300, 860));
    expect(find.text('Pick a chat'), findsOneWidget);

    await t.tap(find.text('Grace Hopper'));
    await t.pumpAndSettle();
    expect(find.text('Weekend'), findsOneWidget, reason: 'list still visible');
    expect(find.text('Hi Ada'), findsNWidgets(2), reason: 'preview + bubble');
    expect(find.byTooltip('Back'), findsNothing);
  });

  testWidgets('deleting my message asks first, then shows it as deleted', (
    t,
  ) async {
    final f = seeded();
    f.messages.pages['dm1'] = [
      msg('m2', 'dm1', me, 'Oops', t0.add(const Duration(minutes: 1))),
    ];
    await pumpApp(t, fakes: f, location: Routes.chat('dm1'));

    await t.longPress(find.text('Oops'));
    await t.pumpAndSettle();
    await t.tap(find.text('Delete'));
    await t.pumpAndSettle();
    await t.tap(find.widgetWithText(TextButton, 'Delete'));
    await t.pumpAndSettle();
    expect(f.messages.deletes, ['m2']);
    expect(find.text('You deleted this message'), findsOneWidget);
  });

  testWidgets('load more fetches older pages when scrolling up', (t) async {
    final f = seeded();
    f.messages.pages['dm1'] = [
      for (var i = 0; i < 70; i++)
        msg(
          'p$i',
          'dm1',
          grace,
          'Message $i',
          t0.subtract(Duration(minutes: i)),
        ),
    ];
    await pumpApp(t, fakes: f, location: Routes.chat('dm1'));
    expect(find.text('Message 0'), findsOneWidget);

    await t.fling(find.text('Message 0'), const Offset(0, 4000), 4000);
    await t.pumpAndSettle();
    await t.fling(find.byType(ListView).last, const Offset(0, 4000), 4000);
    await t.pumpAndSettle();
    await t.fling(find.byType(ListView).last, const Offset(0, 4000), 4000);
    await t.pumpAndSettle();
    expect(find.text('Message 69'), findsOneWidget);
  });

  test('page size is 50', () => expect(MessageRepository.pageSize, 50));

  test('reply preview text for attachments', () {
    expect(
      ReplyPreview.of(
        Message(
          id: 'x',
          conversationId: 'c',
          senderId: 's',
          createdAt: DateTime(2026),
          attachment: const Attachment(
            path: 'c/x.png',
            kind: AttachmentKind.image,
          ),
        ),
      ).attachmentKind,
      AttachmentKind.image,
    );
  });
}
