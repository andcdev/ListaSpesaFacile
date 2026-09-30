import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lista_spesa_facile/l10n/app_localizations.dart';
import 'package:lista_spesa_facile/models/list_item.dart';
import 'package:lista_spesa_facile/models/shopping_list.dart';
import 'package:lista_spesa_facile/services/api_client.dart';
import 'package:lista_spesa_facile/widgets/item_price_sheet.dart';

void main() {
  final list = ShoppingList.fromJson({
    'id': 1,
    'name': 'Spesa',
    'scheduled_at': '2026-10-03T08:30:00+00:00',
    'permission': 'owner',
    'supermarket': 'Lidl',
    'supermarket_chain': {'id': 5, 'name': 'Lidl'},
    'country': 'IT',
    'city': 'Milano',
    'locality': 'Città Studi',
  });
  final item = ListItem.fromJson({
    'id': 10,
    'shopping_list_id': 1,
    'name': 'Latte intero Parmalat',
    'barcode': '8002580018446',
    'brand': 'Parmalat',
    'price': 1.35,
    'price_info': {
      'price': 1.35,
      'per': 'pz',
      'source': 'user',
      'reporter': 'Mario',
      'observed_at': '2026-09-30T10:15:00+00:00',
      'city': 'Milano',
      'locality': null,
    },
  });

  test('articolo e lista leggono marca, provenienza del prezzo e zona', () {
    expect(item.barcode, '8002580018446');
    expect(item.brand, 'Parmalat');
    expect(item.priceInfo!.reporter, 'Mario');
    expect(item.priceInfo!.fromUser, isTrue);
    expect(item.priceInfo!.zone, 'Milano');
    expect(item.copyWith(status: ItemStatus.taken).priceInfo!.reporter, 'Mario');
    expect([list.country, list.city, list.locality], ['IT', 'Milano', 'Città Studi']);
    expect(list.withMeta({'name': 'Spesa', 'city': 'Roma'}).city, 'Roma');
    expect(list.withMeta({'name': 'Spesa'}).locality, 'Città Studi');
  });

  test('ricerca dei prodotti di marca e rettifica del prezzo', () async {
    final sent = <http.Request>[];
    final api = ApiClient(
      baseUrl: 'https://spesa.example.com',
      httpClient: MockClient((request) async {
        sent.add(request);
        final body = request.url.path.endsWith('/search')
            ? {
                'data': [
                  {
                    'barcode': '8002580018446',
                    'name': 'latte intero Parmalat',
                    'brand': 'Parmalat',
                    'quantity': '1 L',
                    'amount': 1,
                    'unit': 'l',
                    'image_url': 'https://images.openfoodfacts.org/latte.jpg',
                  },
                ],
              }
            : {
                'data': {'id': 10, 'shopping_list_id': 1, 'name': 'Latte', 'price': 1.4},
              };
        return http.Response(jsonEncode(body), 200, headers: {'content-type': 'application/json; charset=utf-8'});
      }),
    );

    final found = await api.searchProducts('latte & parm', country: 'IT');
    expect(sent.last.url.queryParameters, {'q': 'latte & parm', 'country': 'IT'});
    expect(found.single.name, 'latte intero Parmalat');
    expect(found.single.amount, 1.0);

    final saved = await api.reportPrice(1, 10, price: 1.4, per: 'pz', city: 'Milano', locality: null);
    expect(sent.last.method, 'POST');
    expect(sent.last.url.path, '/api/lists/1/items/10/prices');
    expect(jsonDecode(sent.last.body), {'price': 1.4, 'per': 'pz', 'city': 'Milano', 'locality': null});
    expect(saved.price, 1.4);
  });

  testWidgets('scheda del prezzo: chi e quando, storico e rettifica con la zona della lista', (tester) async {
    tester.view.physicalSize = const Size(360, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final api = ApiClient(
      baseUrl: 'https://spesa.example.com',
      httpClient: MockClient(
        (request) async => http.Response(
          jsonEncode({
            'data': {
              'supermarket': 'Lidl',
              'current': item.priceInfo == null
                  ? null
                  : {
                      'price': 1.35,
                      'per': 'pz',
                      'source': 'user',
                      'reporter': 'Mario',
                      'observed_at': '2026-09-30T10:15:00+00:00',
                      'city': 'Milano',
                    },
              'reports': [
                {
                  'price': 1.35,
                  'per': 'pz',
                  'source': 'user',
                  'reporter': 'Mario',
                  'observed_at': '2026-09-30T10:15:00+00:00',
                  'city': 'Milano',
                  'product_name': 'Latte intero Parmalat',
                },
                {
                  'price': 1.89,
                  'per': 'pz',
                  'source': 'open_prices',
                  'reporter': 'Open Prices',
                  'observed_at': '2026-09-05T00:00:00+00:00',
                  'city': 'Milano',
                  'product_name': 'latte intero',
                },
              ],
            },
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        ),
      ),
    );
    PriceCorrection? corrected;

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('it'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () =>
                  showItemPriceSheet(context, api: api, list: list, item: item, onCorrect: (c) async => corrected = c),
              child: const Text('apri'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('apri'));
    await tester.pumpAndSettle();

    expect(find.textContaining('1,35'), findsNWidgets(2));
    expect(find.textContaining('Mario ·'), findsNWidgets(2));
    expect(find.textContaining('Open Prices ·'), findsOneWidget);
    expect(find.text('Segnalazioni precedenti'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Correggi il prezzo'));
    await tester.pumpAndSettle();
    expect(find.text('Milano'), findsWidgets);
    expect(find.text('Città Studi'), findsOneWidget);
    expect(find.textContaining('non la tua email'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, 'Prezzo'), 'abc');
    await tester.tap(find.text('Salva'));
    await tester.pump();
    expect(find.text('Scrivi un prezzo, es. 1,29'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, 'Prezzo'), '1,49');
    await tester.tap(find.text('al kg'));
    await tester.tap(find.text('Salva'));
    await tester.pumpAndSettle();
    expect(corrected, (price: 1.49, per: 'kg', city: 'Milano', locality: 'Città Studi'));
    expect(tester.takeException(), isNull);
  });
}
