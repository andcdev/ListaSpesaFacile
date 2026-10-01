import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/l10n.dart';
import '../models/app_user.dart';
import '../services/api_client.dart';

/// Informativa privacy sul sito (accettata alla registrazione).
const privacyPolicyUrl = 'https://listaspesafacile.com/privacy';

Future<void> openPrivacyPolicy() => launchUrl(Uri.parse(privacyPolicyUrl), mode: LaunchMode.externalApplication);

/// Condizioni d'uso: chi aggiunge un contenuto (liste, articoli, chat, foto) ne è responsabile.
const termsOfUseUrl = 'https://listaspesafacile.com/termini';
Future<void> openTermsOfUse() => launchUrl(Uri.parse(termsOfUseUrl), mode: LaunchMode.externalApplication);

/// Email scritta correttamente: nome@dominio.estensione, senza spazi né punti doppi ("mario@localhost" no).
bool isValidEmail(String value) {
  final email = value.trim();
  return RegExp(r'^[^@\s]+@[^@\s]+\.[a-zA-Z]{2,}$').hasMatch(email) && !email.contains('..');
}

void showError(BuildContext context, Object error) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text('$error'), behavior: SnackBarBehavior.floating));
}

void showMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message), behavior: SnackBarBehavior.floating));
}

/// Dialogo di conferma; [action] è il testo del pulsante (predefinito: "Elimina").
Future<bool> confirm(BuildContext context, {required String title, String? message, String? action}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: message == null ? null : Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: Text(context.l10n.cancel)),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(action ?? context.l10n.delete)),
      ],
    ),
  );
  return result ?? false;
}

/// "Oggi", "Domani", "Ieri" oppure es. "venerdì 26 settembre" (nella lingua dell'app).
String dayLabel(DateTime date) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(date.year, date.month, date.day);
  final diff = day.difference(today).inDays;
  if (diff == 0) return appL10n.today;
  if (diff == 1) return appL10n.tomorrow;
  if (diff == -1) return appL10n.yesterday;
  // Ordine di giorno e mese come si usa nella lingua (es. "Friday, September 26" in inglese).
  final format = date.year == now.year ? DateFormat.MMMMEEEEd() : DateFormat.yMMMMEEEEd();
  final label = format.format(date);
  return label[0].toUpperCase() + label.substring(1);
}

String timeLabel(DateTime date) => DateFormat.Hm().format(date);

/// Icona del carrello e nome dell'app in stampatello, in alto nella prima pagina (il nome non si traduce).
/// Logo dell'app, lo stesso in alto sul sito (marchio/logo.svg): carrello bianco su verde con la spunta.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 28});

  static const asset = 'assets/logos/lista_spesa_facile.png';

  final double size;

  @override
  Widget build(BuildContext context) =>
      Image.asset(asset, width: size, height: size, filterQuality: FilterQuality.medium, semanticLabel: '');
}

class AppName extends StatelessWidget {
  const AppName({super.key});

  static const appName = 'LISTA SPESA FACILE';

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const AppLogo(size: 28),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            appName,
            maxLines: 1,
            overflow: TextOverflow.fade,
            softWrap: false,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(color: primary, fontSize: 13, letterSpacing: 1.6),
          ),
        ),
      ],
    );
  }
}

/// Titolo grande della pagina (es. "Le mie liste", il nome della lista), con righe facoltative sotto.
class PageHeading extends StatelessWidget {
  const PageHeading(this.title, {super.key, this.subtitle, this.compact = false});

  final String title;
  final Widget? subtitle;

  /// Più piccolo, quando lo spazio serve ad altro (es. con la chat aperta).
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title, style: compact ? text.headlineSmall : text.displaySmall),
        if (subtitle != null) ...[
          const SizedBox(height: 6),
          DefaultTextStyle.merge(
            style: text.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
            child: subtitle!,
          ),
        ],
      ],
    );
  }
}

/// Titolo nella barra delle schermate secondarie (es. modifica o condivisione di una lista), con una riga
/// piccola facoltativa sotto.
class ScreenTitle extends StatelessWidget {
  const ScreenTitle(this.title, {super.key, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        if (subtitle != null)
          Text(
            subtitle!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
      ],
    );
  }
}

/// Corpo delle schermate: trasparente, lascia vedere lo sfondo con i disegni dei prodotti che sta sotto ogni pagina
/// (ProductsWallpaper in app_theme.dart). Il Material trasparente fa vedere l'effetto al tocco sulle righe.
class Wallpaper extends StatelessWidget {
  const Wallpaper({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Material(type: MaterialType.transparency, child: child);
}

/// Barra di avanzamento della spesa: articoli presi sul totale.
class ShoppingProgress extends StatelessWidget {
  const ShoppingProgress({super.key, required this.done, required this.total});

  final int done;
  final int total;

  @override
  Widget build(BuildContext context) => LinearProgressIndicator(value: total == 0 ? 0 : done / total);
}

/// Foto profilo dell'utente, oppure le iniziali se non l'ha impostata (o non si carica).
class UserAvatar extends StatelessWidget {
  const UserAvatar({super.key, required this.initials, this.radius = 16, this.tooltip, this.image});

  final String initials;
  final double radius;
  final String? tooltip;
  final ImageProvider? image;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final avatar = CircleAvatar(
      radius: radius,
      backgroundColor: scheme.secondary,
      foregroundColor: scheme.onSecondary,
      backgroundImage: image,
      onBackgroundImageError: image == null ? null : (_, _) {},
      child: image != null
          ? null
          : Text(
              initials,
              style: TextStyle(fontSize: radius * 0.75, fontWeight: FontWeight.w600),
            ),
    );
    return tooltip == null ? avatar : Tooltip(message: tooltip!, child: avatar);
  }
}

/// Foto profilo dell'utente (null se non l'ha impostata).
ImageProvider? avatarImage(ApiClient api, AppUser user) => user.avatarVersion == null
    ? null
    : NetworkImage(api.avatarUrl(user.id, user.avatarVersion!), headers: api.authHeaders);

String initialsOf(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
  if (parts.isEmpty) return '?';
  return parts.take(2).map((p) => p[0].toUpperCase()).join();
}
