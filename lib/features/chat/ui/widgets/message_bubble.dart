import 'package:flutter/material.dart';

import '../../../../core/format.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/ui/relay_avatar.dart';
import '../../domain/message.dart';
import 'attachment_views.dart';

/// Read state of one of my messages.
enum ReadMark { sending, sent, read }

/// One message: optional sender name/avatar (groups), the bubble, reactions,
/// and a meta line (time, edited, receipt / failed + retry).
class MessageRow extends StatelessWidget {
  const MessageRow({
    super.key,
    required this.message,
    required this.mine,
    required this.myId,
    required this.showSender,
    required this.firstInRun,
    required this.lastInRun,
    required this.reactions,
    required this.onActions,
    required this.onRetry,
    required this.onReaction,
    this.readMark,
    this.seenLabel,
    this.onReplyTap,
  });

  final Message message;
  final bool mine;
  final String myId;

  /// Groups: name above the first bubble and avatar beside the last one.
  final bool showSender;
  final bool firstInRun;
  final bool lastInRun;
  final List<Reaction> reactions;
  final ReadMark? readMark;

  /// "Seen", "Seen by 3" — under my latest message only.
  final String? seenLabel;
  final VoidCallback onActions;
  final VoidCallback onRetry;
  final ValueChanged<String> onReaction;
  final ValueChanged<String>? onReplyTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    final m = message;
    final failed = m.sendState == SendState.failed;
    final showMeta = lastInRun || failed || m.isEdited || seenLabel != null;

    final bubble = _Bubble(
      message: m,
      mine: mine,
      firstInRun: firstInRun,
      onReplyTap: onReplyTap,
    );

    final column = Column(
      crossAxisAlignment: mine
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showSender && firstInRun && !mine)
          Padding(
            padding: const EdgeInsets.only(left: RelaySpace.s3, bottom: 2),
            child: Text(
              m.sender?.displayName ?? 'Someone',
              style: text.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: p.textSecondary,
              ),
            ),
          ),
        GestureDetector(
          onLongPress: onActions,
          onSecondaryTap: onActions,
          child: bubble,
        ),
        if (reactions.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: RelaySpace.s1),
            child: ReactionsRow(
              reactions: reactions,
              myId: myId,
              onTap: onReaction,
            ),
          ),
        if (showMeta)
          Padding(
            padding: const EdgeInsets.only(top: 3, left: 4, right: 4),
            child: failed
                ? _FailedLine(onRetry: onRetry)
                : _MetaLine(
                    message: m,
                    readMark: mine ? readMark : null,
                    seenLabel: seenLabel,
                  ),
          ),
      ],
    );

    final maxWidth = (MediaQuery.sizeOf(context).width * 0.78).clamp(
      0.0,
      560.0,
    );
    return Padding(
      padding: EdgeInsets.only(
        left: RelaySpace.s3,
        right: RelaySpace.s3,
        top: firstInRun ? RelaySpace.s2 : 2,
      ),
      child: Row(
        mainAxisAlignment: mine
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (showSender && !mine) ...[
            SizedBox(
              width: 30,
              child: lastInRun
                  ? Padding(
                      // Align with the bubble, above the meta line.
                      padding: EdgeInsets.only(
                        bottom:
                            (showMeta ? 20.0 : 0) +
                            (reactions.isNotEmpty ? 30.0 : 0),
                      ),
                      child: RelayAvatar(
                        name: m.sender?.displayName ?? '',
                        seed: m.senderId,
                        imageUrl: m.sender?.avatarUrl,
                        size: 30,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: RelaySpace.s2),
          ],
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: column,
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.message,
    required this.mine,
    required this.firstInRun,
    this.onReplyTap,
  });

  final Message message;
  final bool mine;
  final bool firstInRun;
  final ValueChanged<String>? onReplyTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final m = message;
    const big = Radius.circular(RelayRadius.bubble);
    const small = Radius.circular(6);
    final radius = mine
        ? BorderRadius.only(
            topLeft: big,
            bottomLeft: big,
            topRight: firstInRun ? big : small,
            bottomRight: small,
          )
        : BorderRadius.only(
            topRight: big,
            bottomRight: big,
            topLeft: firstInRun ? big : small,
            bottomLeft: small,
          );
    final fg = mine ? p.onInk : p.ink;
    final bodyStyle = TextStyle(
      fontFamily: RelayFonts.sans,
      fontSize: 16,
      height: 1.45,
      color: fg,
    );

    if (m.isDeleted) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: radius,
          border: Border.all(color: p.border),
        ),
        child: Text(
          mine ? 'You deleted this message' : 'This message was deleted',
          style: bodyStyle.copyWith(
            color: p.textSubtle,
            fontStyle: FontStyle.italic,
            fontSize: 15,
          ),
        ),
      );
    }

    final a = m.attachment;
    final body = m.body;
    final isImage = a?.kind == AttachmentKind.image;
    final children = <Widget>[
      if (m.replyTo != null)
        Padding(
          padding: EdgeInsets.fromLTRB(
            isImage ? 6 : 0,
            isImage ? 6 : 0,
            isImage ? 6 : 0,
            RelaySpace.s2,
          ),
          child: ReplyQuote(
            reply: m.replyTo!,
            onDark: mine,
            onTap: onReplyTap == null ? null : () => onReplyTap!(m.replyTo!.id),
          ),
        ),
      if (a != null)
        switch (a.kind) {
          AttachmentKind.image => ImageAttachmentView(message: m),
          AttachmentKind.file => FileAttachmentView(message: m, mine: mine),
          AttachmentKind.audio => VoiceAttachmentView(message: m, mine: mine),
        },
      if (body != null && body.isNotEmpty)
        Padding(
          padding: EdgeInsets.only(
            top: a == null ? 0 : RelaySpace.s2,
            left: isImage ? 10 : 0,
            right: isImage ? 10 : 0,
            bottom: isImage ? 6 : 0,
          ),
          child: Text(body, style: bodyStyle),
        ),
    ];

    return Container(
      padding: isImage
          ? const EdgeInsets.all(4)
          : const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: mine ? p.ink : p.surface,
        borderRadius: radius,
        border: mine ? null : Border.all(color: p.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: children,
      ),
    );
  }
}

