import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lista_spesa_facile/l10n/app_localizations.dart';
import 'package:lista_spesa_facile/screens/list_share_screen.dart';
import 'package:lista_spesa_facile/screens/login_screen.dart';
import 'package:lista_spesa_facile/services/api_client.dart';
import 'package:lista_spesa_facile/services/social_login.dart';
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
  testWidgets('accesso: Google e Amazon con il logo ufficiale, niente Facebook', (tester) async {
    await tester.pumpWidget(
      _app(
        Scaffold(
          body: Column(
            children: [for (final p in SocialLoginSection.alwaysShown) SocialButton(provider: p, onPressed: () {})],
          ),
        ),
      ),
    );

    expect(SocialLoginSection.alwaysShown, ['google', 'amazon']);
    expect(SocialLogin.labels.keys, isNot(contains('facebook')));
    expect(find.text('Continua con Google'), findsOneWidget);
    expect(find.text('Continua con Amazon'), findsOneWidget);
    final logos = tester.widgetList<Image>(find.byType(Image)).map((i) => (i.image as AssetImage).assetName);
    expect(logos, ['assets/logos/google.png', 'assets/logos/amazon.png']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('condivisione della lista: si cambia il permesso di chi ce l\'ha già', (tester) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    var canEdit = true;
    final sent = <http.Request>[];
    final api = ApiClient(
      baseUrl: 'https://spesa.example.com',
      httpClient: MockClient((request) async {
        sent.add(request);
        if (request.method == 'PATCH') canEdit = (jsonDecode(request.body) as Map)['can_edit'] as bool;
        return http.Response(
          jsonEncode({
            'data': [
              {'id': 7, 'name': 'Renata Maddaluna', 'email': 'renata.maddaluna@example.com', 'can_edit': canEdit},
            ],
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );

    await tester.pumpWidget(_app(const ListShareScreen(listId: 3, listName: 'Spesa'), api: api));
    await tester.pumpAndSettle();
    // Uno nel modulo per aggiungere, uno per Renata.
    expect(find.text('Lettura e modifica'), findsNWidgets(2));

    await tester.tap(find.text('Lettura e modifica').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Solo lettura').last);
    await tester.pumpAndSettle();

    final patch = sent.singleWhere((r) => r.method == 'PATCH');
    expect(patch.url.path, '/api/lists/3/shares/7');
    expect(jsonDecode(patch.body), {'can_edit': false});
    expect(find.text('Solo lettura'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
