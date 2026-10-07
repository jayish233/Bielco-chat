import 'dart:typed_data';

import '../domain/profile.dart';

abstract interface class ProfileRepository {
  Future<Profile> fetchMyProfile();
  Future<Profile> updateMyProfile({String? displayName, String? username});
  Future<bool> isUsernameAvailable(String username);

  /// Uploads a new avatar image and saves its public URL on my profile.
  Future<Profile> uploadAvatar(Uint8List bytes, {required String extension});

  /// Stamps `last_seen_at` (on app pause / sign-out).
  Future<void> touchLastSeen();
}
