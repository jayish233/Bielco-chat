import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants.dart';
import '../../../core/providers.dart';
import '../../../core/router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/ui/form_error_banner.dart';
import '../../../core/ui/relay_button.dart';
import '../../../core/ui/relay_logo.dart';
import '../../../core/ui/relay_text_field.dart';
import '../domain/validators.dart';
import 'auth_form_controller.dart';
import 'auth_layout.dart';

class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _submitted = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    setState(() => _submitted = true);
    final email = _email.text.trim();
    final password = _password.text;
    if (validateEmail(email) != null || validatePassword(password) != null) {
      return;
    }
    TextInput.finishAutofillContext();
    ref
        .read(authFormControllerProvider.notifier)
        .run(
          () => ref
              .read(authRepositoryProvider)
              .signIn(email: email, password: password),
        );
  }

  @override
  Widget build(BuildContext context) {
    final form = ref.watch(authFormControllerProvider);
    final text = Theme.of(context).textTheme;
    final p = context.palette;
    final emailError = _submitted ? validateEmail(_email.text) : null;
    final passwordError = _submitted ? validatePassword(_password.text) : null;

    return Scaffold(
      body: AuthLayout(
        form: AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const RelayLogo(),
              const SizedBox(height: RelaySpace.s6),
              Text('Welcome back', style: text.headlineLarge),
              const SizedBox(height: RelaySpace.s2),
              Text(
                'Pick up your conversations where you left off.',
                style: text.bodyMedium?.copyWith(color: p.textMuted),
              ),
              const SizedBox(height: RelaySpace.s6),
              if (form.formError != null) ...[
                FormErrorBanner(message: form.formError!),
                const SizedBox(height: RelaySpace.s4),
              ],
              RelayTextField(
                label: 'Email',
                controller: _email,
                errorText: emailError,
                autocorrect: false,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                textInputAction: TextInputAction.next,
                enabled: !form.submitting,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: RelaySpace.s4),
              RelayTextField(
                label: 'Password',
                controller: _password,
                errorText: passwordError,
                obscure: true,
                autofillHints: const [AutofillHints.password],
                textInputAction: TextInputAction.done,
                enabled: !form.submitting,
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: RelaySpace.s6),
              RelayButton(
                label: 'Sign in',
                loading: form.submitting,
                onPressed: _submit,
              ),
              const SizedBox(height: RelaySpace.s6),
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    'New to $appName? ',
                    style: text.bodyMedium?.copyWith(color: p.textMuted),
                  ),
                  TextButton(
                    onPressed: () => context.go(Routes.signUp),
                    child: const Text('Create account'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
