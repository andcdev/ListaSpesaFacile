import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/l10n.dart';
import '../services/api_client.dart';
import '../state/auth_controller.dart';
import '../widgets/password_field.dart';
import '../widgets/ui.dart';
import 'login_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  Map<String, List<String>> _serverErrors = {};
  bool _busy = false;

  /// Informativa privacy accettata (obbligatoria) e consenso alla newsletter (facoltativo).
  bool _privacy = false;
  bool _newsletter = false;

  @override
  void dispose() {
    for (final c in [_name, _email, _password, _confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _serverErrors = {});
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await context.read<AuthController>().register(
        _name.text,
        _email.text,
        _password.text,
        privacy: _privacy,
        newsletter: _newsletter,
      );
      if (mounted) Navigator.pop(context);
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
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l.createAccount)),
      body: Wallpaper(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _name,
                    decoration: InputDecoration(labelText: l.name, errorText: _serverError('name')),
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    validator: (v) => (v == null || v.trim().isEmpty) ? l.enterYourName : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _email,
                    decoration: InputDecoration(labelText: l.email, errorText: _serverError('email')),
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    validator: (v) => isValidEmail(v ?? '') ? null : l.invalidEmail,
                  ),
                  const SizedBox(height: 16),
                  PasswordField(
                    controller: _password,
                    decoration: InputDecoration(
                      labelText: l.password,
                      helperText: l.atLeast8,
                      errorText: _serverError('password'),
                    ),
                    textInputAction: TextInputAction.next,
                    validator: (v) => (v == null || v.length < 8) ? l.atLeast8 : null,
                  ),
                  const SizedBox(height: 16),
                  PasswordField(
                    controller: _confirm,
                    decoration: InputDecoration(labelText: l.confirmPassword),
                    onFieldSubmitted: (_) => _submit(),
                    validator: (v) => v != _password.text ? l.passwordsDontMatch : null,
                  ),
                  const SizedBox(height: 16),
                  FormField<bool>(
                    validator: (_) => _privacy ? null : l.privacyRequired,
                    builder: (field) => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CheckboxListTile(
                          value: _privacy,
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                          onChanged: (v) {
                            setState(() => _privacy = v ?? false);
                            field.didChange(v);
                          },
                          title: Text.rich(
                            TextSpan(
                              text: l.acceptPrivacyPrefix,
                              children: [
                                TextSpan(
                                  text: l.privacyPolicy,
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.primary,
                                    decoration: TextDecoration.underline,
                                  ),
                                  recognizer: TapGestureRecognizer()..onTap = openPrivacyPolicy,
                                ),
                                TextSpan(text: l.acceptPrivacySuffix),
                              ],
                            ),
                          ),
                        ),
                        if (field.errorText != null || _serverError('privacy') != null)
                          Padding(
                            padding: const EdgeInsets.only(left: 12),
                            child: Text(
                              field.errorText ?? _serverError('privacy')!,
                              style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12),
                            ),
                          ),
                      ],
                    ),
                  ),
                  CheckboxListTile(
                    value: _newsletter,
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    onChanged: (v) => setState(() => _newsletter = v ?? false),
                    title: Text(l.newsletterConsent),
                    subtitle: Text(l.newsletterOptional),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _busy ? null : _submit,
                    child: _busy
                        ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : Text(l.signUp),
                  ),
                  const SizedBox(height: 24),
                  const SocialLoginSection(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
