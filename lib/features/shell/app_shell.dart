import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/ui/relay_avatar.dart';
import '../../core/ui/relay_button.dart';
import '../../core/ui/relay_logo.dart';
import '../conversations/ui/conversation_list_controller.dart';

/// Signed-in frame: a black nav rail when wide, a bottom bar on phones.
/// Also keeps me "online" and stamps last-seen when the app goes to the
/// background.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key, required this.location, required this.child});

  final String location;
  final Widget child;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Signs out right away if access was revoked since the last session.
    ref.read(authRepositoryProvider).revalidate();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      ref.read(profileRepositoryProvider).touchLastSeen();
    } else if (state == AppLifecycleState.resumed) {
      ref.read(authRepositoryProvider).revalidate();
      ref.read(conversationListProvider.notifier).refresh();
    }
  }

  int get _tab => widget.location.startsWith(Routes.people) ? 1 : 0;

  void _go(int i) => context.go(i == 0 ? Routes.home : Routes.people);

  @override
  Widget build(BuildContext context) {
    // Announces me as online while signed in.
    ref.watch(onlineUsersProvider);
    final unread = ref.watch(totalUnreadProvider);

    if (isWide(context)) {
      return Scaffold(
        body: Row(
          children: [
            _NavRail(selected: _tab, unread: unread, onSelect: _go),
            Expanded(child: widget.child),
          ],
        ),
      );
    }
    final showBar =
        widget.location == Routes.home || widget.location == Routes.people;
    return Scaffold(
      body: widget.child,
      bottomNavigationBar: showBar
          ? DecoratedBox(
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: context.palette.hairline),
                ),
              ),
              child: NavigationBar(
                selectedIndex: _tab,
                onDestinationSelected: _go,
                destinations: [
                  NavigationDestination(
                    icon: Badge(
                      isLabelVisible: unread > 0,
                      backgroundColor: context.palette.accent,
                      label: Text(unread > 99 ? '99+' : '$unread'),
                      child: const Icon(Icons.chat_bubble_outline),
                    ),
                    selectedIcon: const Icon(Icons.chat_bubble),
                    label: 'Chats',
                  ),
                  const NavigationDestination(
                    icon: Icon(Icons.people_outline),
                    selectedIcon: Icon(Icons.people),
                    label: 'People',
                  ),
                ],
              ),
            )
          : null,
    );
  }
}

class _NavRail extends ConsumerWidget {
  const _NavRail({
    required this.selected,
    required this.unread,
    required this.onSelect,
  });

  final int selected;
  final int unread;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(myProfileProvider).asData?.value;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final bg = dark ? RelayColors.darkSurfaceAlt : RelayColors.ink;

    Widget item(int i, IconData icon, IconData activeIcon, String label) {
      final active = selected == i;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: RelaySpace.s1),
        child: Tooltip(
          message: label,
          child: Semantics(
            button: true,
            selected: active,
            label: unread > 0 && i == 0 ? '$label, $unread unread' : label,
            child: InkWell(
              borderRadius: BorderRadius.circular(RelayRadius.lg),
              onTap: () => onSelect(i),
              child: ExcludeSemantics(
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: active
                        ? RelayColors.surface.withValues(alpha: 0.14)
                        : null,
                    borderRadius: BorderRadius.circular(RelayRadius.lg),
                  ),
                  child: Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.center,
                    children: [
                      Icon(
                        active ? activeIcon : icon,
                        color: active
                            ? RelayColors.surface
                            : RelayColors.placeholder,
                      ),
                      if (i == 0 && unread > 0)
                        Positioned(
                          top: 4,
                          right: 2,
                          child: UnreadBadge(count: unread, small: true),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      width: 72,
      color: bg,
      child: SafeArea(
        right: false,
        child: Column(
          children: [
            const SizedBox(height: RelaySpace.s4),
            const RelayLogo(size: 36, inverted: true),
            const SizedBox(height: RelaySpace.s6),
            item(0, Icons.chat_bubble_outline, Icons.chat_bubble, 'Chats'),
            item(1, Icons.people_outline, Icons.people, 'People'),
            const Spacer(),
            Tooltip(
              message: 'Your profile',
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => context.push(Routes.profile),
                child: Padding(
                  padding: const EdgeInsets.all(RelaySpace.s2),
                  child: RelayAvatar(
                    name: profile?.displayName ?? '',
                    seed: profile?.id ?? '',
                    imageUrl: profile?.avatarUrl,
                    size: 36,
                  ),
                ),
              ),
            ),
            const SizedBox(height: RelaySpace.s4),
          ],
        ),
      ),
    );
  }
}

/// Right pane of the wide layout before a chat is picked.
class NoChatSelected extends StatelessWidget {
  const NoChatSelected({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const RelayLogo(size: 48),
            const SizedBox(height: RelaySpace.s4),
            Text('Pick a chat', style: text.titleMedium),
            const SizedBox(height: RelaySpace.s1),
            Text(
              'Or start a new one with the pencil button.',
              style: text.bodyMedium?.copyWith(
                color: context.palette.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class NotFoundScreen extends StatelessWidget {
  const NotFoundScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(RelaySpace.s6),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Page not found', style: text.titleMedium),
                const SizedBox(height: RelaySpace.s2),
                Text(
                  'That link doesn’t go anywhere.',
                  style: text.bodyMedium?.copyWith(
                    color: context.palette.textSecondary,
                  ),
                ),
                const SizedBox(height: RelaySpace.s5),
                RelayButton(
                  label: 'Go to chats',
                  onPressed: () => context.go(Routes.home),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
