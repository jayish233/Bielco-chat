import 'dart:async';
import 'dart:io' show SocketException;

import 'package:http/http.dart' show ClientException;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/auth_failure.dart';
import '../domain/validators.dart';
import 'auth_repository.dart';

/// Maps any thrown error from Supabase/network layers to an [AuthFailure].
AuthFailure mapAuthError(Object error) {
  if (error is AuthFailure) return error;
  if (error is AuthRetryableFetchException ||
      error is SocketException ||
      error is ClientException) {
    return const AuthFailure(AuthFailureCode.network);
  }
  if (error is AuthException) {
    switch (error.code) {
      case 'invalid_credentials':
        return const AuthFailure(AuthFailureCode.invalidCredentials);
      case 'user_already_exists':
      case 'email_exists':
        return const AuthFailure(AuthFailureCode.emailTaken);
      case 'weak_password':
        return const AuthFailure(AuthFailureCode.weakPassword);
      case 'email_not_confirmed':
        return const AuthFailure(AuthFailureCode.emailNotConfirmed);
    }
    if (error is AuthWeakPasswordException) {
      return const AuthFailure(AuthFailureCode.weakPassword);
    }
    if (error.message.contains('Database error saving new user')) {
      return const AuthFailure(AuthFailureCode.usernameTaken);
    }
    return const AuthFailure(AuthFailureCode.unknown);
  }
  if (error is PostgrestException) {
    if (error.code == '23505') {
      return const AuthFailure(AuthFailureCode.usernameTaken);
    }
    return const AuthFailure(AuthFailureCode.unknown);
  }
  return const AuthFailure(AuthFailureCode.unknown);
}

class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(this._client);

  final SupabaseClient _client;

  GoTrueClient get _auth => _client.auth;

  AuthStatus _statusOf(Session? s) =>
      s == null ? AuthStatus.signedOut : AuthStatus.signedIn;

  @override
  AuthStatus get currentStatus => _statusOf(_auth.currentSession);

  @override
  String? get currentUserId => _auth.currentUser?.id;

  @override
  String? get currentEmail => _auth.currentUser?.email;

  @override
  Stream<AuthStatus> statusChanges() {
    late StreamController<AuthStatus> controller;
    StreamSubscription<AuthState>? sub;
    controller = StreamController<AuthStatus>(
      onListen: () {
        // Captured synchronously on listen (an async* body would start late).
        var last = currentStatus;
        // onAuthStateChange is a ReplaySubject: it replays past events on
        // listen. Reading the live session (not the event's) makes replays
        // harmless.
        sub = _auth.onAuthStateChange.listen((_) {
          final next = currentStatus;
          if (next == last) return;
          last = next;
          controller.add(next);
        }, onError: (Object _) {});
      },
      onCancel: () => sub?.cancel(),
    );
    return controller.stream;
  }

  @override
  Future<void> signIn({required String email, required String password}) async {
    try {
      await _auth.signInWithPassword(email: email.trim(), password: password);
    } catch (e) {
      throw mapAuthError(e);
    }
  }

  @override
  Future<SignUpResult> signUp({
    required String email,
    required String password,
    required String username,
    required String displayName,
  }) async {
    final name = normalizeUsername(username);
    try {
      final available = await _client.rpc(
        'username_available',
        params: {'name': name},
      );
      if (available == false) {
        throw const AuthFailure(AuthFailureCode.usernameTaken);
      }
      final res = await _auth.signUp(
        email: email.trim(),
        password: password,
        data: {'username': name, 'display_name': displayName.trim()},
      );
      return SignUpResult(needsEmailConfirmation: res.session == null);
    } catch (e) {
      throw mapAuthError(e);
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      throw mapAuthError(e);
    }
  }
}
