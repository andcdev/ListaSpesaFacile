import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/l10n.dart';

/// Lingua dell'app: scelta dall'utente (accesso o menu del profilo) oppure quella del telefono.
/// La scelta resta salvata sul dispositivo; "come il telefono" segue anche i cambi fatti nelle impostazioni di Android.
class LocaleController extends ChangeNotifier with WidgetsBindingObserver {
  static const _key = 'app_language';

  /// Lingua scelta dall'utente, null = come il telefono.
  String? choice;

  /// Lingua in uso (una di [appLanguages]).
  String get language => resolve(choice);

  Locale get locale => Locale(language);

  /// Lingua del telefono tra quelle dell'app; se il telefono ne usa un'altra, l'inglese.
  static String systemLanguage() {
    for (final locale in WidgetsBinding.instance.platformDispatcher.locales) {
      if (appLanguages.containsKey(locale.languageCode)) return locale.languageCode;
    }
    return 'en';
  }

  static String resolve(String? choice) => appLanguages.containsKey(choice) ? choice! : systemLanguage();

  /// Legge la scelta salvata e imposta la lingua (anche per il gestore dei push in background).
  static Future<String> loadSaved() async {
    final saved = (await SharedPreferences.getInstance()).getString(_key);
    _apply(resolve(saved));
    return currentLanguage;
  }

  Future<void> load() async {
    choice = (await SharedPreferences.getInstance()).getString(_key);
    if (!appLanguages.containsKey(choice)) choice = null;
    _apply(language);
    WidgetsBinding.instance.addObserver(this);
  }

  Future<void> setChoice(String? value) async {
    choice = value;
    _apply(language);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    value == null ? await prefs.remove(_key) : await prefs.setString(_key, value);
  }

  @override
  void didChangeLocales(List<Locale>? locales) {
    if (choice != null || currentLanguage == language) return;
    _apply(language);
    notifyListeners();
  }

  /// Date ("venerdì 26 settembre") e testi fuori dai widget nella nuova lingua.
  static void _apply(String language) {
    currentLanguage = language;
    Intl.defaultLocale = language;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
