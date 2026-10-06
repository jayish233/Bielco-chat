import 'package:chatapp/core/router.dart';
import 'package:chatapp/features/auth/data/auth_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('signed out is sent to sign-in unless on an auth route', () {
    expect(
      authRedirect(status: AuthStatus.signedOut, location: '/'),
      Routes.signIn,
    );
    expect(
      authRedirect(status: AuthStatus.signedOut, location: '/profile'),
      Routes.signIn,
    );
    expect(
      authRedirect(status: AuthStatus.signedOut, location: '/sign-up'),
      isNull,
    );
    expect(
      authRedirect(status: AuthStatus.signedOut, location: '/sign-in'),
      isNull,
    );
  });

  test('signed in is sent home from auth routes only', () {
    expect(
      authRedirect(status: AuthStatus.signedIn, location: '/sign-in'),
      Routes.home,
    );
    expect(
      authRedirect(status: AuthStatus.signedIn, location: '/sign-up'),
      Routes.home,
    );
    expect(
      authRedirect(status: AuthStatus.signedIn, location: '/profile'),
      isNull,
    );
    expect(authRedirect(status: AuthStatus.signedIn, location: '/'), isNull);
  });
}
