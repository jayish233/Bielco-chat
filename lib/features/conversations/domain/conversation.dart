import '../../chat/domain/message.dart';
import '../../profile/domain/profile.dart';

enum ConversationType { direct, group }

enum MemberRole { admin, member }

MemberRole parseRole(Object? value) =>
    value == 'admin' ? MemberRole.admin : MemberRole.member;

/// The last message of a conversation, as shown in the chat list.
class MessagePreview {
  const MessagePreview({
    required this.id,
    required this.senderId,
    required this.createdAt,
    this.senderName,
    this.body,
    this.attachmentKind,
    this.deleted = false,
  });

  final String id;
  final String senderId;
  final String? senderName;
  final String? body;
  final AttachmentKind? attachmentKind;
  final bool deleted;
  final DateTime createdAt;
}

/// One row of `get_conversation_list()`.
class ConversationSummary {
  const ConversationSummary({
    required this.id,
    required this.type,
    required this.createdAt,
    required this.myRole,
    required this.memberCount,
    this.name,
    this.lastMessageAt,
    this.lastReadAt,
    this.unreadCount = 0,
    this.otherUser,
    this.lastMessage,
  });

  factory ConversationSummary.fromJson(Map<String, dynamic> j) {
    final type = j['type'] == 'group'
        ? ConversationType.group
        : ConversationType.direct;
    final otherId = j['other_user_id'] as String?;
    final lastId = j['last_message_id'] as String?;
    return ConversationSummary(
      id: j['id'] as String,
      type: type,
      name: j['name'] as String?,
      createdAt: parseTime(j['created_at'])!,
      lastMessageAt: parseTime(j['last_message_at']),
      myRole: parseRole(j['my_role']),
      lastReadAt: parseTime(j['last_read_at']),
      memberCount: (j['member_count'] as num?)?.toInt() ?? 0,
      unreadCount: (j['unread_count'] as num?)?.toInt() ?? 0,
      otherUser: otherId == null
          ? null
          : Profile(
              id: otherId,
              username: j['other_username'] as String,
              displayName: j['other_display_name'] as String,
              avatarUrl: j['other_avatar_url'] as String?,
            ),
      lastMessage: lastId == null
          ? null
          : MessagePreview(
              id: lastId,
              senderId: j['last_message_sender_id'] as String,
              senderName: j['last_message_sender_name'] as String?,
              body: j['last_message_body'] as String?,
              attachmentKind: parseAttachmentKind(
                j['last_message_attachment_type'],
              ),
              deleted: j['last_message_deleted'] as bool? ?? false,
              createdAt: parseTime(j['last_message_created_at'])!,
            ),
    );
  }

  final String id;
  final ConversationType type;
  final String? name;
  final DateTime createdAt;
  final DateTime? lastMessageAt;
  final MemberRole myRole;
  final DateTime? lastReadAt;
  final int memberCount;
  final int unreadCount;

  /// The other person in a DM (null for groups, or if they deleted their account).
  final Profile? otherUser;
  final MessagePreview? lastMessage;

  bool get isGroup => type == ConversationType.group;
  bool get isAdmin => myRole == MemberRole.admin;

  String get title => isGroup
      ? (name ?? 'Group')
      : (otherUser?.displayName ?? 'Deleted account');

  /// Seed for the avatar tint: the person for DMs, the group otherwise.
  String get avatarSeed => otherUser?.id ?? id;

  DateTime get sortTime => lastMessageAt ?? createdAt;

  ConversationSummary copyWith({int? unreadCount, DateTime? lastReadAt}) =>
      ConversationSummary(
        id: id,
        type: type,
        name: name,
        createdAt: createdAt,
        lastMessageAt: lastMessageAt,
        myRole: myRole,
        lastReadAt: lastReadAt ?? this.lastReadAt,
        memberCount: memberCount,
        unreadCount: unreadCount ?? this.unreadCount,
        otherUser: otherUser,
        lastMessage: lastMessage,
      );
}

class ConversationMember {
  const ConversationMember({
    required this.profile,
    required this.role,
    required this.joinedAt,
    this.lastReadAt,
  });

  factory ConversationMember.fromJson(Map<String, dynamic> j) =>
      ConversationMember(
        profile: Profile.fromJson(j['profile'] as Map<String, dynamic>),
        role: parseRole(j['role']),
        joinedAt: parseTime(j['joined_at'])!,
        lastReadAt: parseTime(j['last_read_at']),
      );

  final Profile profile;
  final MemberRole role;
  final DateTime joinedAt;
  final DateTime? lastReadAt;

  String get userId => profile.id;
  bool get isAdmin => role == MemberRole.admin;

  ConversationMember copyWith({DateTime? lastReadAt, MemberRole? role}) =>
      ConversationMember(
        profile: profile,
        role: role ?? this.role,
        joinedAt: joinedAt,
        lastReadAt: lastReadAt ?? this.lastReadAt,
      );
}

/// What someone sees on an invite link before joining.
class InvitePreview {
  const InvitePreview({
    required this.conversationId,
    required this.name,
    required this.memberCount,
    required this.isMember,
  });

  final String conversationId;
  final String name;
  final int memberCount;
  final bool isMember;
}
