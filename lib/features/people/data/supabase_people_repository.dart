import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/app_failure.dart';
import '../../profile/domain/profile.dart';
import 'people_repository.dart';

class SupabasePeopleRepository implements PeopleRepository {
  SupabasePeopleRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<Profile>> searchPeople({String query = ''}) => guard(() async {
    var q = _client
        .from('profiles')
        .select()
        .neq('id', _client.auth.currentUser!.id);
    // Strip characters that have meaning in a PostgREST `or` filter.
    final term = query.trim().replaceAll(RegExp(r'[,()*%\\]'), '');
    if (term.isNotEmpty) {
      q = q.or('display_name.ilike.%$term%,username.ilike.%$term%');
    }
    final rows = await q.order('display_name').limit(200);
    return [for (final r in rows) Profile.fromJson(r)];
  });
}
