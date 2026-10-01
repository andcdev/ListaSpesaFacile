import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lista_spesa_facile/l10n/app_localizations.dart';
import 'package:lista_spesa_facile/screens/register_screen.dart';
import 'package:lista_spesa_facile/services/api_client.dart';
import 'package:lista_spesa_facile/services/realtime_client.dart';
import 'package:lista_spesa_facile/services/session_storage.dart';
import 'package:lista_spesa_facile/state/auth_controller.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('registrazione: senza le condizioni d\'uso non parte, con le due caselle manda privacy e terms', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final sent = <Map<String, dynamic>>[];
    final api = ApiClient(
      baseUrl: 'https://spesa.example.com',
      httpClient: MockClient((request) async {
        if (request.url.path.endsWith('/register')) sent.add(jsonDecode(request.body) as Map<String, dynamic>);
        // Email già usata: la registrazione si ferma qui, senza salvare sessioni.
        return http.Response(
          jsonEncode({
            'message': 'Email già in uso',
            'errors': {
              'email': ['Questa email è già in uso.'],
            },
          }),
          422,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    final auth = AuthController(api: api, realtime: RealtimeClient(api), storage: SessionStorage());
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: auth,
        child: MaterialApp(
          locale: const Locale('it'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: const RegisterScreen(),
        ),
      ),
    );

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Mario');
    await tester.enterText(fields.at(1), 'mario@example.com');
    await tester.enterText(fields.at(2), 'password123');
    await tester.enterText(fields.at(3), 'password123');
    expect(find.textContaining('i contenuti che aggiungo sono sotto la mia responsabilità'), findsOneWidget);

    // Solo la privacy: manca l'accettazione delle condizioni d'uso, nessuna richiesta al server.
    final boxes = find.byType(CheckboxListTile);
    await tester.tap(boxes.at(0));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Registrati'));
    await tester.pump();
    expect(find.text("Per registrarti devi accettare le condizioni d'uso"), findsOneWidget);
    expect(sent, isEmpty);

    // Con le condizioni d'uso la richiesta parte e le porta con sé.
    await tester.tap(boxes.at(1));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Registrati'));
    await tester.pumpAndSettle();
    expect(sent, hasLength(1));
    expect(sent.single['privacy'], isTrue);
    expect(sent.single['terms'], isTrue);
    expect(sent.single['newsletter'], isFalse);
    expect(find.text('Questa email è già in uso.'), findsOneWidget);
  });
}
