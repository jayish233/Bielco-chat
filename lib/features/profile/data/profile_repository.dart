import '../domain/profile.dart';

abstract interface class ProfileRepository {
  Future<Profile> fetchMyProfile();
  Future<Profile> updateMyProfile({String? displayName, String? username});
  Future<bool> isUsernameAvailable(String username);
}
