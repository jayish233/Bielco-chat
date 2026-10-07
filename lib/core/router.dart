import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/data/auth_repository.dart';
import '../features/auth/ui/sign_in_screen.dart';
import '../features/auth/ui/sign_up_screen.dart';
import '../features/chat/ui/chat_screen.dart';
import '../features/conversations/ui/chat_list_pane.dart';
import '../features/conversations/ui/group_info_screen.dart';
import '../features/conversations/ui/join_invite_screen.dart';
import '../features/conversations/ui/new_chat_screen.dart';
import '../features/people/ui/people_screen.dart';
import '../features/profile/ui/profile_screen.dart';
import '../features/shell/app_shell.dart';
import 'providers.dart';

abstract final class Routes {
  static const signIn = '/sign-in';
  static const signUp = '/sign-up';
  static const home = '/';
  static const profile = '/profile';
  static const people = '/people';
  static const newChat = '/new';
  static const newGroup = '/new/group';
  static String chat(String id) => '/c/$id';
  static String groupInfo(String id) => '/c/$id/info';
  static String join(String token) => '/join/$token';
}

const _authRoutes = {Routes.signIn, Routes.signUp};

/// Signed out and not on an auth route -> sign-in; signed in and on an auth
/// route -> home; otherwise no redirect.
String? authRedirect({required AuthStatus status, required String location}) {
  final onAuthRoute = _authRoutes.contains(location);
  if (status == AuthStatus.signedOut && !onAuthRoute) return Routes.signIn;
  if (status == AuthStatus.signedIn && onAuthRoute) return Routes.home;
  return null;
}

/// Notifies listeners whenever [stream] emits (used as `refreshListenable`).
class StreamListenable extends ChangeNotifier {
  StreamListenable(Stream<Object?> stream) {
    _sub = stream.listen((_) => notifyListeners());
  }

  late final StreamSubscription<Object?> _sub;

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

/// Page that animates like a normal push on phones but swaps instantly in
/// the wide split view (where the list stays put and only the pane changes).
Page<void> _adaptivePage(GoRouterState state, Widget child) =>
    CustomTransitionPage<void>(
      key: state.pageKey,
      child: child,
      transitionsBuilder: (context, animation, secondary, child) {
        if (isWide(context)) return child;
        return Theme.of(context).pageTransitionsTheme.buildTransitions(
          ModalRoute.of(context) as PageRoute<void>,
          context,
          animation,
          secondary,
          child,
        );
      },
    );

final routerProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authRepositoryProvider);
  final refresh = StreamListenable(auth.statusChanges());
  final rootKey = GlobalKey<NavigatorState>();
  final shellKey = GlobalKey<NavigatorState>();
  // An invite opened while signed out is resumed after signing in.
  String? pendingInvite;

  final router = GoRouter(
    navigatorKey: rootKey,
    initialLocation: Routes.home,
    refreshListenable: refresh,
    redirect: (context, state) {
      final location = state.uri.path;
      final status = auth.currentStatus;
      if (status == AuthStatus.signedOut && location.startsWith('/join/')) {
        pendingInvite = location;
      }
      final target = authRedirect(status: status, location: location);
      if (target == Routes.home && pendingInvite != null) {
        final resume = pendingInvite;
        pendingInvite = null;
        return resume;
      }
      return target;
    },
    errorBuilder: (_, _) => const NotFoundScreen(),
    routes: [
      GoRoute(path: Routes.signIn, builder: (_, _) => const SignInScreen()),
      GoRoute(path: Routes.signUp, builder: (_, _) => const SignUpScreen()),
      ShellRoute(
        navigatorKey: shellKey,
        builder: (_, state, child) =>
            AppShell(location: state.uri.path, child: child),
        routes: [
          GoRoute(
            path: Routes.home,
            pageBuilder: (_, state) =>
                NoTransitionPage(key: state.pageKey, child: const ChatsHome()),
            routes: [
              GoRoute(
                path: 'c/:id',
                pageBuilder: (_, state) => _adaptivePage(
                  state,
                  ChatsHome(selectedId: state.pathParameters['id']),
                ),
                routes: [
                  GoRoute(
                    path: 'info',
                    parentNavigatorKey: rootKey,
                    builder: (_, state) => GroupInfoScreen(
                      conversationId: state.pathParameters['id']!,
                    ),
                  ),
                ],
              ),
            ],
          ),
          GoRoute(
            path: Routes.people,
            pageBuilder: (_, state) => NoTransitionPage(
              key: state.pageKey,
              child: const PeopleScreen(),
            ),
          ),
        ],
      ),
      GoRoute(
        path: Routes.profile,
        parentNavigatorKey: rootKey,
        builder: (_, _) => const ProfileScreen(),
      ),
      GoRoute(
        path: Routes.newChat,
        parentNavigatorKey: rootKey,
        builder: (_, _) => const NewChatScreen(),
        routes: [
          GoRoute(
            path: 'group',
            parentNavigatorKey: rootKey,
            builder: (_, _) => const NewGroupScreen(),
          ),
        ],
      ),
      GoRoute(
        path: '/join/:token',
        parentNavigatorKey: rootKey,
        builder: (_, state) =>
            JoinInviteScreen(token: state.pathParameters['token']!),
      ),
    ],
  );
  ref.onDispose(() {
    router.dispose();
    refresh.dispose();
  });
  return router;
});

/// Wide layout (nav rail + list + chat side by side).
bool isWide(BuildContext context) => MediaQuery.sizeOf(context).width >= 840;

/// Chats tab: the list on phones; list + open chat side by side when wide.
class ChatsHome extends StatelessWidget {
  const ChatsHome({super.key, this.selectedId});

  final String? selectedId;

  @override
  Widget build(BuildContext context) {
    final id = selectedId;
    if (!isWide(context)) {
      return id == null
          ? const ChatListPane()
          : ChatScreen(key: ValueKey(id), conversationId: id);
    }
    final p = Theme.of(context).dividerColor;
    return Row(
      children: [
        SizedBox(width: 340, child: ChatListPane(selectedId: id)),
        VerticalDivider(width: 1, color: p),
        Expanded(
          child: id == null
              ? const NoChatSelected()
              : ChatScreen(
                  key: ValueKey(id),
                  conversationId: id,
                  embedded: true,
                ),
        ),
      ],
    );
  }
}
