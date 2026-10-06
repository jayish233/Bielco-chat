import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/data/supabase_auth_repository.dart' show mapAuthError;
import '../../auth/domain/auth_failure.dart';
import '../../auth/domain/validators.dart';
import '../domain/profile.dart';
import 'profile_repository.dart';

class SupabaseProfileRepository implements ProfileRepository {
  SupabaseProfileRepository(this._client);

  final SupabaseClient _client;

  String get _uid {
    final id = _client.auth.currentUser?.id;
    if (id == null) throw const AuthFailure(AuthFailureCode.unknown);
    return id;
  }

  @override
  Future<Profile> fetchMyProfile() async {
    try {
      final row = await _client
          .from('profiles')
          .select()
          .eq('id', _uid)
          .single();
      return Profile.fromJson(row);
    } catch (e, st) {
      Error.throwWithStackTrace(mapAuthError(e), st);
    }
  }

  @override
  Future<Profile> updateMyProfile({
    String? displayName,
    String? username,
  }) async {
    final patch = <String, dynamic>{
      if (displayName != null) 'display_name': displayName.trim(),
      if (username != null) 'username': normalizeUsername(username),
    };
    try {
      if (patch.isEmpty) return await fetchMyProfile();
      final row = await _client
          .from('profiles')
          .update(patch)
          .eq('id', _uid)
          .select()
          .single();
      return Profile.fromJson(row);
    } catch (e, st) {
      Error.throwWithStackTrace(mapAuthError(e), st);
    }
  }

  @override
  Future<bool> isUsernameAvailable(String username) async {
    try {
      final res = await _client.rpc(
        'username_available',
        params: {'name': normalizeUsername(username)},
      );
      return res == true;
    } catch (e, st) {
      Error.throwWithStackTrace(mapAuthError(e), st);
    }
  }
}
