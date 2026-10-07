import 'dart:typed_data';

import '../../profile/domain/profile.dart';

enum AttachmentKind { image, file, audio }

AttachmentKind? parseAttachmentKind(Object? value) => switch (value) {
  'image' => AttachmentKind.image,
  'file' => AttachmentKind.file,
  'audio' => AttachmentKind.audio,
  _ => null,
};

class Attachment {
  const Attachment({
    required this.path,
    required this.kind,
    this.name,
    this.size,
    this.durationMs,
    this.waveform = const [],
    this.width,
    this.height,
  });

  /// Storage path inside the `attachments` bucket (`{conversation}/{file}`).
  final String path;
  final AttachmentKind kind;
  final String? name;
  final int? size;

  /// Voice notes: length and normalized (0–1) bar heights.
  final int? durationMs;
  final List<double> waveform;

  /// Images: pixel size, when known, to reserve layout space.
  final int? width;
  final int? height;

  Map<String, dynamic>? get metaJson {
    final meta = <String, dynamic>{
      'duration_ms': ?durationMs,
      if (waveform.isNotEmpty)
        'waveform': [for (final v in waveform) (v * 100).round() / 100],
      'width': ?width,
      'height': ?height,
    };
    return meta.isEmpty ? null : meta;
  }

  static Attachment? fromRow(Map<String, dynamic> j) {
    final path = j['attachment_path'] as String?;
    final kind = parseAttachmentKind(j['attachment_type']);
    if (path == null || kind == null) return null;
    final meta = (j['attachment_meta'] as Map?)?.cast<String, dynamic>() ?? {};
    return Attachment(
      path: path,
      kind: kind,
      name: j['attachment_name'] as String?,
      size: (j['attachment_size'] as num?)?.toInt(),
      durationMs: (meta['duration_ms'] as num?)?.toInt(),
      waveform: [
        for (final v in (meta['waveform'] as List?) ?? const [])
          (v as num).toDouble(),
      ],
      width: (meta['width'] as num?)?.toInt(),
      height: (meta['height'] as num?)?.toInt(),
    );
  }
}

/// A file chosen to send, before it is uploaded.
class OutgoingAttachment {
  const OutgoingAttachment({
    required this.bytes,
    required this.name,
    required this.kind,
    required this.contentType,
    this.durationMs,
    this.waveform = const [],
    this.width,
    this.height,
  });

  /// Uploads larger than this are refused before they start.
  static const maxBytes = 50 * 1024 * 1024;

  final Uint8List bytes;
  final String name;
  final AttachmentKind kind;
  final String contentType;
  final int? durationMs;
  final List<double> waveform;
  final int? width;
  final int? height;

  String get extension {
    final dot = name.lastIndexOf('.');
    return dot < 0 ? 'bin' : name.substring(dot + 1).toLowerCase();
  }
}

/// The message a reply points at, embedded for the quote above the reply.
class ReplyPreview {
  const ReplyPreview({
    required this.id,
    required this.senderId,
    this.senderName,
    this.body,
    this.attachmentKind,
    this.deleted = false,
  });

  factory ReplyPreview.fromJson(Map<String, dynamic> j) => ReplyPreview(
    id: j['id'] as String,
    senderId: j['sender_id'] as String,
    senderName:
        ((j['sender'] as Map?)?['display_name']) as String? ??
        j['sender_name'] as String?,
    body: j['body'] as String?,
    attachmentKind: parseAttachmentKind(j['attachment_type']),
    deleted: j['deleted_at'] != null,
  );

  factory ReplyPreview.of(Message m) => ReplyPreview(
    id: m.id,
    senderId: m.senderId,
    senderName: m.sender?.displayName,
    body: m.body,
    attachmentKind: m.attachment?.kind,
    deleted: m.isDeleted,
  );

  final String id;
  final String senderId;
  final String? senderName;
  final String? body;
  final AttachmentKind? attachmentKind;
  final bool deleted;
}

enum SendState { sent, sending, failed }

class Message {
  const Message({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.createdAt,
    this.sender,
    this.body,
    this.replyTo,
    this.attachment,
    this.editedAt,
    this.deletedAt,
    this.sendState = SendState.sent,
    this.pending,
  });

  /// Columns + embeds that every message query selects.
  static const select =
      '*, sender:profiles!sender_id(*), '
      'reply:reply_to_id(id, sender_id, body, attachment_type, deleted_at, '
      'sender:profiles!sender_id(display_name))';

  factory Message.fromJson(Map<String, dynamic> j) {
    final sender = j['sender'] as Map<String, dynamic>?;
    final reply = j['reply'] as Map<String, dynamic>?;
    return Message(
      id: j['id'] as String,
      conversationId: j['conversation_id'] as String,
      senderId: j['sender_id'] as String,
      sender: sender == null ? null : Profile.fromJson(sender),
      body: j['body'] as String?,
      replyTo: reply == null ? null : ReplyPreview.fromJson(reply),
      attachment: Attachment.fromRow(j),
      createdAt: parseTime(j['created_at'])!,
      editedAt: parseTime(j['edited_at']),
      deletedAt: parseTime(j['deleted_at']),
    );
  }

  final String id;
  final String conversationId;
  final String senderId;
  final Profile? sender;
  final String? body;
  final ReplyPreview? replyTo;
  final Attachment? attachment;
  final DateTime createdAt;
  final DateTime? editedAt;
  final DateTime? deletedAt;
  final SendState sendState;

  /// For an unsent message: what to (re)send.
  final OutgoingAttachment? pending;

  bool get isDeleted => deletedAt != null;
  bool get isEdited => editedAt != null && !isDeleted;

  Message copyWith({
    String? body,
    DateTime? editedAt,
    DateTime? deletedAt,
    SendState? sendState,
  }) => Message(
    id: id,
    conversationId: conversationId,
    senderId: senderId,
    sender: sender,
    body: body ?? this.body,
    replyTo: replyTo,
    attachment: attachment,
    createdAt: createdAt,
    editedAt: editedAt ?? this.editedAt,
    deletedAt: deletedAt ?? this.deletedAt,
    sendState: sendState ?? this.sendState,
    pending: pending,
  );
}

class Reaction {
  const Reaction({
    required this.messageId,
    required this.userId,
    required this.emoji,
  });

  factory Reaction.fromJson(Map<String, dynamic> j) => Reaction(
    messageId: j['message_id'] as String,
    userId: j['user_id'] as String,
    emoji: j['emoji'] as String,
  );

  final String messageId;
  final String userId;
  final String emoji;

  @override
  bool operator ==(Object other) =>
      other is Reaction &&
      other.messageId == messageId &&
      other.userId == userId &&
      other.emoji == emoji;

  @override
  int get hashCode => Object.hash(messageId, userId, emoji);
}

/// What to send: text and/or an attachment, optionally as a reply.
class OutgoingMessage {
  const OutgoingMessage({
    required this.id,
    required this.conversationId,
    this.body,
    this.replyToId,
    this.attachment,
  });

  /// Client-generated so the optimistic row and the stored row match.
  final String id;
  final String conversationId;
  final String? body;
  final String? replyToId;
  final OutgoingAttachment? attachment;
}
