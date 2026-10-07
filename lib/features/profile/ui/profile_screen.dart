import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/app_failure.dart';
import '../../../core/providers.dart';
import '../../../core/router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/ui/form_error_banner.dart';
import '../../../core/ui/relay_avatar.dart';
import '../../../core/ui/relay_button.dart';
import '../../../core/ui/relay_text_field.dart';
import '../../auth/domain/auth_failure.dart';
import '../../auth/domain/validators.dart';
import '../../auth/ui/auth_form_controller.dart';
import '../../auth/ui/username_field.dart';
import '../../chat/ui/media_picker.dart' show pickAvatar;
import '../domain/profile.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  void _back(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(Routes.home);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(myProfileProvider);
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => _back(context),
        ),
        title: const Text('Profile'),
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: profile.when(
              data: (p) => _ProfileForm(profile: p),
              loading: () => const _Skeleton(),
              error: (_, _) => Padding(
                padding: const EdgeInsets.all(RelaySpace.s6),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Couldn’t load your profile.',
                      style: text.bodyLarge,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: RelaySpace.s4),
                    RelayButton(
                      label: 'Try again',
                      variant: RelayButtonVariant.secondary,
                      onPressed: () => ref.invalidate(myProfileProvider),
                    ),
                    const SizedBox(height: RelaySpace.s3),
                    RelayButton(
                      label: 'Sign out',
                      variant: RelayButtonVariant.secondary,
                      onPressed: () =>
                          ref.read(authRepositoryProvider).signOut(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Skeleton extends StatelessWidget {
  const _Skeleton();

  Widget _block(BuildContext context, double height, {double? width}) =>
      Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: context.palette.fillMuted,
          borderRadius: BorderRadius.circular(RelayRadius.lg),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: const ValueKey('profile-skeleton'),
      padding: const EdgeInsets.all(RelaySpace.s6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(child: _block(context, 72, width: 72)),
          const SizedBox(height: RelaySpace.s6),
          for (var i = 0; i < 3; i++) ...[
            _block(context, 48),
            const SizedBox(height: RelaySpace.s4),
          ],
        ],
      ),
    );
  }
}

class _ProfileForm extends ConsumerStatefulWidget {
  const _ProfileForm({required this.profile});

  final Profile profile;

  @override
  ConsumerState<_ProfileForm> createState() => _ProfileFormState();
}

class _ProfileFormState extends ConsumerState<_ProfileForm> {
  late final TextEditingController _name;
  late final TextEditingController _username;
  late final TextEditingController _email;

  /// Last loaded or saved values; edits are compared against these.
  late String _baseName;
  late String _baseUsername;
  String? _nameError;
  String? _usernameError;

  @override
  void initState() {
    super.initState();
    // The form-state provider is shared across auth screens; start clean.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(authFormControllerProvider.notifier).clearError();
    });
    _baseName = widget.profile.displayName;
    _baseUsername = widget.profile.username;
    _name = TextEditingController(text: _baseName);
    _username = TextEditingController(text: _baseUsername);
    _email = TextEditingController(
      text: ref.read(authRepositoryProvider).currentEmail ?? '',
    );
  }

  @override
  void dispose() {
    _name.dispose();
    _username.dispose();
    _email.dispose();
    super.dispose();
  }

  bool _uploading = false;

  Future<void> _changePhoto() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final picked = await pickAvatar();
      if (picked == null) return;
      setState(() => _uploading = true);
      await ref
          .read(profileRepositoryProvider)
          .uploadAvatar(picked.bytes, extension: picked.extension);
      ref.invalidate(myProfileProvider);
      messenger.showSnackBar(const SnackBar(content: Text('Photo updated')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(mapAppError(e).message)));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  bool get _nameChanged => _name.text.trim() != _baseName;
  bool get _usernameChanged =>
      normalizeUsername(_username.text) != _baseUsername;
  bool get _dirty => _nameChanged || _usernameChanged;

  Future<void> _save() async {
    final name = _name.text.trim();
    final username = normalizeUsername(_username.text);
    final nameError = _nameChanged ? validateDisplayName(name) : null;
    final usernameError = _usernameChanged ? validateUsername(username) : null;
    if (nameError != null || usernameError != null) {
      setState(() {
        _nameError = nameError;
        _usernameError = usernameError;
      });
      return;
    }
    setState(() {
      _nameError = null;
      _usernameError = null;
    });
    final messenger = ScaffoldMessenger.of(context);
    await ref.read(authFormControllerProvider.notifier).run(() async {
      try {
        final saved = await ref
            .read(profileRepositoryProvider)
            .updateMyProfile(
              displayName: _nameChanged ? name : null,
              username: _usernameChanged ? username : null,
            );
        ref.invalidate(myProfileProvider);
        if (!mounted) return;
        setState(() {
          _baseName = saved.displayName;
          _baseUsername = saved.username;
        });
        messenger.showSnackBar(
          const SnackBar(content: Text('Profile updated')),
        );
      } on AuthFailure catch (failure) {
        if (failure.code != AuthFailureCode.usernameTaken) rethrow;
        if (mounted) setState(() => _usernameError = failure.message);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final form = ref.watch(authFormControllerProvider);
    final p = widget.profile;
    return ListView(
      padding: const EdgeInsets.all(RelaySpace.s6),
      children: [
        Align(
          child: RelayAvatar(
            name: _name.text.trim().isEmpty ? p.displayName : _name.text,
            seed: p.id,
            imageUrl: p.avatarUrl,
            size: 72,
          ),
        ),
        Align(
          child: TextButton(
            onPressed: _uploading || form.submitting ? null : _changePhoto,
            child: Text(_uploading ? 'Uploading…' : 'Change photo'),
          ),
        ),
        const SizedBox(height: RelaySpace.s6),
        if (form.formError != null) ...[
          FormErrorBanner(message: form.formError!),
          const SizedBox(height: RelaySpace.s4),
        ],
        RelayTextField(
          label: 'Name',
          controller: _name,
          errorText: _nameError,
          autofillHints: const [AutofillHints.name],
          textInputAction: TextInputAction.next,
          enabled: !form.submitting,
          onChanged: (_) => setState(() => _nameError = null),
        ),
        const SizedBox(height: RelaySpace.s4),
        UsernameField(
          controller: _username,
          currentUsername: _baseUsername,
          submitError: _usernameError,
          enabled: !form.submitting,
          textInputAction: TextInputAction.done,
          onChanged: () => setState(() => _usernameError = null),
        ),
        const SizedBox(height: RelaySpace.s4),
        RelayTextField(
          label: 'Email',
          controller: _email,
          readOnly: true,
          autocorrect: false,
        ),
        const SizedBox(height: RelaySpace.s6),
        RelayButton(
          label: 'Save changes',
          loading: form.submitting,
          onPressed: _dirty ? _save : null,
        ),
        const SizedBox(height: RelaySpace.s3),
        RelayButton(
          label: 'Sign out',
          variant: RelayButtonVariant.secondary,
          onPressed: form.submitting
              ? null
              : () =>
                    ref.read(authFormControllerProvider.notifier).run(() async {
                      await ref.read(profileRepositoryProvider).touchLastSeen();
                      await ref.read(authRepositoryProvider).signOut();
                    }),
        ),
      ],
    );
  }
}
