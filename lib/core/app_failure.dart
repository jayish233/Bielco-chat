import 'dart:async';
import 'dart:io' show SocketException;

import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
import 'package:http/http.dart' show ClientException;
import 'package:supabase_flutter/supabase_flutter.dart';

/// A readable failure from a chat/data operation. [message] is shown as-is.
class AppFailure implements Exception {
  const AppFailure(this.message, [this.cause]);

  final String message;
  final Object? cause;

  static const network = AppFailure(
    'Can’t reach the server. Check your connection and try again.',
  );
  static const generic = AppFailure('Something went wrong. Please try again.');

  @override
  String toString() => 'AppFailure($message)';
}

/// Maps Supabase / network errors to an [AppFailure].
AppFailure mapAppError(Object error) {
  if (error is AppFailure) return error;
  if (error is SocketException ||
      error is ClientException ||
      error is TimeoutException) {
    return AppFailure.network;
  }
  if (error is PostgrestException) {
    switch (error.code) {
      case '42501':
        return AppFailure('You don’t have permission to do that.', error);
      case 'P0002':
        return AppFailure('That link or person no longer exists.', error);
      case '22023':
      case '23514':
        return AppFailure(_sentence(error.message), error);
    }
  }
  if (error is StorageException) {
    if (error.statusCode == '413') {
      return AppFailure('That file is too big (50 MB max).', error);
    }
    if (error.statusCode == '404') {
      return AppFailure('That file is no longer available.', error);
    }
    if (error.statusCode == '403') {
      return AppFailure('You don’t have permission to do that.', error);
    }
  }
  if (kDebugMode) debugPrint('AppFailure.generic caused by: $error');
  return AppFailure(AppFailure.generic.message, error);
}

String _sentence(String s) {
  if (s.isEmpty) return AppFailure.generic.message;
  final t = s[0].toUpperCase() + s.substring(1);
  return t.endsWith('.') ? t : '$t.';
}

/// Runs [body], rethrowing any error as an [AppFailure] (stack preserved).
Future<T> guard<T>(Future<T> Function() body) async {
  try {
    return await body();
  } catch (e, st) {
    Error.throwWithStackTrace(mapAppError(e), st);
  }
}
