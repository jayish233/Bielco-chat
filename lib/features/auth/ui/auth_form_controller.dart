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

  /// Runs [action] unless a submit is already in flight. [AuthFailure]s
  /// become [AuthFormState.formError]; other errors show the generic message.
  Future<void> run(Future<void> Function() action) async {
    if (state.submitting) return;
    state = const AuthFormState(submitting: true);
    try {
      await action();
    } on AuthFailure catch (failure) {
      state = AuthFormState(submitting: true, formError: failure.message);
    } catch (error, stack) {
      debugPrint('Unexpected auth error: $error\n$stack');
      state = AuthFormState(
        submitting: true,
        formError: const AuthFailure(AuthFailureCode.unknown).message,
      );
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
