import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/ui/relay_text_field.dart';
import '../domain/validators.dart';

/// Username input with a debounced availability check.
///
/// The format error shows once the user has typed 3+ characters, or when
/// [showFormatErrors] is true (after the first submit). The availability RPC
/// only runs for valid formats, since it also returns false for invalid ones.
class UsernameField extends ConsumerStatefulWidget {
  const UsernameField({
    super.key,
    required this.controller,
    this.submitError,
    this.currentUsername,
    this.showFormatErrors = false,
    this.enabled = true,
    this.textInputAction,
    this.onChanged,
  });

  final TextEditingController controller;

  /// Error from a failed submit (e.g. a server-side username race).
  final String? submitError;

  /// The user's existing username; matching it skips the availability check.
  final String? currentUsername;
  final bool showFormatErrors;
  final bool enabled;
  final TextInputAction? textInputAction;
  final VoidCallback? onChanged;

  @override
  ConsumerState<UsernameField> createState() => _UsernameFieldState();
}

class _UsernameFieldState extends ConsumerState<UsernameField> {
  static const _debounce = Duration(milliseconds: 400);

  Timer? _timer;
  late String _lastText;

  /// Normalized value the current [_available] result is for.
  String? _checkedFor;
  bool? _available;

  @override
  void initState() {
    super.initState();
    _lastText = widget.controller.text;
    widget.controller.addListener(_onController);
  }

  @override
  void didUpdateWidget(UsernameField old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.removeListener(_onController);
      widget.controller.addListener(_onController);
      _lastText = widget.controller.text;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    widget.controller.removeListener(_onController);
    super.dispose();
  }

  String get _normalized => normalizeUsername(widget.controller.text);

  void _onController() {
    final text = widget.controller.text;
    if (text == _lastText) return;
    _lastText = text;
    _timer?.cancel();
    setState(() {
      _available = null;
      _checkedFor = null;
    });
    widget.onChanged?.call();
    final value = _normalized;
    if (validateUsername(value) != null || value == widget.currentUsername) {
      return;
    }
    _timer = Timer(_debounce, () => _check(value));
  }

  Future<void> _check(String value) async {
    bool available;
    try {
      available = await ref
          .read(profileRepositoryProvider)
          .isUsernameAvailable(value);
    } catch (_) {
      return; // Best effort; the server re-checks on submit.
    }
    // Ignore stale responses for an older value.
    if (!mounted || value != _normalized) return;
    setState(() {
      _checkedFor = value;
      _available = available;
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final value = _normalized;
    final isCurrent = value == widget.currentUsername;
    String? formatError;
    if (!isCurrent && (widget.showFormatErrors || value.length >= 3)) {
      formatError = validateUsername(value);
    }
    final checked = !isCurrent && _checkedFor == value ? _available : null;
    final error =
        widget.submitError ??
        formatError ??
        (checked == false ? 'That username is taken.' : null);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RelayTextField(
          label: 'Username',
          controller: widget.controller,
          prefix: Text('@', style: TextStyle(color: p.textMuted)),
          errorText: error,
          autocorrect: false,
          autofillHints: const [AutofillHints.newUsername],
          textInputAction: widget.textInputAction,
          enabled: widget.enabled,
        ),
        if (error == null && checked == true) ...[
          const SizedBox(height: RelaySpace.s2),
          Row(
            children: [
              Icon(Icons.check, size: 16, color: p.textMuted),
              const SizedBox(width: RelaySpace.s1),
              Text(
                '@$value is available',
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: p.textMuted),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
