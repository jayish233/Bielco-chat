import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/tokens.dart';

const quickReactions = ['👍', '❤️', '😂', '😮', '😢', '🙏'];

enum MessageAction { reply, copy, edit, delete, retry }

/// Result of the actions sheet: an action, or a reaction emoji.
typedef MessageActionResult = ({MessageAction? action, String? emoji});

/// Bottom sheet for a message: quick reactions + reply/copy/edit/delete.
Future<MessageActionResult?> showMessageActions(
  BuildContext context, {
  required bool canReact,
  required bool canReply,
  required bool canCopy,
  required bool canEdit,
  required bool canDelete,
  bool canRetry = false,
}) {
  return showModalBottomSheet<MessageActionResult>(
    context: context,
    builder: (context) {
      final p = context.palette;
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (canReact)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  RelaySpace.s4,
                  0,
                  RelaySpace.s4,
                  RelaySpace.s2,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    for (final e in quickReactions)
                      Semantics(
                        button: true,
                        label: 'React $e',
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () =>
                              Navigator.pop(context, (action: null, emoji: e)),
                          child: ExcludeSemantics(
                            child: Container(
                              width: 48,
                              height: 48,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: p.fillMuted,
                              ),
                              child: Text(
                                e,
                                style: const TextStyle(fontSize: 24),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            if (canRetry)
              _tile(context, Icons.refresh, 'Retry', MessageAction.retry),
            if (canReply)
              _tile(context, Icons.reply, 'Reply', MessageAction.reply),
            if (canCopy)
              _tile(context, Icons.copy, 'Copy text', MessageAction.copy),
            if (canEdit)
              _tile(context, Icons.edit_outlined, 'Edit', MessageAction.edit),
            if (canDelete)
              _tile(
                context,
                Icons.delete_outline,
                'Delete',
                MessageAction.delete,
                danger: true,
              ),
            const SizedBox(height: RelaySpace.s2),
          ],
        ),
      );
    },
  );
}

Widget _tile(
  BuildContext context,
  IconData icon,
  String label,
  MessageAction action, {
  bool danger = false,
}) {
  final color = danger ? context.palette.dangerText : null;
  return ListTile(
    leading: Icon(icon, color: color),
    title: Text(label, style: TextStyle(color: color)),
    onTap: () => Navigator.pop(context, (action: action, emoji: null)),
  );
}

/// "Delete for everyone?" confirmation.
Future<bool> confirmDelete(BuildContext context) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Delete message?'),
      content: const Text('It will be removed for everyone in this chat.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          style: TextButton.styleFrom(
            foregroundColor: context.palette.dangerText,
          ),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  return ok ?? false;
}
