import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/auth_failure.dart';

class AuthFormState {
  const AuthFormState({this.submitting = false, this.formError});

  final bool submitting;
  final String? formError;
}

/// Shared submit state for the auth forms (sign in, sign up, ...).
class AuthFormController extends Notifier<AuthFormState> {
  @override
  AuthFormState build() => const AuthFormState();

  /// Drops a stale [AuthFormState.formError] (e.g. left by another screen that
  /// shares this provider) without touching an in-flight submit.
  void clearError() {
    if (state.formError == null) return;
    state = AuthFormState(submitting: state.submitting);
  }

  /// Runs [action] unless a submit is already in flight. [AuthFailure]s
  /// become [AuthFormState.formError]; other errors show the generic message.
  Future<void> run(Future<void> Function() action) async {
    if (state.submitting) return;
    state = const AuthFormState(submitting: true);
    try {
      await action();
    } on AuthFailure catch (failure) {
      if (ref.mounted) {
        state = AuthFormState(submitting: true, formError: failure.message);
      }
    } catch (error, stack) {
      if (kDebugMode) debugPrint('Unexpected auth error: $error\n$stack');
      if (ref.mounted) {
        state = AuthFormState(
          submitting: true,
          formError: const AuthFailure(AuthFailureCode.unknown).message,
        );
      }
    } finally {
      // The provider may have been disposed while the action was awaiting.
      if (ref.mounted) {
        state = AuthFormState(formError: state.formError);
      }
    }
  }
}

final authFormControllerProvider =
    NotifierProvider.autoDispose<AuthFormController, AuthFormState>(
      AuthFormController.new,
    );
