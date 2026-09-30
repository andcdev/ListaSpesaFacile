import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lista_spesa_facile/l10n/app_localizations.dart';
import 'package:lista_spesa_facile/models/shopping_list.dart';
import 'package:lista_spesa_facile/models/supermarket.dart';
import 'package:lista_spesa_facile/services/api_client.dart';
import 'package:lista_spesa_facile/widgets/price_comparison.dart';
import 'package:provider/provider.dart';

void main() {
  Map<String, dynamic> listJson({String? supermarket, Map<String, dynamic>? chain}) => {
    'id': 1,
    'name': 'Spesa',
    'scheduled_at': '2026-10-03T08:30:00+00:00',
    'permission': 'owner',
    'supermarket': supermarket,
    'supermarket_chain': chain,
    'items': [
      {'id': 10, 'shopping_list_id': 1, 'name': 'Latte', 'price': 2.4},
      {'id': 11, 'shopping_list_id': 1, 'name': 'Carta igienica', 'price': null},
    ],
  };

  test('la lista legge supermercato, catena e prezzi degli articoli', () {
    final list = ShoppingList.fromJson(
      listJson(supermarket: 'Lidl via Roma', chain: {'id': 5, 'name': 'Lidl', 'description': 'Discount'}),
    );

    expect(list.supermarket, 'Lidl via Roma');
    expect(list.supermarketChain!.name, 'Lidl');
    expect(list.supermarketChain!.description, 'Discount');
    expect(list.items.first.price, 2.4);
    expect(list.items.last.price, isNull);
  });

  test('withMeta toglie la catena se il supermercato cambia e la tiene altrimenti', () {
    final list = ShoppingList.fromJson(listJson(supermarket: 'Lidl', chain: {'id': 5, 'name': 'Lidl'}));

    expect(list.withMeta({'name': 'Spesa', 'supermarket': 'Lidl'}).supermarketChain?.name, 'Lidl');
    expect(list.withMeta({'name': 'Spesa'}).supermarketChain?.name, 'Lidl');
    final changed = list.withMeta({'name': 'Spesa', 'supermarket': 'Bottega'});
    expect(changed.supermarket, 'Bottega');
    expect(changed.supermarketChain, isNull);
  });

  test('il confronto legge totale, copertura e dettaglio per catena', () {
    final row = PriceComparison.fromJson({
      'id': 5,
      'name': 'Lidl',
      'description': 'Discount, in tutta Italia',
      'current': true,
      'total': 3.4,
      'priced_count': 2,
      'items_count': 3,
      'items': [
        {'id': 10, 'name': 'Latte', 'icon': '🥛', 'status': 'todo', 'price': 2.4},
        {'id': 11, 'name': 'Pane', 'icon': '🍞', 'status': 'missing', 'price': 1},
        {'id': 12, 'name': 'Sapone', 'icon': '🧴', 'status': 'todo', 'price': null},
      ],
    });

    expect(row.supermarket.name, 'Lidl');
    expect(row.current, isTrue);
    expect(row.total, 3.4);
    expect(row.pricedCount, 2);
    expect(row.items[1].price, 1.0);
    expect(row.items[1].missing, isTrue);
    expect(row.items[2].price, isNull);
  });

  testWidgets('confronto catene: una fisarmonica per catena con totale, i dettagli si aprono toccandola', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    late Uri requested;
    final api = ApiClient(
      baseUrl: 'https://spesa.example.com',
      httpClient: MockClient((request) async {
        requested = request.url;
        return http.Response(
          jsonEncode({
            'data': [
              for (final (name, total, current) in [('Lidl', 3.4, false), ('Esselunga', 5.0, true)])
                {
                  'id': name.length,
                  'name': name,
                  'description': 'Supermercati e superstore, soprattutto al Nord e al Centro',
                  'current': current,
                  'total': total,
                  'priced_count': 1,
                  'items_count': 2,
                  'items': [
                    {'id': 10, 'name': 'Latte parzialmente scremato alta qualità', 'icon': '🥛', 'price': total},
                    {'id': 11, 'name': 'Sapone', 'icon': '🧴', 'price': null},
                  ],
                },
            ],
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );

    await tester.pumpWidget(
      Provider.value(
        value: api,
        child: MaterialApp(
          locale: const Locale('it'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(onPressed: () => showPriceComparison(context, 7), child: const Text('apri')),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('apri'));
    await tester.pumpAndSettle();

    expect(requested.path, '/api/lists/7/price-comparison');
    expect(find.text('Confronta catene'), findsOneWidget);
    expect(find.text('Lidl'), findsOneWidget);
    expect(find.text('Esselunga · scelta'), findsOneWidget);
    expect(find.textContaining('3,40'), findsOneWidget);
    expect(find.textContaining('Prezzo per 1 di 2 prodotti'), findsNWidgets(2));
    expect(find.text('Sapone'), findsNothing);

    await tester.tap(find.text('Lidl'));
    await tester.pumpAndSettle();
    expect(find.text('Sapone'), findsOneWidget);
    expect(find.text('—'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
