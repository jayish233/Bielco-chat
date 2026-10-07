import '../../profile/domain/profile.dart';

abstract interface class PeopleRepository {
  /// Everyone except me, by name. [query] matches name or username.
  Future<List<Profile>> searchPeople({String query = ''});
}
