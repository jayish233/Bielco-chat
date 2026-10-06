import 'dart:async';

import 'package:chatapp/features/auth/data/auth_repository.dart';
import 'package:chatapp/features/auth/domain/validators.dart';
import 'package:chatapp/features/profile/data/profile_repository.dart';
import 'package:chatapp/features/profile/domain/profile.dart';

class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({this._status = AuthStatus.signedOut});

  AuthStatus _status;
  final _controller = StreamController<AuthStatus>.broadcast();

  final List<({String email, String password})> signInCalls = [];
  final List<
    ({String email, String password, String username, String displayName})
  >
  signUpCalls = [];
  int signOutCalls = 0;

  Object? nextError;
  Completer<void>? signInGate;
  SignUpResult signUpResult = const SignUpResult(needsEmailConfirmation: false);

  @override
  String? currentUserId;
  @override
  String? currentEmail;

  @override
  AuthStatus get currentStatus => _status;

  @override
  Stream<AuthStatus> statusChanges() => _controller.stream;

  /// Updates [currentStatus] first, then broadcasts (if changed).
  void emit(AuthStatus status) {
    if (status == _status) return;
    _status = status;
    _controller.add(status);
  }

  void _throwIfError() {
    final e = nextError;
    if (e != null) {
      nextError = null;
      throw e;
    }
  }

  @override
  Future<void> signIn({required String email, required String password}) async {
    signInCalls.add((email: email, password: password));
    final gate = signInGate;
    if (gate != null) await gate.future;
    _throwIfError();
    emit(AuthStatus.signedIn);
  }

  @override
  Future<SignUpResult> signUp({
    required String email,
    required String password,
    required String username,
    required String displayName,
  }) async {
    signUpCalls.add((
      email: email,
      password: password,
      username: username,
      displayName: displayName,
    ));
    _throwIfError();
    if (!signUpResult.needsEmailConfirmation) emit(AuthStatus.signedIn);
    return signUpResult;
  }

  @override
  Future<void> signOut() async {
    signOutCalls++;
    emit(AuthStatus.signedOut);
  }

  Future<void> dispose() => _controller.close();
}

class FakeProfileRepository implements ProfileRepository {
  FakeProfileRepository({this.profile});

  Profile? profile;
  Object? loadError;
  Object? nextError;
  Set<String> takenUsernames = {};
  final List<({String? displayName, String? username})> updateCalls = [];

  @override
  Future<Profile> fetchMyProfile() async {
    final e = loadError;
    if (e != null) throw e;
    return profile!;
  }

  @override
  Future<Profile> updateMyProfile({
    String? displayName,
    String? username,
  }) async {
    final e = nextError;
    if (e != null) {
      nextError = null;
      throw e;
    }
    updateCalls.add((displayName: displayName, username: username));
    return profile = profile!.copyWith(
      displayName: displayName,
      username: username == null ? null : normalizeUsername(username),
    );
  }

  @override
  Future<bool> isUsernameAvailable(String username) async =>
      !takenUsernames.contains(normalizeUsername(username));
}
