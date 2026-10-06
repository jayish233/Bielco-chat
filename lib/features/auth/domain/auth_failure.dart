enum AuthFailureCode {
  invalidCredentials,
  emailTaken,
  usernameTaken,
  weakPassword,
  emailNotConfirmed,
  network,
  unknown,
}

class AuthFailure implements Exception {
  const AuthFailure(this.code);

  final AuthFailureCode code;

  String get message => switch (code) {
    AuthFailureCode.invalidCredentials => 'Email or password is incorrect.',
    AuthFailureCode.emailTaken => 'An account with this email already exists.',
    AuthFailureCode.usernameTaken => 'That username is taken.',
    AuthFailureCode.weakPassword =>
      'Use 8+ characters with a letter and a number.',
    AuthFailureCode.emailNotConfirmed =>
      'Confirm your email first — check your inbox.',
    AuthFailureCode.network =>
      'Can’t reach the server. Check your connection and try again.',
    AuthFailureCode.unknown => 'Something went wrong. Please try again.',
  };

  @override
  String toString() => 'AuthFailure($code)';
}
