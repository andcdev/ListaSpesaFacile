import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lista_spesa_facile/l10n/app_localizations.dart';
import 'package:lista_spesa_facile/models/list_item.dart';
import 'package:lista_spesa_facile/models/product_info.dart';
import 'package:lista_spesa_facile/models/user_price.dart';
import 'package:lista_spesa_facile/screens/my_prices_screen.dart';
import 'package:lista_spesa_facile/services/api_client.dart';
import 'package:lista_spesa_facile/widgets/product_info_sheet.dart';
import 'package:lista_spesa_facile/widgets/ui.dart';
import 'package:provider/provider.dart';

Widget _app(Widget home, {ApiClient? api}) {
  final app = MaterialApp(
    locale: const Locale('it'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    home: home,
  );
  return api == null ? app : Provider.value(value: api, child: app);
}

void main() {
  test("controllo dell'email in registrazione", () {
    for (final ok in ['mario@example.com', 'mario.rossi+spesa@mail.example.it']) {
      expect(isValidEmail(ok), isTrue, reason: ok);
    }
    for (final bad in [
      'mario',
      'mario@',
      'mario@localhost',
      'ma rio@example.com',
      'mario@example.c',
      'mario..r@example.com',
    ]) {
      expect(isValidEmail(bad), isFalse, reason: bad);
    }
  });

  test('scheda prodotto e prezzo personale dal JSON', () {
    final info = ProductInfo.fromJson({
      'barcode': '3017620422003',
      'name': 'Nutella',
      'images': ['https://img/front.jpg'],
      'nutriments': {'energy-kcal': 539, 'proteins': null},
      'allergens': ['milk', 'nuts'],
      'gluten_free': true,
      'vegan': false,
      'vegetarian': null,
      'matched_by': 'name',
    });
    expect(info.nutriments['energy-kcal'], 539.0);
    expect(info.nutriments['proteins'], isNull);
    expect([info.glutenFree, info.vegan, info.vegetarian], [true, false, null]);
    expect(info.matchedByName, isTrue);

    final price = UserPrice.fromJson({
      'id': 1,
      'product_name': 'Mele',
      'price': 2.2,
      'per': 'kg',
      'supermarket': 'Coop',
    });
    expect(price.toJson(), {
      'product_name': 'Mele',
      'price': 2.2,
      'per': 'kg',
      'barcode': null,
      'brand': null,
      'supermarket': 'Coop',
      'note': null,
    });
  });

  testWidgets('scheda Info: celiaci, vegani, calorie e allergeni, senza overflow', (tester) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    const item = ListItem(id: 1, listId: 1, name: 'Nutella', icon: '🍫');
    final info = ProductInfo.fromJson({
      'barcode': '3017620422003',
      'name': 'Nutella',
      'brand': 'Ferrero',
      'quantity': '400 g',
      'nutriments': {'energy-kcal': 539, 'fat': 30.9, 'sugars': 56.3},
      'ingredients': 'Zucchero, olio di palma, nocciole 13%',
      'allergens': ['milk', 'nuts', 'soybeans'],
      'traces': ['gluten'],
      'gluten_free': true,
      'vegetarian': true,
      'vegan': false,
      'palm_oil_free': false,
      'nutriscore': 'e',
      'nova': 4,
    });

    await tester.pumpWidget(
      _app(
        Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showProductInfo(context, item: item, info: Future.value(info)),
              child: const Text('apri'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('apri'));
    await tester.pumpAndSettle();

    expect(find.text('3017620422003'), findsOneWidget);
    expect(find.text('Celiaci: senza glutine'), findsOneWidget);
    expect(find.text('Vegano: no'), findsOneWidget);
    expect(find.text('Vegetariano: sì'), findsOneWidget);
    expect(find.text('Olio di palma: contiene'), findsOneWidget);
    expect(find.text('539 kcal'), findsOneWidget);
    expect(find.text('Latte, Frutta a guscio, Soia'), findsOneWidget);
    expect(find.text('Può contenere tracce di: Glutine'), findsOneWidget);
    expect(find.textContaining('Nutri-Score E'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  Future<void> openInfo(WidgetTester tester, ListItem item, ProductInfo info) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      _app(
        Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showProductInfo(context, item: item, info: Future.value(info)),
              child: const Text('apri'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('apri'));
    await tester.pumpAndSettle();
  }

  testWidgets("scheda Info di un'acqua: minerali in mg/L, niente calorie né voci non indicate", (tester) async {
    final info = ProductInfo.fromJson({
      'barcode': '80412021',
      'name': 'Acqua minerale naturale frizzante Lete',
      'kind': 'water',
      'nutriments': {'energy-kcal': 0, 'fat': 0},
      'minerals': {'calcium': 305, 'magnesium': 13.3, 'sodium': 5, 'bicarbonate': 940, 'nitrate': null},
      'gluten_free': null,
      'vegan': null,
    });
    expect(info.isWater, isTrue);
    await openInfo(tester, const ListItem(id: 1, listId: 1, name: 'Lete', icon: '💧'), info);

    expect(find.text('Composizione per litro'), findsOneWidget);
    expect(find.text('Calcio'), findsOneWidget);
    expect(find.text('305 mg/L'), findsOneWidget);
    expect(find.text('13,3 mg/L'), findsOneWidget);
    expect(find.text('940 mg/L'), findsOneWidget);
    expect(find.text('Nitrati'), findsNothing);
    expect(find.text('Valori nutrizionali per 100 g'), findsNothing);
    expect(find.textContaining('kcal'), findsNothing);
    expect(find.textContaining('Celiaci'), findsNothing);
    expect(find.textContaining('non indicato'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('scheda Info senza valori nutrizionali: lo dice, e niente voci vuote', (tester) async {
    // Un oggetto vuoto da PHP arriva come lista vuota.
    final info = ProductInfo.fromJson({
      'barcode': '8001234567890',
      'name': 'Torta della nonna',
      'kind': 'food',
      'nutriments': {'energy-kcal': null, 'fat': null},
      'minerals': [],
    });
    await openInfo(tester, const ListItem(id: 1, listId: 1, name: 'Torta della nonna'), info);

    expect(find.text('Non ci sono informazioni nutrizionali'), findsOneWidget);
    expect(find.byType(Chip), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('scheda Info di uno sfuso: valori medi CIQUAL, con la fonte giusta', (tester) async {
    final info = ProductInfo.fromJson({
      'barcode': '',
      'name': '',
      'kind': 'food',
      'nutriments': {'energy-kcal': 52.4, 'carbohydrates': 11.6, 'sugars': 9.35},
      'minerals': [],
      'vegan': true,
      'matched_by': 'generic',
      'source': 'CIQUAL (ANSES)',
      'url': 'https://ciqual.anses.fr/#/aliments/13039',
    });
    await openInfo(tester, const ListItem(id: 1, listId: 1, name: 'Mele', icon: '🍎'), info);

    expect(find.text('Mele'), findsOneWidget);
    expect(find.textContaining('tabella nutrizionale ufficiale CIQUAL'), findsOneWidget);
    expect(find.text('52,4 kcal'), findsOneWidget);
    expect(find.text('Vedi su CIQUAL (ANSES)'), findsOneWidget);
    expect(find.textContaining('CC BY 4.0'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('scheda Info di uno shampoo: niente valori nutrizionali, fonte Open Beauty Facts', (tester) async {
    final info = ProductInfo.fromJson({
      'barcode': '8001090662231',
      'name': 'Shampoo Coconut Milk',
      'kind': 'other',
      'nutriments': {'energy-kcal': null},
      'ingredients': 'Aqua, Sodium Laureth Sulfate',
      'source': 'Open Beauty Facts',
      'url': 'https://world.openbeautyfacts.org/product/8001090662231',
    });
    await openInfo(tester, const ListItem(id: 1, listId: 1, name: 'Shampoo', icon: '🧴'), info);

    expect(find.text('Non ci sono informazioni nutrizionali'), findsNothing);
    expect(find.text('Valori nutrizionali per 100 g'), findsNothing);
    expect(find.text('Aqua, Sodium Laureth Sulfate'), findsOneWidget);
    expect(find.text('Vedi su Open Beauty Facts'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('scheda Info senza prodotto trovato', (tester) async {
    await tester.pumpWidget(
      _app(
        Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showProductInfo(
                context,
                item: const ListItem(id: 1, listId: 1, name: 'Torta della nonna'),
                info: Future.value(null),
              ),
              child: const Text('apri'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('apri'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Nessuna informazione trovata'), findsOneWidget);
  });

  testWidgets('I miei prezzi: elenco, nuovo prezzo ed eliminazione', (tester) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final prices = <Map<String, dynamic>>[
      {'id': 1, 'product_name': 'Latte intero Parmalat', 'price': 1.39, 'per': 'pz', 'supermarket': 'Conad'},
    ];
    final sent = <http.Request>[];
    final api = ApiClient(
      baseUrl: 'https://spesa.example.com',
      httpClient: MockClient((request) async {
        sent.add(request);
        if (request.method == 'POST') {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          prices.insert(0, {...body, 'id': 2});
          return http.Response(jsonEncode({'data': prices.first}), 201, headers: {'content-type': 'application/json'});
        }
        if (request.method == 'DELETE') {
          prices.removeWhere((p) => request.url.path.endsWith('/${p['id']}'));
          return http.Response('', 204);
        }
        return http.Response(
          jsonEncode({'data': prices}),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );

    await tester.pumpWidget(_app(const MyPricesScreen(), api: api));
    await tester.pumpAndSettle();
    expect(find.text('Latte intero Parmalat'), findsOneWidget);
    expect(find.textContaining('1,39'), findsOneWidget);
    expect(find.text('I tuoi prezzi li vedi solo tu.'), findsWidgets);

    await tester.tap(find.text('Aggiungi prezzo'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Prodotto'), 'Mele');
    await tester.enterText(find.widgetWithText(TextField, 'Prezzo'), '2,20');
    await tester.tap(find.text('al kg'));
    await tester.tap(find.text('Salva'));
    await tester.pumpAndSettle();
    expect(jsonDecode(sent.firstWhere((r) => r.method == 'POST').body), containsPair('per', 'kg'));
    expect(find.text('Mele'), findsOneWidget);

    await tester.drag(find.text('Mele'), const Offset(-500, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Elimina'));
    await tester.pumpAndSettle();
    expect(sent.last.method, 'GET');
    expect(sent.any((r) => r.method == 'DELETE' && r.url.path == '/api/me/prices/2'), isTrue);
    expect(find.text('Mele'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
