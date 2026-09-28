import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:lista_spesa_facile/l10n/l10n.dart';
import 'package:lista_spesa_facile/services/api_client.dart';
import 'package:lista_spesa_facile/services/spoken_item.dart';
import 'package:lista_spesa_facile/state/locale_controller.dart';
import 'package:lista_spesa_facile/widgets/ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => initializeDateFormatting());
  tearDown(() => currentLanguage = 'it');

  test('ogni lingua ha tutti i testi dell\'italiano, con gli stessi segnaposto', () {
    Map<String, dynamic> arb(String lang) =>
        jsonDecode(File('lib/l10n/app_$lang.arb').readAsStringSync()) as Map<String, dynamic>;
    Set<String> placeholders(String text) => RegExp(r'\{(\w+)[},]').allMatches(text).map((m) => m[1]!).toSet();
    final it = arb('it')..removeWhere((k, _) => k.startsWith('@'));
    for (final lang in appLanguages.keys) {
      final other = arb(lang)..removeWhere((k, _) => k.startsWith('@'));
      expect(other.keys.toSet(), it.keys.toSet(), reason: lang);
      for (final key in it.keys) {
        expect(placeholders(other[key] as String), placeholders(it[key] as String), reason: '$lang: $key');
      }
    }
  });

  test('durate e date nella lingua dell\'app', () {
    expect(durationLabel(90), '1 ora e 30 minuti');
    currentLanguage = 'en';
    expect(durationLabel(1561), '1 day, 2 hours and 1 minute');
    currentLanguage = 'de';
    expect(durationLabel(2880), '2 Tage');
    expect(dayLabel(DateTime.now().add(const Duration(days: 1))), 'Morgen');
    currentLanguage = 'fr';
    expect(durationLabel(10), '10 minutes');
    currentLanguage = 'es';
    expect(durationLabel(60), '1 hora');
  });

  test('la lingua arriva al server in ogni richiesta', () async {
    late http.BaseRequest sent;
    final api = ApiClient(
      baseUrl: 'https://spesa.example.com',
      httpClient: MockClient((request) async {
        sent = request;
        return http.Response(jsonEncode({'message': 'Controlla la tua email.'}), 200);
      }),
    )..language = 'fr';
    await api.forgotPassword('a@example.com');
    expect(sent.headers['Accept-Language'], 'fr');
  });

  test('errori di rete tradotti', () async {
    currentLanguage = 'en';
    final api = ApiClient(
      baseUrl: 'https://spesa.example.com',
      httpClient: MockClient((_) async => throw http.ClientException('offline')),
    );
    await expectLater(
      api.lists(),
      throwsA(
        isA<ApiException>().having((e) => e.message, 'message', "Cannot reach the server. Check your connection."),
      ),
    );
  });

  test('prodotti dettati nelle altre lingue', () {
    SpokenItem parse(String text) => SpokenItem.parse(text);
    final apples = parse('2 kilos of apples');
    expect((apples.name, apples.amount, apples.unit), ('Apples', 2.0, 'kg'));
    final flour = parse('500 grammes de farine');
    expect((flour.name, flour.amount, flour.unit), ('Farine', 500.0, 'g'));
    final oranges = parse("1 kg d'oranges");
    expect((oranges.name, oranges.unit), ('Oranges', 'kg'));
    final milk = parse('zwei Liter Milch');
    expect((milk.name, milk.amount, milk.unit), ('Milch', 2.0, 'l'));
    final eggs = parse('seis huevos');
    expect((eggs.name, eggs.quantity), ('Huevos', '6'));
    // Articolo, non quantità.
    expect(parse('a pizza').quantity, isNull);
    expect(parse('a pizza').name, 'Pizza');
  });

  group('lingua dell\'app', () {
    testWidgets('come il telefono se supportata, altrimenti inglese', (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.platformDispatcher.localesTestValue = const [Locale('de', 'AT'), Locale('it')];
      addTearDown(tester.platformDispatcher.clearLocalesTestValue);
      final controller = LocaleController();
      await controller.load();
      addTearDown(controller.dispose);
      expect(controller.choice, isNull);
      expect(controller.language, 'de');
      expect(currentLanguage, 'de');

      tester.platformDispatcher.localesTestValue = const [Locale('pt', 'BR')];
      expect(controller.language, 'en');

      // Scelta dell'utente: vale anche dopo il riavvio.
      await controller.setChoice('es');
      expect(controller.language, 'es');
      final restarted = LocaleController();
      await restarted.load();
      addTearDown(restarted.dispose);
      expect(restarted.choice, 'es');

      await restarted.setChoice(null);
      expect(restarted.language, 'en');
    });

    testWidgets('segue la lingua cambiata nelle impostazioni del telefono', (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.platformDispatcher.localesTestValue = const [Locale('it', 'IT')];
      addTearDown(tester.platformDispatcher.clearLocalesTestValue);
      final controller = LocaleController();
      await controller.load();
      addTearDown(controller.dispose);
      var notified = 0;
      controller.addListener(() => notified++);

      tester.platformDispatcher.localesTestValue = const [Locale('fr', 'FR')];
      tester.binding.handleLocaleChanged();
      expect(currentLanguage, 'fr');
      expect(notified, 1);
    });

    testWidgets('interfaccia tradotta', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Scaffold(
            appBar: AppBar(title: const AppName()),
            body: Builder(builder: (context) => PageHeading(context.l10n.myLists)),
          ),
        ),
      );
      expect(find.text('My lists'), findsOneWidget);
      expect(find.text(AppName.appName), findsOneWidget);
    });
  });
}
