import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
import '../../../core/router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/ui/form_error_banner.dart';
import '../../../core/ui/relay_button.dart';
import '../../../core/ui/relay_logo.dart';
import '../../../core/ui/relay_text_field.dart';
import '../domain/auth_failure.dart';
import '../domain/validators.dart';
import 'auth_form_controller.dart';
import 'auth_layout.dart';
import 'username_field.dart';
import 'widgets/password_strength_meter.dart';

class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final _name = TextEditingController();
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _submitted = false;
  bool _needsConfirmation = false;
  String? _usernameError;

  @override
  void initState() {
    super.initState();
    // The form-state provider is shared across auth screens; start clean.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(authFormControllerProvider.notifier).clearError();
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _username.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _submitted = true);
    final name = _name.text.trim();
    final username = normalizeUsername(_username.text);
    final email = _email.text.trim();
    final password = _password.text;
    if (validateDisplayName(name) != null ||
        validateUsername(username) != null ||
        validateEmail(email) != null ||
        validatePassword(password) != null) {
      return;
    }
    TextInput.finishAutofillContext();
    await ref.read(authFormControllerProvider.notifier).run(() async {
      try {
        final result = await ref
            .read(authRepositoryProvider)
            .signUp(
              email: email,
              password: password,
              username: username,
              displayName: name,
            );
        if (mounted && result.needsEmailConfirmation) {
          setState(() => _needsConfirmation = true);
        }
      } on AuthFailure catch (failure) {
        if (failure.code != AuthFailureCode.usernameTaken) rethrow;
        if (mounted) setState(() => _usernameError = failure.message);
      }
    });
  }

  Widget _confirmation(TextTheme text) {
    final p = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const RelayLogo(),
        const SizedBox(height: RelaySpace.s6),
        Text('Check your inbox', style: text.headlineLarge),
        const SizedBox(height: RelaySpace.s2),
        Text(
          'Confirm your email, then sign in.',
          style: text.bodyMedium?.copyWith(color: p.textMuted),
        ),
        const SizedBox(height: RelaySpace.s6),
        RelayButton(
          label: 'Back to sign in',
          variant: RelayButtonVariant.secondary,
          onPressed: () => context.go(Routes.signIn),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final form = ref.watch(authFormControllerProvider);
    final text = Theme.of(context).textTheme;
    final p = context.palette;
    final nameError = _submitted ? validateDisplayName(_name.text) : null;
    final emailError = _submitted ? validateEmail(_email.text) : null;
    final passwordError = _submitted ? validatePassword(_password.text) : null;

    return Scaffold(
      body: AuthLayout(
        form: _needsConfirmation
            ? _confirmation(text)
            : AutofillGroup(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const RelayLogo(),
                    const SizedBox(height: RelaySpace.s6),
                    Text('Create your account', style: text.headlineLarge),
                    const SizedBox(height: RelaySpace.s2),
                    Text(
                      'Pick a username so your friends can find you.',
                      style: text.bodyMedium?.copyWith(color: p.textMuted),
                    ),
                    const SizedBox(height: RelaySpace.s6),
                    if (form.formError != null) ...[
                      FormErrorBanner(message: form.formError!),
                      const SizedBox(height: RelaySpace.s4),
                    ],
                    RelayTextField(
                      label: 'Name',
                      controller: _name,
                      errorText: nameError,
                      autofillHints: const [AutofillHints.name],
                      textInputAction: TextInputAction.next,
                      enabled: !form.submitting,
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: RelaySpace.s4),
                    UsernameField(
                      controller: _username,
                      submitError: _usernameError,
                      showFormatErrors: _submitted,
                      enabled: !form.submitting,
                      textInputAction: TextInputAction.next,
                      onChanged: () {
                        if (_usernameError != null) {
                          setState(() => _usernameError = null);
                        }
                      },
                    ),
                    const SizedBox(height: RelaySpace.s4),
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
                      helperText: '8+ characters with a letter and a number',
                      obscure: true,
                      autofillHints: const [AutofillHints.newPassword],
                      textInputAction: TextInputAction.done,
                      enabled: !form.submitting,
                      onChanged: (_) => setState(() {}),
                      onSubmitted: (_) => _submit(),
                    ),
                    const SizedBox(height: RelaySpace.s2),
                    PasswordStrengthMeter(
                      score: passwordStrength(_password.text),
                    ),
                    const SizedBox(height: RelaySpace.s6),
                    RelayButton(
                      label: 'Create account',
                      loading: form.submitting,
                      onPressed: _submit,
                    ),
                    const SizedBox(height: RelaySpace.s6),
                    Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          'Have an account? ',
                          style: text.bodyMedium?.copyWith(color: p.textMuted),
                        ),
                        TextButton(
                          onPressed: () => context.go(Routes.signIn),
                          child: const Text('Sign in'),
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
