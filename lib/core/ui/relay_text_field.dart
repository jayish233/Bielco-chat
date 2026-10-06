import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/tokens.dart';

/// Web-style text field: label above, 2px accent focus ring, inline error.
class RelayTextField extends StatefulWidget {
  const RelayTextField({
    super.key,
    required this.label,
    this.controller,
    this.hintText,
    this.errorText,
    this.helperText,
    this.prefix,
    this.obscure = false,
    this.keyboardType,
    this.autofillHints,
    this.textInputAction,
    this.onChanged,
    this.onSubmitted,
    this.enabled = true,
    this.readOnly = false,
  });

  final String label;
  final TextEditingController? controller;
  final String? hintText;
  final String? errorText;
  final String? helperText;
  final Widget? prefix;
  final bool obscure;
  final TextInputType? keyboardType;
  final Iterable<String>? autofillHints;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool enabled;
  final bool readOnly;

  @override
  State<RelayTextField> createState() => _RelayTextFieldState();
}

class _RelayTextFieldState extends State<RelayTextField> {
  final FocusNode _focus = FocusNode();
  bool _hidden = true;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final m = context.metrics;
    final theme = Theme.of(context).textTheme;
    final hasError = widget.errorText != null;
    final focused = _focus.hasFocus;
    final radius = BorderRadius.circular(RelayRadius.lg);
    final borderColor = hasError
        ? p.danger
        : focused
        ? p.ink
        : p.borderStrong;
    final bodyStyle = theme.bodyLarge;

    final field = SizedBox(
      height: m.controlHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (focused && !hasError)
            Positioned(
              left: -2,
              top: -2,
              right: -2,
              bottom: -2,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(RelayRadius.lg + 2),
                  border: Border.all(color: p.accent, width: 2),
                ),
              ),
            ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: p.surface,
                borderRadius: radius,
                border: Border.all(color: borderColor),
              ),
              child: Row(
                children: [
                  if (widget.prefix != null)
                    Padding(
                      padding: const EdgeInsets.only(left: RelaySpace.s3),
                      child: widget.prefix,
                    ),
                  Expanded(
                    child: Semantics(
                      label: widget.label,
                      hint: widget.errorText,
                      child: TextField(
                        controller: widget.controller,
                        focusNode: _focus,
                        enabled: widget.enabled,
                        readOnly: widget.readOnly,
                        obscureText: widget.obscure && _hidden,
                        autocorrect: !widget.obscure,
                        enableSuggestions: !widget.obscure,
                        keyboardType: widget.keyboardType,
                        autofillHints: widget.autofillHints,
                        textInputAction: widget.textInputAction,
                        onChanged: widget.onChanged,
                        onSubmitted: widget.onSubmitted,
                        style: bodyStyle,
                        cursorColor: p.ink,
                        decoration: InputDecoration(
                          hintText: widget.hintText,
                          hintStyle: bodyStyle?.copyWith(color: p.placeholder),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          errorBorder: InputBorder.none,
                          disabledBorder: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: RelaySpace.s4,
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (widget.obscure)
                    IconButton(
                      tooltip: _hidden ? 'Show password' : 'Hide password',
                      constraints: BoxConstraints(
                        minWidth: m.iconButtonSize,
                        minHeight: m.iconButtonSize,
                      ),
                      onPressed: () => setState(() => _hidden = !_hidden),
                      icon: Icon(
                        _hidden
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        size: 20,
                        color: p.textMuted,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label, style: theme.labelLarge),
        const SizedBox(height: RelaySpace.s2),
        field,
        if (hasError) ...[
          const SizedBox(height: RelaySpace.s2),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.error_outline, size: 16, color: p.dangerText),
              const SizedBox(width: RelaySpace.s1),
              Expanded(
                child: Text(
                  widget.errorText!,
                  style: theme.bodySmall?.copyWith(color: p.dangerText),
                ),
              ),
            ],
          ),
        ] else if (widget.helperText != null) ...[
          const SizedBox(height: RelaySpace.s2),
          Text(widget.helperText!, style: theme.bodySmall),
        ],
      ],
    );
  }
}
