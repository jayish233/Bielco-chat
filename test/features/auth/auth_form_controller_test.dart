import 'dart:async';

import 'package:chatapp/features/auth/domain/auth_failure.dart';
import 'package:chatapp/features/auth/ui/auth_form_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late ProviderContainer container;
  setUp(() {
    container = ProviderContainer();
    addTearDown(container.dispose);
    container.listen(authFormControllerProvider, (_, _) {});
  });

  test('second run while submitting is ignored; submitting resets', () async {
    final gate = Completer<void>();
    var calls = 0;
    final ctrl = container.read(authFormControllerProvider.notifier);
    final first = ctrl.run(() async {
      calls++;
      await gate.future;
    });
    await ctrl.run(() async => calls++);
    expect(calls, 1);
    expect(container.read(authFormControllerProvider).submitting, isTrue);
    gate.complete();
    await first;
    expect(container.read(authFormControllerProvider).submitting, isFalse);
  });

  test('AuthFailure sets formError and resets submitting', () async {
    await container
        .read(authFormControllerProvider.notifier)
        .run(() async => throw const AuthFailure(AuthFailureCode.network));
    final s = container.read(authFormControllerProvider);
    expect(s.submitting, isFalse);
    expect(s.formError, const AuthFailure(AuthFailureCode.network).message);
  });

  test('failure after disposal does not throw', () async {
    final c = ProviderContainer();
    final sub = c.listen(authFormControllerProvider, (_, _) {});
    final gate = Completer<void>();
    final f = c.read(authFormControllerProvider.notifier).run(() async {
      await gate.future;
      throw const AuthFailure(AuthFailureCode.network);
    });
    sub.close();
    c.dispose();
    gate.complete();
    await f;
  });
}
