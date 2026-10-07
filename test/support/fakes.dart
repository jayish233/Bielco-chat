import 'dart:async';
import 'dart:typed_data';

import 'package:chatapp/features/auth/data/auth_repository.dart';
import 'package:chatapp/features/auth/domain/auth_failure.dart';
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

  /// Fresh stream per call, changes only (like the real repository).
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
    currentEmail = email.trim();
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

  int revalidateCalls = 0;

  @override
  Future<void> revalidate() async => revalidateCalls++;

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

  /// Normalized values passed to [isUsernameAvailable], in call order.
  final List<String> availabilityCalls = [];

  /// When set for a normalized value, its availability check waits on the gate.
  final Map<String, Completer<bool>> availabilityGates = {};

  @override
  Future<Profile> fetchMyProfile() async {
    final e = loadError;
    if (e != null) throw e;
    final p = profile;
    if (p == null) throw StateError('No profile set on FakeProfileRepository');
    return p;
  }

  @override
  Future<Profile> updateMyProfile({
    String? displayName,
    String? username,
  }) async {
    updateCalls.add((displayName: displayName, username: username));
    final e = nextError;
    if (e != null) {
      nextError = null;
      throw e;
    }
    if (username != null &&
        takenUsernames.contains(normalizeUsername(username))) {
      throw const AuthFailure(AuthFailureCode.usernameTaken);
    }
    return profile = profile!.copyWith(
      displayName: displayName,
      username: username == null ? null : normalizeUsername(username),
    );
  }

  @override
  Future<bool> isUsernameAvailable(String username) async {
    final value = normalizeUsername(username);
    availabilityCalls.add(value);
    final gate = availabilityGates[value];
    if (gate != null) return gate.future;
    return !takenUsernames.contains(value);
  }

  int avatarUploads = 0;
  int lastSeenTouches = 0;

  @override
  Future<Profile> uploadAvatar(
    Uint8List bytes, {
    required String extension,
  }) async {
    avatarUploads++;
    return profile = profile!.copyWith(avatarUrl: 'https://x/a.$extension');
  }

  @override
  Future<void> touchLastSeen() async => lastSeenTouches++;
}
