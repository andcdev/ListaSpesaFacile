import 'package:flutter/widgets.dart';

import '../models/shopping_list.dart';
import 'app_localizations.dart';

export 'app_localizations.dart';

/// Lingue dell'app, con il loro nome nella lingua stessa (come si mostrano nel menu "Lingua").
const appLanguages = {'it': 'Italiano', 'en': 'English', 'fr': 'Français', 'de': 'Deutsch', 'es': 'Español'};

/// Lingua in uso (codice di [appLanguages]): la imposta LocaleController, serve ai testi fuori dai widget.
String currentLanguage = 'it';

/// Testi nella lingua in uso, per servizi e modelli che non hanno un BuildContext (errori di rete, notifiche…).
AppLocalizations get appL10n => lookupAppLocalizations(Locale(currentLanguage));

extension L10nContext on BuildContext {
  /// Testi nella lingua dell'app; fuori da MaterialApp (es. nei test) quelli della lingua in uso.
  AppLocalizations get l10n => Localizations.of<AppLocalizations>(this, AppLocalizations) ?? appL10n;
}

extension ReminderTargetLabel on ReminderTarget {
  String label(AppLocalizations l) => switch (this) {
    ReminderTarget.owner => l.reminderOwner,
    ReminderTarget.members => l.reminderMembers,
    ReminderTarget.all => l.reminderAll,
  };
}

/// Es. "10 minuti", "1 ora", "1 ora e 30 minuti", "2 giorni" (come sul server).
String durationLabel(int minutes, [AppLocalizations? l10n]) {
  final l = l10n ?? appL10n;
  final days = minutes ~/ 1440;
  final hours = (minutes % 1440) ~/ 60;
  final mins = minutes % 60;
  final parts = [
    if (days > 0) l.durationDays(days),
    if (hours > 0) l.durationHours(hours),
    if (mins > 0) l.durationMinutes(mins),
  ];
  if (parts.isEmpty) return l.durationMoments;
  if (parts.length == 1) return parts.single;
  return l.listAnd(parts.sublist(0, parts.length - 1).join(', '), parts.last);
}
