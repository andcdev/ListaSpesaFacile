import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Aspetto dell'app scelto dall'utente: sfondo chiaro, scuro o come il telefono. Resta salvato sul dispositivo.
class AppearanceController extends ChangeNotifier {
  static const _key = 'theme_mode';

  ThemeMode mode = ThemeMode.system;

  Future<void> load() async {
    final saved = (await SharedPreferences.getInstance()).getString(_key);
    mode = ThemeMode.values.firstWhere((m) => m.name == saved, orElse: () => ThemeMode.system);
    notifyListeners();
  }

  Future<void> setMode(ThemeMode value) async {
    mode = value;
    notifyListeners();
    await (await SharedPreferences.getInstance()).setString(_key, value.name);
  }
}
