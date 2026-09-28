import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/l10n.dart';
import '../services/api_client.dart';
import '../state/auth_controller.dart';
import '../widgets/password_field.dart';
import '../widgets/ui.dart';

/// Recupero della password in due passi: email → codice di 6 cifre ricevuto via email + nuova password.
/// Al termine si è già dentro l'app. Serve anche a chi si era registrato con Google o Facebook
/// e vuole accedere con email e password.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key, this.email = ''});

  final String email;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _form = GlobalKey<FormState>();
  late final _email = TextEditingController(text: widget.email);
  final _code = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  Map<String, List<String>> _serverErrors = {};
  bool _codeSent = false;
  bool _busy = false;

  @override
  void dispose() {
    for (final c in [_email, _code, _password, _confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _sendCode() async {
    setState(() => _serverErrors = {});
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      final message = await context.read<AuthController>().forgotPassword(_email.text);
      if (!mounted) return;
      setState(() => _codeSent = true);
      showMessage(context, message);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _serverErrors = e.errors);
      if (e.errors.isEmpty) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reset() async {
    setState(() => _serverErrors = {});
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    final navigator = Navigator.of(context);
    try {
      await context.read<AuthController>().resetPassword(_email.text, _code.text, _password.text);
      // Accesso fatto: si torna alla schermata principale (le liste).
      navigator.popUntil((route) => route.isFirst);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _serverErrors = e.errors);
      if (e.errors.isEmpty) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String? _serverError(String field) => _serverErrors[field]?.first;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l.forgotPasswordTitle)),
      body: Wallpaper(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(_codeSent ? l.resetCodeSentInfo : l.resetInfo, style: theme.textTheme.bodyMedium),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _email,
                    readOnly: _codeSent,
                    decoration: InputDecoration(labelText: l.email, errorText: _serverError('email')),
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    textInputAction: TextInputAction.next,
                    onFieldSubmitted: (_) => _codeSent ? null : _sendCode(),
                    validator: (v) => (v == null || !v.contains('@')) ? l.invalidEmail : null,
                  ),
                  if (_codeSent) ...[
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _code,
                      autofocus: true,
                      decoration: InputDecoration(
                        labelText: l.resetCodeLabel,
                        counterText: '',
                        errorText: _serverError('code'),
                      ),
                      keyboardType: TextInputType.number,
                      autofillHints: const [AutofillHints.oneTimeCode],
                      maxLength: 6,
                      textInputAction: TextInputAction.next,
                      validator: (v) => RegExp(r'^\d{6}$').hasMatch(v?.trim() ?? '') ? null : l.resetCodeInvalid,
                    ),
                    const SizedBox(height: 16),
                    PasswordField(
                      controller: _password,
                      decoration: InputDecoration(
                        labelText: l.newPassword,
                        helperText: l.atLeast8,
                        errorText: _serverError('password'),
                      ),
                      autofillHints: const [AutofillHints.newPassword],
                      textInputAction: TextInputAction.next,
                      validator: (v) => (v == null || v.length < 8) ? l.atLeast8 : null,
                    ),
                    const SizedBox(height: 16),
                    PasswordField(
                      controller: _confirm,
                      decoration: InputDecoration(labelText: l.confirmPassword),
                      onFieldSubmitted: (_) => _reset(),
                      validator: (v) => v != _password.text ? l.passwordsDontMatch : null,
                    ),
                  ],
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _busy ? null : (_codeSent ? _reset : _sendCode),
                    child: _busy
                        ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : Text(_codeSent ? l.setNewPassword : l.sendCode),
                  ),
                  if (_codeSent) ...[
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => setState(() {
                              _codeSent = false;
                              _code.clear();
                            }),
                      child: Text(l.resendCode),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
