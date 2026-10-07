import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/app_failure.dart';
import '../../../core/env.dart';
import '../../../core/providers.dart';
import '../../../core/router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/ui/relay_text_field.dart';
import '../../people/ui/people_list.dart';
import '../../people/ui/people_screen.dart' show openDm;
import 'conversation_list_controller.dart';

void _back(BuildContext context) =>
    context.canPop() ? context.pop() : context.go(Routes.home);

/// Start a DM (tap a person), create a group, or join with a link.
class NewChatScreen extends ConsumerWidget {
  const NewChatScreen({super.key});

  Future<void> _joinWithLink(BuildContext context) async {
    final controller = TextEditingController();
    final token = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Join with a link'),
        content: RelayTextField(
          label: 'Invite link',
          controller: controller,
          hintText: 'Paste the link you were sent',
          autocorrect: false,
          keyboardType: TextInputType.url,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (token == null || !context.mounted) return;
    final parsed = AppLinks.tokenFrom(token);
    if (parsed == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('That doesn’t look like an invite link.')),
      );
      return;
    }
    context.go(Routes.join(parsed));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    Widget action(IconData icon, String label, VoidCallback onTap) => ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: RelaySpace.s4),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: p.ink,
          borderRadius: BorderRadius.circular(
            context.metrics.circularAvatars ? 20 : 12,
          ),
        ),
        child: Icon(icon, color: p.onInk, size: 20),
      ),
      title: Text(
        label,
        style: Theme.of(context).textTheme.bodyLarge
            ?.copyWith(fontWeight: FontWeight.w500),
      ),
    );

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Close',
          icon: const Icon(Icons.close),
          onPressed: () => _back(context),
        ),
        title: const Text('New chat'),
      ),
      body: SafeArea(
        child: PeopleList(
          autofocus: true,
          header: [
            action(
              Icons.group_add_outlined,
              'New group',
              () => context.push(Routes.newGroup),
            ),
            action(
              Icons.link,
              'Join with a link',
              () => _joinWithLink(context),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                RelaySpace.s4,
                RelaySpace.s4,
                RelaySpace.s4,
                RelaySpace.s1,
              ),
              child: Text(
                'PEOPLE',
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ),
          ],
          rowBuilder: (context, person, online) => PersonTile(
            person: person,
            online: online,
            onTap: () => openDm(context, ref, person),
          ),
        ),
      ),
    );
  }
}

/// Group name + member selection.
class NewGroupScreen extends ConsumerStatefulWidget {
  const NewGroupScreen({super.key});

  @override
  ConsumerState<NewGroupScreen> createState() => _NewGroupScreenState();
}

class _NewGroupScreenState extends ConsumerState<NewGroupScreen> {
  final _name = TextEditingController();
  Set<String> _selected = {};
  bool _busy = false;
  String? _nameError;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final name = _name.text.trim();
    if (name.isEmpty || name.length > 80) {
      setState(
        () => _nameError = 'Give the group a name (up to 80 characters).',
      );
      return;
    }
    setState(() {
      _busy = true;
      _nameError = null;
    });
    try {
      final id = await ref
          .read(conversationRepositoryProvider)
          .createGroup(name, _selected.toList());
      await ref.read(conversationListProvider.notifier).refresh();
      if (mounted) context.go(Routes.chat(id));
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(mapAppError(e).message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final n = _selected.length;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => _back(context),
        ),
        title: const Text('New group'),
        actions: [
          TextButton(
            onPressed: _busy ? null : _create,
            child: Text(_busy ? 'Creating…' : 'Create'),
          ),
          const SizedBox(width: RelaySpace.s2),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                RelaySpace.s4,
                RelaySpace.s4,
                RelaySpace.s4,
                0,
              ),
              child: RelayTextField(
                label: 'Group name',
                controller: _name,
                hintText: 'e.g. Weekend plans',
                errorText: _nameError,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _create(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                RelaySpace.s4,
                RelaySpace.s4,
                RelaySpace.s4,
                0,
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  n == 0 ? 'ADD PEOPLE' : 'ADD PEOPLE · $n SELECTED',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ),
            ),
            Expanded(
              child: PeoplePicker(
                selected: _selected,
                onChanged: (s) => setState(() => _selected = s),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Admins add people to an existing group.
class AddMembersScreen extends ConsumerStatefulWidget {
  const AddMembersScreen({
    super.key,
    required this.conversationId,
    required this.existing,
  });

  final String conversationId;
  final Set<String> existing;

  @override
  ConsumerState<AddMembersScreen> createState() => _AddMembersScreenState();
}

class _AddMembersScreenState extends ConsumerState<AddMembersScreen> {
  Set<String> _selected = {};
  bool _busy = false;

  Future<void> _add() async {
    if (_selected.isEmpty) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(conversationRepositoryProvider)
          .addMembers(widget.conversationId, _selected.toList());
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(mapAppError(e).message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Close',
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(false),
        ),
        title: const Text('Add people'),
        actions: [
          TextButton(
            onPressed: _busy || _selected.isEmpty ? null : _add,
            child: Text(
              _selected.isEmpty ? 'Add' : 'Add (${_selected.length})',
            ),
          ),
          const SizedBox(width: RelaySpace.s2),
        ],
      ),
      body: SafeArea(
        child: PeoplePicker(
          selected: _selected,
          exclude: widget.existing,
          onChanged: (s) => setState(() => _selected = s),
        ),
      ),
    );
  }
}
