import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../features/auth/data/auth_repository.dart';
import '../features/auth/data/supabase_auth_repository.dart';
import '../features/chat/data/message_repository.dart';
import '../features/chat/data/presence_service.dart';
import '../features/chat/data/supabase_message_repository.dart';
import '../features/chat/data/supabase_presence_service.dart';
import '../features/conversations/data/conversation_repository.dart';
import '../features/conversations/data/supabase_conversation_repository.dart';
import '../features/people/data/people_repository.dart';
import '../features/people/data/supabase_people_repository.dart';
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

final conversationRepositoryProvider = Provider<ConversationRepository>(
  (ref) => SupabaseConversationRepository(ref.watch(supabaseClientProvider)),
);

final messageRepositoryProvider = Provider<MessageRepository>(
  (ref) => SupabaseMessageRepository(ref.watch(supabaseClientProvider)),
);

final peopleRepositoryProvider = Provider<PeopleRepository>(
  (ref) => SupabasePeopleRepository(ref.watch(supabaseClientProvider)),
);

final presenceServiceProvider = Provider<PresenceService>(
  (ref) => SupabasePresenceService(ref.watch(supabaseClientProvider)),
);

/// Seeds with the current status, then follows changes.
final authStatusProvider = StreamProvider<AuthStatus>((ref) async* {
  final repo = ref.watch(authRepositoryProvider);
  yield repo.currentStatus;
  yield* repo.statusChanges();
});

/// My user id while signed in, else null. Follows sign-in/out.
final myUserIdProvider = Provider<String?>((ref) {
  final status = ref.watch(authStatusProvider).asData?.value;
  if (status != AuthStatus.signedIn) return null;
  return ref.watch(authRepositoryProvider).currentUserId;
});

/// Only meaningful while signed in (the profile screen is only shown then).
/// When signed out it fails with `StateError('Not signed in')` instead of
/// querying; it refetches whenever the auth status changes.
final myProfileProvider = FutureProvider<Profile>((ref) async {
  final status = await ref.watch(authStatusProvider.future);
  if (status == AuthStatus.signedOut) throw StateError('Not signed in');
  return ref.watch(profileRepositoryProvider).fetchMyProfile();
});

/// Ids of people with the app open right now. Empty while signed out.
final onlineUsersProvider = StreamProvider<Set<String>>((ref) {
  if (ref.watch(myUserIdProvider) == null) return Stream.value(const {});
  return ref.watch(presenceServiceProvider).watchOnline();
});

/// Realtime connection state, for the offline banner.
final connectionProvider = StreamProvider<bool>((ref) {
  if (ref.watch(myUserIdProvider) == null) return Stream.value(true);
  return ref.watch(presenceServiceProvider).watchConnection();
});
