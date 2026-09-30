import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lista_spesa_facile/l10n/app_localizations.dart';
import 'package:lista_spesa_facile/models/list_item.dart';
import 'package:lista_spesa_facile/models/shopping_list.dart';
import 'package:lista_spesa_facile/models/supermarket.dart';
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
    'province': 'MI',
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

  test('articolo e lista leggono marca, provenienza del prezzo, proposta in attesa e zona', () {
    expect(item.barcode, '8002580018446');
    expect(item.brand, 'Parmalat');
    expect(item.priceInfo!.reporter, 'Mario');
    expect(item.priceInfo!.fromUser, isTrue);
    expect(item.priceInfo!.zone, 'Milano');
    expect(item.copyWith(status: ItemStatus.taken).priceInfo!.reporter, 'Mario');
    // La mia proposta in attesa si mostra al posto del prezzo confermato (solo a me).
    final pending = ListItem.fromJson({
      'id': 11,
      'shopping_list_id': 1,
      'name': 'Pane',
      'price': 2.0,
      'price_info': {'price': 2.0, 'currency': 'EUR', 'per': 'pz', 'source': 'open_prices', 'report_id': 5},
      'my_price': {
        'line': 2.4,
        'price': 2.4,
        'currency': 'EUR',
        'per': 'pz',
        'source': 'user',
        'status': 'pending',
        'report_id': 9,
      },
      'pending_prices': 2,
    });
    expect(pending.shownPrice, 2.4);
    expect(pending.myPrice!.pending, isTrue);
    expect(pending.pendingPrices, 2);
    expect(pending.copyWith(myPrice: () => null).shownPrice, 2.0);
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

    final saved = await api.reportPrice(1, 10, price: 1.4, per: 'pz', province: 'MI', city: 'Milano', locality: null);
    expect(sent.last.method, 'POST');
    expect(sent.last.url.path, '/api/lists/1/items/10/prices');
    expect(jsonDecode(sent.last.body), {
      'price': 1.4,
      'per': 'pz',
      'province': 'MI',
      'city': 'Milano',
      'locality': null,
    });
    expect(saved.price, 1.4);

    await api.votePrice(1, 10, 7, approve: false).catchError((_) => const ItemPrices());
    expect(sent.last.url.path, '/api/lists/1/items/10/prices/7/vote');
    expect(jsonDecode(sent.last.body), {'approve': false});
  });

  testWidgets('scheda del prezzo: più confermato in alto, voto, proposta in attesa e nuova proposta', (tester) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    Map<String, dynamic> report(int id, double price, String source, String status, int approvals, {String? who}) => {
      'id': id,
      'price': price,
      'currency': 'EUR',
      'per': 'pz',
      'source': source,
      'status': status,
      'approvals': approvals,
      'reporter': who ?? 'Open Prices',
      'observed_at': '2026-09-30T10:15:00+00:00',
      'city': 'Milano',
      'mine': false,
      'my_vote': null,
    };
    final api = ApiClient(
      baseUrl: 'https://spesa.example.com',
      httpClient: MockClient(
        (request) async => http.Response(
          jsonEncode({
            'data': {
              'supermarket': 'Lidl',
              'current': {...report(1, 1.89, 'open_prices', 'approved', 2), 'report_id': 1},
              'mine': {...report(3, 1.35, 'user', 'pending', 0, who: 'Io'), 'report_id': 3},
              'reports': [
                report(1, 1.89, 'open_prices', 'approved', 2),
                report(2, 1.49, 'user', 'pending', 0, who: 'Anna'),
              ],
            },
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        ),
      ),
    );
    PriceCorrection? proposed;
    final votes = <(int?, bool)>[];

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('it'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showItemPriceSheet(
                context,
                api: api,
                list: list,
                item: item,
                onPropose: (c) async => proposed = c,
                onVote: (r, approve) async {
                  votes.add((r.reportId, approve));
                  return api.itemPrices(1, 10);
                },
              ),
              child: const Text('apri'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('apri'));
    await tester.pumpAndSettle();

    expect(find.textContaining('1,89'), findsOneWidget);
    expect(find.text('2 conferme'), findsOneWidget);
    expect(find.textContaining('La tua proposta: 1,35'), findsOneWidget);
    expect(find.text('Altri prezzi'), findsOneWidget);
    expect(find.textContaining('Anna ·'), findsOneWidget);
    expect(find.textContaining('da confermare'), findsOneWidget);
    expect(tester.takeException(), isNull);

    // Conferma del prezzo mostrato e smentita di quello di Anna.
    await tester.tap(find.text('Confermo').first);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Non è giusto').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Non è giusto').last);
    await tester.pumpAndSettle();
    expect(votes, [(1, true), (2, false)]);

    await tester.ensureVisible(find.text('Proponi un altro prezzo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Proponi un altro prezzo'));
    await tester.pumpAndSettle();
    expect(find.text('Città Studi'), findsOneWidget);
    expect(find.textContaining('dopo la conferma di altri utenti'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextField, 'Prezzo'), 'abc');
    await tester.tap(find.text('Salva'));
    await tester.pump();
    expect(find.text('Scrivi un prezzo, es. 1,29'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, 'Prezzo'), '1,49');
    await tester.enterText(find.widgetWithText(TextField, 'Provincia'), 'MI');
    await tester.tap(find.text('al kg'));
    await tester.tap(find.text('Salva'));
    await tester.pumpAndSettle();
    expect(proposed, (price: 1.49, per: 'kg', province: 'MI', city: 'Milano', locality: 'Città Studi'));
    expect(tester.takeException(), isNull);
  });
}
