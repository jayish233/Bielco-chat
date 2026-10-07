import 'package:chatapp/core/env.dart';
import 'package:chatapp/core/format.dart';
import 'package:chatapp/core/router.dart';
import 'package:chatapp/features/auth/data/auth_repository.dart';
import 'package:chatapp/features/chat/ui/widgets/attachment_views.dart';
import 'package:chatapp/features/conversations/domain/conversation.dart';
import 'package:chatapp/features/conversations/ui/chat_list_pane.dart';
import 'package:chatapp/features/chat/domain/message.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_pump.dart';
import '../../support/chat_fakes.dart';

final grace = person('g', 'Grace Hopper');
final alan = person('a', 'Alan Turing');

void main() {
  testWidgets('People: Message opens the DM', (t) async {
    final f = ChatFakes();
    f.people.people = [grace, alan];
    f.conversations.nextConversationId = 'dm-g';
    final app = await pumpApp(t, fakes: f, location: Routes.people);

    expect(find.text('Grace Hopper'), findsOneWidget);
    await t.tap(find.widgetWithText(OutlinedButton, 'Message').first);
    await t.pumpAndSettle();
    expect(f.conversations.dmCalls, ['g']);
    expect(app.router.routerDelegate.currentConfiguration.uri.path, '/c/dm-g');
  });

  testWidgets('People search filters by name', (t) async {
    final f = ChatFakes();
    f.people.people = [grace, alan];
    await pumpApp(t, fakes: f, location: Routes.people);
    await t.enterText(find.byType(TextField), 'grace');
    await t.pump(const Duration(milliseconds: 300));
    await t.pumpAndSettle();
    expect(find.text('Grace Hopper'), findsOneWidget);
    expect(find.text('Alan Turing'), findsNothing);
  });

  testWidgets('New group: name required, then created with the picked people', (
    t,
  ) async {
    final f = ChatFakes();
    f.people.people = [grace, alan];
    f.conversations.nextConversationId = 'g-new';
    final app = await pumpApp(t, fakes: f, location: Routes.newGroup);

    await t.tap(find.text('Create'));
    await t.pumpAndSettle();
    expect(find.textContaining('Give the group a name'), findsOneWidget);
    expect(f.conversations.groupCalls, isEmpty);

    await t.enterText(find.byType(TextField).first, 'Weekend');
    await t.tap(find.text('Grace Hopper'));
    await t.pump();
    expect(find.text('ADD PEOPLE · 1 SELECTED'), findsOneWidget);
    await t.tap(find.text('Create'));
    await t.pumpAndSettle();

    expect(f.conversations.groupCalls.single.name, 'Weekend');
    expect(f.conversations.groupCalls.single.ids, ['g']);
    expect(app.router.routerDelegate.currentConfiguration.uri.path, '/c/g-new');
  });

  testWidgets('invite link: preview then join', (t) async {
    final f = ChatFakes();
    f.conversations.invite = const InvitePreview(
      conversationId: 'g9',
      name: 'Book club',
      memberCount: 4,
      isMember: false,
    );
    final app = await pumpApp(
      t,
      fakes: f,
      location: Routes.join('tok123tok123tok123'),
    );
    expect(find.text('Book club'), findsOneWidget);
    expect(find.text('4 members'), findsOneWidget);

    await t.tap(find.text('Join group'));
    await t.pumpAndSettle();
    expect(f.conversations.joinCalls, ['tok123tok123tok123']);
    expect(app.router.routerDelegate.currentConfiguration.uri.path, '/c/g9');
  });

  testWidgets('dead invite link explains itself', (t) async {
    await pumpApp(t, location: Routes.join('tok123tok123tok123'));
    expect(find.text('This invite link doesn’t work'), findsOneWidget);
  });

  testWidgets('invite opened while signed out resumes after sign-in', (
    t,
  ) async {
    final f = ChatFakes();
    f.conversations.invite = const InvitePreview(
      conversationId: 'g9',
      name: 'Book club',
      memberCount: 4,
      isMember: false,
    );
    final app = await pumpApp(
      t,
      fakes: f,
      status: AuthStatus.signedOut,
      location: Routes.join('tok123tok123tok123'),
    );
    expect(find.text('Welcome back'), findsOneWidget);

    app.auth.emit(AuthStatus.signedIn);
    await t.pumpAndSettle();
    expect(find.text('Book club'), findsOneWidget);
  });

  testWidgets('unknown route shows a 404 page', (t) async {
    await pumpApp(t, location: '/nope/nothing');
    expect(find.text('Page not found'), findsOneWidget);
  });

  testWidgets('group info: admin creates and sees an invite link', (t) async {
    final f = ChatFakes();
    f.conversations.conversations = [
      ConversationSummary(
        id: 'g1',
        type: ConversationType.group,
        name: 'Weekend',
        createdAt: DateTime(2026, 10, 1),
        myRole: MemberRole.admin,
        memberCount: 2,
      ),
    ];
    f.conversations.members['g1'] = [member(me, admin: true), member(grace)];
    await pumpApp(t, fakes: f, location: Routes.groupInfo('g1'));

    expect(find.text('Weekend'), findsOneWidget);
    expect(find.text('Admin'), findsOneWidget);
    expect(find.text('Member'), findsOneWidget);
    await t.tap(find.text('Create invite link'));
    await t.pumpAndSettle();
    expect(find.text(AppLinks.invite('tok123tok123tok123')), findsOneWidget);
    expect(find.text('Copy link'), findsOneWidget);
  });

  group('helpers', () {
    test('invite tokens are pulled from links or taken bare', () {
      expect(
        AppLinks.tokenFrom('http://localhost:3000/#/join/abcdef0123456789'),
        'abcdef0123456789',
      );
      expect(
        AppLinks.tokenFrom(' abcdef0123456789abcd '),
        'abcdef0123456789abcd',
      );
      expect(AppLinks.tokenFrom('hello'), isNull);
    });

    test('list times', () {
      final now = DateTime(2026, 10, 7, 12);
      expect(listTime(DateTime(2026, 10, 7, 9, 5), now: now), '09:05');
      expect(listTime(DateTime(2026, 10, 6, 9), now: now), 'Yesterday');
      expect(listTime(DateTime(2026, 9, 1), now: now), '1 Sep');
      expect(listTime(DateTime(2025, 9, 1), now: now), '1 Sep 2025');
    });

    test('file sizes and durations', () {
      expect(fileSize(900), '900 B');
      expect(fileSize(2048), '2 KB');
      expect(fileSize((2.4 * 1024 * 1024).round()), '2.4 MB');
      expect(duration(const Duration(seconds: 92)), '1:32');
    });

    test('previews', () {
      ConversationSummary c(MessagePreview? m, {bool group = false}) =>
          ConversationSummary(
            id: 'c',
            type: group ? ConversationType.group : ConversationType.direct,
            createdAt: DateTime(2026),
            myRole: MemberRole.member,
            memberCount: 2,
            lastMessage: m,
          );
      MessagePreview p(
        String sender, {
        String? body,
        AttachmentKind? kind,
        bool deleted = false,
      }) => MessagePreview(
        id: 'm',
        senderId: sender,
        senderName: 'Grace Hopper',
        body: body,
        attachmentKind: kind,
        deleted: deleted,
        createdAt: DateTime(2026),
      );
      expect(previewText(c(p('me', body: 'hi')), 'me'), 'You: hi');
      expect(
        previewText(c(p('g', body: 'hi'), group: true), 'me'),
        'Grace: hi',
      );
      expect(
        previewText(c(p('g', kind: AttachmentKind.audio)), 'me'),
        '🎤 Voice note',
      );
      expect(previewText(c(p('g', deleted: true)), 'me'), 'Message deleted');
      expect(previewText(c(null), 'me'), 'Say hi 👋');
    });

    test('waveform resampling', () {
      expect(Waveform.resample(const [], 4), everyElement(0.15));
      expect(Waveform.resample(const [0, 1, 0, 1], 2), [0.5, 0.5]);
      expect(Waveform.resample(const [1], 3), [1, 1, 1]);
    });
  });
}
