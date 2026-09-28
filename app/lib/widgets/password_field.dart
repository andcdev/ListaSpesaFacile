import 'package:flutter/material.dart';

import '../l10n/l10n.dart';

/// Campo password con l'occhio per vedere (o nascondere di nuovo) quello che si sta scrivendo.
class PasswordField extends StatefulWidget {
  const PasswordField({
    super.key,
    required this.controller,
    this.decoration = const InputDecoration(),
    this.autofillHints,
    this.textInputAction,
    this.onFieldSubmitted,
    this.validator,
  });

  final TextEditingController controller;
  final InputDecoration decoration;
  final Iterable<String>? autofillHints;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onFieldSubmitted;
  final FormFieldValidator<String>? validator;

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _visible = false;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      obscureText: !_visible,
      enableSuggestions: false,
      autocorrect: false,
      autofillHints: widget.autofillHints,
      textInputAction: widget.textInputAction,
      onFieldSubmitted: widget.onFieldSubmitted,
      validator: widget.validator,
      decoration: widget.decoration.copyWith(
        suffixIcon: IconButton(
          icon: Icon(_visible ? Icons.visibility_off_outlined : Icons.visibility_outlined),
          tooltip: _visible ? context.l10n.hidePassword : context.l10n.showPassword,
          onPressed: () => setState(() => _visible = !_visible),
        ),
      ),
    );
  }
}
