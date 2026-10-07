import 'dart:io';

import 'package:chatapp/features/auth/data/supabase_auth_repository.dart';
import 'package:chatapp/features/auth/domain/auth_failure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' show ClientException;
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  AuthFailureCode code(Object e) => mapAuthError(e).code;

  test('duplicate username surfaced as HTTP 500 -> usernameTaken', () {
    expect(
      code(
        AuthRetryableFetchException(
          message:
              '{"code":"23505","message":"duplicate key value violates '
              'unique constraint \\"profiles_username_key\\""}',
          statusCode: '500',
        ),
      ),
      AuthFailureCode.usernameTaken,
    );
    expect(
      code(const AuthException('Database error saving new user')),
      AuthFailureCode.usernameTaken,
    );
  });

  test('network-ish errors', () {
    expect(code(AuthRetryableFetchException()), AuthFailureCode.network);
    expect(
      code(AuthRetryableFetchException(statusCode: '503')),
      AuthFailureCode.network,
    );
    expect(code(const SocketException('x')), AuthFailureCode.network);
    expect(code(ClientException('x')), AuthFailureCode.network);
  });

  test('other 5xx is unknown', () {
    expect(
      code(AuthRetryableFetchException(message: 'boom', statusCode: '500')),
      AuthFailureCode.unknown,
    );
  });

  test('codes', () {
    expect(
      code(const PostgrestException(message: 'x', code: '23505')),
      AuthFailureCode.usernameTaken,
    );
    expect(
      code(const AuthException('x', code: 'weak_password')),
      AuthFailureCode.weakPassword,
    );
    expect(
      code(const AuthException('x', code: 'email_not_confirmed')),
      AuthFailureCode.emailNotConfirmed,
    );
    expect(
      code(const AuthException('x', code: 'invalid_credentials')),
      AuthFailureCode.invalidCredentials,
    );
    expect(
      code(const AuthException('x', code: 'user_already_exists')),
      AuthFailureCode.emailTaken,
    );
  });

  test(
    'company allowlist rejections -> notAllowed (sign-up 403 and token hook)',
    () {
      expect(
        mapAuthError(
          const AuthApiException(
            "email_not_allowed: This email isn't on the company list.",
            statusCode: '403',
          ),
        ).code,
        AuthFailureCode.notAllowed,
      );
      expect(
        mapAuthError(
          AuthRetryableFetchException(
            message: 'email_not_allowed: This account no longer has access.',
            statusCode: '500',
          ),
        ).code,
        AuthFailureCode.notAllowed,
      );
    },
  );

  test('unknown keeps the cause', () {
    final err = StateError('boom');
    final f = mapAuthError(err);
    expect(f.code, AuthFailureCode.unknown);
    expect(f.cause, same(err));
  });
}
