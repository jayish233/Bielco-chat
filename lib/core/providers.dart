import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../features/auth/data/auth_repository.dart';
import '../features/auth/data/supabase_auth_repository.dart';
import '../features/profile/data/profile_repository.dart';
import '../features/profile/data/supabase_profile_repository.dart';
import '../features/profile/domain/profile.dart';

final supabaseClientProvider = Provider<SupabaseClient>(
  (ref) => Supabase.instance.client,
);

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => SupabaseAuthRepository(ref.watch(supabaseClientProvider)),
);

final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => SupabaseProfileRepository(ref.watch(supabaseClientProvider)),
);

/// Seeds with the current status, then follows changes.
final authStatusProvider = StreamProvider<AuthStatus>((ref) async* {
  final repo = ref.watch(authRepositoryProvider);
  yield repo.currentStatus;
  yield* repo.statusChanges();
});

/// Only meaningful while signed in (the profile screen is only shown then).
/// When signed out it fails with `StateError('Not signed in')` instead of
/// querying; it refetches whenever the auth status changes.
final myProfileProvider = FutureProvider<Profile>((ref) async {
  final status = await ref.watch(authStatusProvider.future);
  if (status == AuthStatus.signedOut) throw StateError('Not signed in');
  return ref.watch(profileRepositoryProvider).fetchMyProfile();
});