/// The quoted message above a reply (also used in the composer).
class ReplyQuote extends StatelessWidget {
  const ReplyQuote({
    super.key,
    required this.reply,
    this.onDark = false,
    this.onTap,
  });

  final ReplyPreview reply;
  final bool onDark;
  final VoidCallback? onTap;

  static String snippet(ReplyPreview r) {
    if (r.deleted) return 'Deleted message';
    if ((r.body ?? '').isNotEmpty) return r.body!.replaceAll('\n', ' ');
    return switch (r.attachmentKind) {
      AttachmentKind.image => '📷 Photo',
      AttachmentKind.audio => '🎤 Voice note',
      AttachmentKind.file => '📎 File',
      null => '',
    };
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final fg = onDark ? p.onInk : p.ink;
    final muted = onDark ? p.onInk.withValues(alpha: 0.75) : p.textMuted;
    return Semantics(
      button: onTap != null,
      label: 'Reply to ${reply.senderName ?? 'message'}: ${snippet(reply)}',
      child: GestureDetector(
        onTap: onTap,
        child: ExcludeSemantics(
          child: Container(
            padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
            decoration: BoxDecoration(
              color: onDark ? p.onInk.withValues(alpha: 0.12) : p.fillMuted,
              borderRadius: BorderRadius.circular(RelayRadius.md),
              border: Border(left: BorderSide(color: p.accent, width: 3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  reply.senderName ?? 'Message',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: RelayFonts.sans,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: fg,
                  ),
                ),
                Text(
                  snippet(reply),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: RelayFonts.sans,
                    fontSize: 13,
                    color: muted,
                    fontStyle: reply.deleted ? FontStyle.italic : null,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Reaction pills: emoji + count; mine have an ink border on a muted fill.
class ReactionsRow extends StatelessWidget {
  const ReactionsRow({
    super.key,
    required this.reactions,
    required this.myId,
    required this.onTap,
  });

  final List<Reaction> reactions;
  final String myId;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final counts = <String, int>{};
    final mine = <String>{};
    for (final r in reactions) {
      counts[r.emoji] = (counts[r.emoji] ?? 0) + 1;
      if (r.userId == myId) mine.add(r.emoji);
    }
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: [
        for (final e in counts.entries)
          Semantics(
            button: true,
            selected: mine.contains(e.key),
            label: '${e.key} ${e.value}',
            child: InkWell(
              borderRadius: BorderRadius.circular(RelayRadius.pill),
              onTap: () => onTap(e.key),
              child: ExcludeSemantics(
                child: Container(
                  height: 28,
                  padding: const EdgeInsets.symmetric(horizontal: 9),
                  decoration: BoxDecoration(
                    color: mine.contains(e.key) ? p.fillMuted : p.surface,
                    borderRadius: BorderRadius.circular(RelayRadius.pill),
                    border: Border.all(
                      color: mine.contains(e.key) ? p.ink : p.border,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(e.key, style: const TextStyle(fontSize: 13)),
                      if (e.value > 1) ...[
                        const SizedBox(width: 4),
                        Text(
                          '${e.value}',
                          style: TextStyle(
                            fontFamily: RelayFonts.sans,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: p.ink,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _MetaLine extends StatelessWidget {
  const _MetaLine({required this.message, this.readMark, this.seenLabel});

  final Message message;
  final ReadMark? readMark;
  final String? seenLabel;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final style = Theme.of(context).textTheme.bodySmall
        ?.copyWith(fontSize: 12, color: p.textSubtle);
    final parts = [
      messageTime(message.createdAt),
      if (message.isEdited) 'Edited',
      ?seenLabel,
    ];
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(child: Text(parts.join(' · '), style: style)),
        if (readMark != null) ...[
          const SizedBox(width: 4),
          switch (readMark!) {
            ReadMark.sending => Icon(
              Icons.schedule,
              size: 14,
              color: p.textSubtle,
              semanticLabel: 'Sending',
            ),
            ReadMark.sent => Icon(
              Icons.done,
              size: 14,
              color: p.textSubtle,
              semanticLabel: 'Sent',
            ),
            ReadMark.read => Icon(
              Icons.done_all,
              size: 14,
              color: p.accent,
              semanticLabel: 'Read',
            ),
          },
        ],
      ],
    );
  }
}

class _FailedLine extends StatelessWidget {
  const _FailedLine({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Semantics(
      button: true,
      label: 'Not sent. Tap to retry',
      child: InkWell(
        onTap: onRetry,
        child: ExcludeSemantics(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, size: 14, color: p.dangerText),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    'Not sent · Tap to retry',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: p.dangerText,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Hairline with a centered pill: "Today", "Yesterday", …
class DateDivider extends StatelessWidget {
  const DateDivider({super.key, required this.day});

  final DateTime day;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: RelaySpace.s4,
        vertical: RelaySpace.s3,
      ),
      child: Row(
        children: [
          Expanded(child: Divider(color: p.hairline)),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: RelaySpace.s2),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(RelayRadius.pill),
              border: Border.all(color: p.hairline),
            ),
            child: Text(
              dayLabel(day),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: p.textSubtle,
              ),
            ),
          ),
          Expanded(child: Divider(color: p.hairline)),
        ],
      ),
    );
  }
}

/// Cobalt line with a "New" label at the first unread message.
class NewMessagesDivider extends StatelessWidget {
  const NewMessagesDivider({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: RelaySpace.s4,
        vertical: RelaySpace.s2,
      ),
      child: Row(
        children: [
          Expanded(child: Container(height: 1, color: p.accent)),
          const SizedBox(width: RelaySpace.s2),
          Text(
            'New',
            style: TextStyle(
              fontFamily: RelayFonts.sans,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: p.accent,
            ),
          ),
        ],
      ),
    );
  }
}

/// Three dots in descending greys, gently pulsing.
class TypingDots extends StatefulWidget {
  const TypingDots({super.key});

  @override
  State<TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<TypingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final greys = [p.textSecondary, p.textSubtle, p.placeholder];
    return AnimatedBuilder(
      animation: _c,
      builder: (_, _) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < 3; i++)
            Container(
              width: 6,
              height: 6,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: greys[i].withValues(
                  alpha: 0.5 + 0.5 * ((_c.value * 3 - i) % 3 < 1 ? 1 : 0),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
