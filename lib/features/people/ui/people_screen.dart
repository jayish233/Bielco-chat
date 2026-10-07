import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/app_failure.dart';
import '../../../core/providers.dart';
import '../../../core/router.dart';
import '../../../core/theme/app_theme.dart';
import '../../profile/domain/profile.dart';
import 'people_list.dart';

/// Opens (or creates) the DM with [person] and navigates to it.
Future<void> openDm(BuildContext context, WidgetRef ref, Profile person) async {
  try {
    final id = await ref
        .read(conversationRepositoryProvider)
        .getOrCreateDm(person.id);
    if (context.mounted) context.go(Routes.chat(id));
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(mapAppError(e).message)));
    }
  }
}

/// Directory of everyone, with a "Message" shortcut.
class PeopleScreen extends ConsumerWidget {
  const PeopleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('People'),
      ),
      body: PeopleList(
        rowBuilder: (context, person, online) => PersonTile(
          person: person,
          online: online,
          onTap: () => openDm(context, ref, person),
          trailing: OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: p.ink,
              side: BorderSide(color: p.border),
              minimumSize: const Size(44, 36),
            ),
            onPressed: () => openDm(context, ref, person),
            child: Text(
              'Message',
              semanticsLabel: 'Message ${person.displayName}',
            ),
          ),
        ),
      ),
    );
  }
}
