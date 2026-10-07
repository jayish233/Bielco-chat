import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_failure.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/ui/relay_avatar.dart';
import '../../../core/ui/relay_button.dart';
import '../../../core/ui/skeleton.dart';
import '../../conversations/ui/chat_list_pane.dart' show SearchField;
import '../../profile/domain/profile.dart';

/// Everyone (except me) matching a search term.
final peopleSearchProvider = FutureProvider.autoDispose
    .family<List<Profile>, String>(
      (ref, query) =>
          ref.watch(peopleRepositoryProvider).searchPeople(query: query),
    );

/// Search box + list of people. Each row gets a [trailing] built by the caller.
class PeopleList extends ConsumerStatefulWidget {
  const PeopleList({
    super.key,
    required this.rowBuilder,
    this.header,
    this.exclude = const {},
    this.autofocus = false,
  });

  final Widget Function(BuildContext context, Profile person, bool online)
  rowBuilder;

  /// Rows shown above the results (e.g. "New group").
  final List<Widget>? header;

  /// Ids to hide (e.g. people already in the group).
  final Set<String> exclude;
  final bool autofocus;

  @override
  ConsumerState<PeopleList> createState() => _PeopleListState();
}

class _PeopleListState extends ConsumerState<PeopleList> {
  final _search = TextEditingController();
  Timer? _debounce;
  String _query = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      if (mounted) setState(() => _query = v.trim());
    });
  }

  @override
  Widget build(BuildContext context) {
    final people = ref.watch(peopleSearchProvider(_query));
    final online = ref.watch(onlineUsersProvider).asData?.value ?? const {};
    final p = context.palette;
    final text = Theme.of(context).textTheme;

    final Widget results = people.when(
      loading: () => Column(
        key: const ValueKey('people-skeleton'),
        children: [
          for (var i = 0; i < 5; i++)
            const Padding(
              padding: EdgeInsets.symmetric(
                horizontal: RelaySpace.s4,
                vertical: RelaySpace.s3,
              ),
              child: Row(
                children: [
                  SkeletonBlock(width: 40, height: 40),
                  SizedBox(width: RelaySpace.s3),
                  Expanded(child: SkeletonBlock(height: 14)),
                ],
              ),
            ),
        ],
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.all(RelaySpace.s6),
        child: Column(
          children: [
            Text(mapAppError(e).message, textAlign: TextAlign.center),
            const SizedBox(height: RelaySpace.s4),
            RelayButton(
              label: 'Try again',
              variant: RelayButtonVariant.secondary,
              onPressed: () => ref.invalidate(peopleSearchProvider(_query)),
            ),
          ],
        ),
      ),
      data: (list) {
        final shown = [
          for (final x in list)
            if (!widget.exclude.contains(x.id)) x,
        ];
        if (shown.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(RelaySpace.s6),
            child: Text(
              _query.isEmpty
                  ? 'No one else is here yet. Share the app with your group.'
                  : 'No one matches “$_query”.',
              textAlign: TextAlign.center,
              style: text.bodyMedium?.copyWith(color: p.textMuted),
            ),
          );
        }
        return Column(
          children: [
            for (final person in shown)
              widget.rowBuilder(context, person, online.contains(person.id)),
          ],
        );
      },
    );

    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            RelaySpace.s4,
            RelaySpace.s3,
            RelaySpace.s4,
            RelaySpace.s2,
          ),
          child: SearchField(
            controller: _search,
            hint: 'Search by name or @username',
            onChanged: _onChanged,
            autofocus: widget.autofocus,
          ),
        ),
        ...?widget.header,
        results,
      ],
    );
  }
}

/// Avatar + name + @username, with a caller-provided trailing widget.
class PersonTile extends StatelessWidget {
  const PersonTile({
    super.key,
    required this.person,
    required this.online,
    this.trailing,
    this.onTap,
    this.subtitle,
  });

  final Profile person;
  final bool online;
  final Widget? trailing;
  final VoidCallback? onTap;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: RelaySpace.s4),
      minVerticalPadding: RelaySpace.s3,
      leading: RelayAvatar(
        name: person.displayName,
        seed: person.id,
        imageUrl: person.avatarUrl,
        size: 40,
        online: online ? true : null,
      ),
      title: Text(
        person.displayName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.bodyLarge
            ?.copyWith(fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        subtitle ?? '@${person.username}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: trailing,
    );
  }
}

/// Pick several people (new group, add members). Returns via [onDone].
class PeoplePicker extends StatefulWidget {
  const PeoplePicker({
    super.key,
    required this.selected,
    required this.onChanged,
    this.exclude = const {},
  });

  final Set<String> selected;
  final ValueChanged<Set<String>> onChanged;
  final Set<String> exclude;

  @override
  State<PeoplePicker> createState() => _PeoplePickerState();
}

class _PeoplePickerState extends State<PeoplePicker> {
  @override
  Widget build(BuildContext context) {
    return PeopleList(
      exclude: widget.exclude,
      rowBuilder: (context, person, online) {
        final on = widget.selected.contains(person.id);
        void toggle() {
          final next = {...widget.selected};
          on ? next.remove(person.id) : next.add(person.id);
          widget.onChanged(next);
        }

        return PersonTile(
          person: person,
          online: online,
          onTap: toggle,
          trailing: Checkbox(
            value: on,
            onChanged: (_) => toggle(),
            semanticLabel: 'Select ${person.displayName}',
          ),
        );
      },
    );
  }
}
