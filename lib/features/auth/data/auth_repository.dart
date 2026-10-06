enum AuthStatus { signedIn, signedOut }

class SignUpResult {
  const SignUpResult({required this.needsEmailConfirmation});
  final bool needsEmailConfirmation;
}

abstract interface class AuthRepository {
  AuthStatus get currentStatus;
  String? get currentUserId;
  String? get currentEmail;

  /// Emits status changes only (deduplicated, no replay of the current value).
  Stream<AuthStatus> statusChanges();

  Future<void> signIn({required String email, required String password});

  Future<SignUpResult> signUp({
    required String email,
    required String password,
    required String username,
    required String displayName,
  });

  Future<void> signOut();
}
