import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lista_spesa_facile/l10n/app_localizations.dart';
import 'package:lista_spesa_facile/services/api_client.dart';
import 'package:lista_spesa_facile/services/realtime_client.dart';
import 'package:lista_spesa_facile/services/session_storage.dart';
import 'package:lista_spesa_facile/state/auth_controller.dart';
import 'package:lista_spesa_facile/state/chat_controller.dart';
import 'package:lista_spesa_facile/widgets/chat_panel.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('aperta dall\'anteprima, la chat scorre fino al messaggio e lo evidenzia per qualche secondo', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final api = ApiClient(
      baseUrl: 'https://spesa.example.com',
      httpClient: MockClient((request) async {
        if (request.method == 'POST') return http.Response('', 204);
        return http.Response(
          jsonEncode({
            'data': [
              for (var id = 40; id >= 1; id--)
                {
                  'id': id,
                  'shopping_list_id': 1,
                  'body': 'Messaggio $id',
                  'user': {'id': 2, 'name': 'Anna'},
                  'created_at': '2026-10-18T10:00:00Z',
                },
            ],
            'has_more': false,
            'delivered': {},
          }),
          200,
        );
      }),
    );
    final chat = ChatController(api: api, realtime: RealtimeClient(api), listId: 1, userId: 1);
    await tester.runAsync(chat.load);
    final auth = AuthController(api: api, realtime: RealtimeClient(api), storage: SessionStorage());

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('it'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Scaffold(
          body: MultiProvider(
            providers: [
              Provider.value(value: api),
              ChangeNotifierProvider.value(value: auth),
              ChangeNotifierProvider.value(value: chat),
            ],
            child: const ChatPanel(isOwner: false, highlightId: 3),
          ),
        ),
      ),
    );
    // Il messaggio 3 è molto più in alto dei più recenti: la chat risale fin lì.
    await tester.pumpAndSettle();
    expect(find.text('Messaggio 3'), findsOneWidget);
    Color? background() =>
        (tester
                    .widget<AnimatedContainer>(
                      find.ancestor(of: find.text('Messaggio 3'), matching: find.byType(AnimatedContainer)).first,
                    )
                    .decoration
                as BoxDecoration?)
            ?.color;
    expect(background(), isNot(Colors.transparent));

    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(background(), Colors.transparent);
  });
}
