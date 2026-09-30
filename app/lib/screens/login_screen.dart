import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/l10n.dart';
import '../services/social_login.dart';
import '../state/auth_controller.dart';
import '../widgets/language_picker.dart';
import '../widgets/password_field.dart';
import '../widgets/ui.dart';
import 'forgot_password_screen.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await context.read<AuthController>().login(_email.text, _password.text);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = context.l10n;
    return Scaffold(
      body: Wallpaper(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Form(
                  key: _form,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Icon(Icons.shopping_cart_outlined, size: 64, color: theme.colorScheme.primary),
                      const SizedBox(height: 12),
                      Text('Lista Spesa Facile', textAlign: TextAlign.center, style: theme.textTheme.headlineLarge),
                      const SizedBox(height: 32),
                      TextFormField(
                        controller: _email,
                        decoration: InputDecoration(labelText: l.email),
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.email],
                        textInputAction: TextInputAction.next,
                        validator: (v) => (v == null || !v.contains('@')) ? l.invalidEmail : null,
                      ),
                      const SizedBox(height: 16),
                      PasswordField(
                        controller: _password,
                        decoration: InputDecoration(labelText: l.password),
                        autofillHints: const [AutofillHints.password],
                        onFieldSubmitted: (_) => _submit(),
                        validator: (v) => (v == null || v.isEmpty) ? l.enterPassword : null,
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _busy
                              ? null
                              : () => Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => ForgotPasswordScreen(email: _email.text.trim())),
                                ),
                          child: Text(l.forgotPasswordQuestion),
                        ),
                      ),
                      const SizedBox(height: 8),
                      FilledButton(
                        onPressed: _busy ? null : _submit,
                        child: _busy
                            ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                            : Text(l.signIn),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: _busy
                            ? null
                            : () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterScreen())),
                        child: Text(l.noAccount),
                      ),
                      const SizedBox(height: 16),
                      const SocialLoginSection(),
                      const SizedBox(height: 24),
                      const LanguageTile(),
                      const ServerSettingsTile(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Permette di cambiare l'indirizzo del backend (utile tra sviluppo locale e VPS).
class ServerSettingsTile extends StatelessWidget {
  const ServerSettingsTile({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    return ListTile(
      leading: const Icon(Icons.dns_outlined),
      title: Text(context.l10n.server),
      subtitle: Text(auth.serverUrl),
      trailing: const Icon(Icons.edit_outlined),
      onTap: () async {
        final controller = TextEditingController(text: auth.serverUrl);
        final url = await showDialog<String>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(context.l10n.serverAddress),
            content: TextField(
              controller: controller,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(hintText: 'https://api.listaspesafacile.com'),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: Text(context.l10n.cancel)),
              FilledButton(onPressed: () => Navigator.pop(context, controller.text), child: Text(context.l10n.save)),
            ],
          ),
        );
        if (url != null && url.trim().isNotEmpty) await auth.setServerUrl(url);
      },
    );
  }
}

/// "oppure" + i pulsanti Continua con Google e Amazon (sempre visibili: se il server non li ha configurati lo spiegano).
/// Accede o crea l'account al primo utilizzo; usata sia nell'accesso sia nella registrazione.
class SocialLoginSection extends StatefulWidget {
  const SocialLoginSection({super.key});

  /// Mostrati anche se il server non li ha ancora configurati (toccandoli si spiega cosa manca).
  static const alwaysShown = ['google', 'amazon'];

  @override
  State<SocialLoginSection> createState() => _SocialLoginSectionState();
}

class _SocialLoginSectionState extends State<SocialLoginSection> {
  bool _busy = false;

  Future<void> _signIn(String provider, {required bool enabled}) async {
    final label = SocialLogin.labels[provider] ?? provider;
    if (!enabled) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(context.l10n.socialNotActiveTitle(label)),
          content: Text(context.l10n.socialNotActiveBody(label)),
          actions: [FilledButton(onPressed: () => Navigator.pop(context), child: Text(context.l10n.ok))],
        ),
      );
      return;
    }
    setState(() => _busy = true);
    final navigator = Navigator.of(context);
    try {
      if (await context.read<AuthController>().loginWithSocial(provider)) {
        // Anche dalla schermata di registrazione si torna alle liste.
        navigator.popUntil((route) => route.isFirst);
      }
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final enabled = context.watch<AuthController>().socialProviders;
    final providers = [
      ...SocialLoginSection.alwaysShown,
      ...enabled.where((p) => !SocialLoginSection.alwaysShown.contains(p)),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(child: Divider()),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Text(context.l10n.or)),
            const Expanded(child: Divider()),
          ],
        ),
        const SizedBox(height: 16),
        for (final provider in providers)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: SocialButton(
              provider: provider,
              onPressed: _busy ? null : () => _signIn(provider, enabled: enabled.contains(provider)),
            ),
          ),
        // Con Google o Amazon l'account si crea al primo accesso: l'informativa si accetta continuando.
        Text.rich(
          TextSpan(
            text: context.l10n.socialPrivacyNotice,
            children: [
              TextSpan(
                text: context.l10n.privacyPolicy,
                style: TextStyle(color: Theme.of(context).colorScheme.primary, decoration: TextDecoration.underline),
                recognizer: TapGestureRecognizer()..onTap = openPrivacyPolicy,
              ),
            ],
          ),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

/// "Continua con Google / Amazon" con il logo ufficiale: accede o crea l'account al primo utilizzo.
class SocialButton extends StatelessWidget {
  const SocialButton({super.key, required this.provider, required this.onPressed});

  final String provider;
  final VoidCallback? onPressed;

  /// Logo ufficiale del provider (assets/logos/).
  static const _logos = {'google': 'assets/logos/google.png', 'amazon': 'assets/logos/amazon.png'};

  @override
  Widget build(BuildContext context) {
    final logo = _logos[provider];
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
      child: Row(
        children: [
          SizedBox.square(
            dimension: 24,
            child: logo == null
                ? const Icon(Icons.login, size: 20)
                : ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Image.asset(logo, fit: BoxFit.contain, filterQuality: FilterQuality.medium),
                  ),
          ),
          Expanded(
            child: Text(
              context.l10n.continueWith(SocialLogin.labels[provider] ?? provider),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 24),
        ],
      ),
    );
  }
}
