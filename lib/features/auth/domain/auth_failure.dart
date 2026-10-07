enum AuthFailureCode {
  invalidCredentials,
  emailTaken,
  usernameTaken,
  weakPassword,
  emailNotConfirmed,

  /// The email isn't on the company allowlist (or was removed from it).
  notAllowed,
  network,
  unknown,
}

class AuthFailure implements Exception {
  const AuthFailure(this.code, [this.cause]);

  final AuthFailureCode code;

  /// The underlying error, when known (kept for diagnostics).
  final Object? cause;

  String get message => switch (code) {
    AuthFailureCode.invalidCredentials => 'Email or password is incorrect.',
    AuthFailureCode.emailTaken => 'An account with this email already exists.',
    AuthFailureCode.usernameTaken => 'That username is taken.',
    AuthFailureCode.weakPassword =>
      'Use 8+ characters with a letter and a number.',
    AuthFailureCode.emailNotConfirmed =>
      'Confirm your email first — check your inbox.',
    AuthFailureCode.notAllowed =>
      'Relay is for company accounts only. Ask your admin to add your email.',
    AuthFailureCode.network =>
      'Can’t reach the server. Check your connection and try again.',
    AuthFailureCode.unknown => 'Something went wrong. Please try again.',
  };

  @override
  String toString() => 'AuthFailure($code)';
}
