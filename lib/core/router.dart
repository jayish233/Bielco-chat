import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/data/auth_repository.dart';
import '../features/auth/ui/sign_in_screen.dart';
import '../features/auth/ui/sign_up_screen.dart';
import '../features/home/ui/home_screen.dart';
import '../features/profile/ui/profile_screen.dart';
import 'providers.dart';

abstract final class Routes {
  static const signIn = '/sign-in';
  static const signUp = '/sign-up';
  static const home = '/';
  static const profile = '/profile';
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

final routerProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authRepositoryProvider);
  final refresh = StreamListenable(auth.statusChanges());
  final router = GoRouter(
    initialLocation: Routes.home,
    refreshListenable: refresh,
    redirect: (context, state) =>
        authRedirect(status: auth.currentStatus, location: state.uri.path),
    routes: [
      GoRoute(path: Routes.home, builder: (_, _) => const HomeScreen()),
      GoRoute(path: Routes.signIn, builder: (_, _) => const SignInScreen()),
      GoRoute(path: Routes.signUp, builder: (_, _) => const SignUpScreen()),
      GoRoute(path: Routes.profile, builder: (_, _) => const ProfileScreen()),
    ],
  );
  ref.onDispose(() {
    router.dispose();
    refresh.dispose();
  });
  return router;
});
