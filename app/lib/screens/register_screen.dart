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
      await context.read<AuthController>().register(_name.text, _email.text, _password.text);
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
                    validator: (v) => (v == null || !v.contains('@')) ? l.invalidEmail : null,
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
                  const SizedBox(height: 24),
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
