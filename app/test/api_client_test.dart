import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lista_spesa_facile/models/shopping_list.dart';
import 'package:lista_spesa_facile/services/api_client.dart';

void main() {
  test('invia il token e converte gli errori di validazione di Laravel', () async {
    late http.Request sent;
    final api = ApiClient(
      baseUrl: 'https://spesa.example.com/',
      httpClient: MockClient((request) async {
        sent = request;
        return http.Response(
          jsonEncode({
            'message': 'The email field is invalid.',
            'errors': {
              'email': ['Nessun utente registrato con questa email.'],
            },
          }),
          422,
        );
      }),
    )..token = 'abc';

    await expectLater(
      api.addShare(1, 'x@example.com'),
      throwsA(
        isA<ApiException>()
            .having((e) => e.statusCode, 'status', 422)
            .having((e) => e.message, 'message', 'Nessun utente registrato con questa email.')
            .having((e) => e.errors.keys, 'errors', ['email']),
      ),
    );
    expect(sent.url.toString(), 'https://spesa.example.com/api/lists/1/shares');
    expect(sent.headers['Authorization'], 'Bearer abc');
    expect(jsonDecode(sent.body), {'email': 'x@example.com', 'can_edit': true});
  });

  test('401 con token attivo notifica la sessione scaduta', () async {
    var unauthorized = false;
    final api =
        ApiClient(
            baseUrl: 'http://10.0.2.2',
            httpClient: MockClient((_) async => http.Response('{"message":"Unauthenticated."}', 401)),
          )
          ..token = 'scaduto'
          ..onUnauthorized = () => unauthorized = true;

    await expectLater(api.lists(), throwsA(isA<ApiException>()));
    expect(unauthorized, isTrue);
  });

  test('realtimeConfig usa l\'host dell\'API quando il server indica localhost', () async {
    final api = ApiClient(
      baseUrl: 'http://10.0.2.2',
      httpClient: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'realtime': {'key': 'k', 'host': 'localhost', 'port': 80, 'scheme': 'http'},
          }),
          200,
        ),
      ),
    );

    final config = await api.realtimeConfig();

    expect(config.host, '10.0.2.2');
    expect(config.port, 80);
    expect(config.key, 'k');
  });

  test('createList invia la data in UTC', () async {
    late Map<String, dynamic> body;
    final api = ApiClient(
      baseUrl: 'http://x',
      httpClient: MockClient((request) async {
        body = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({
            'data': {'id': 5, 'name': 'A', 'scheduled_at': '2026-10-03T08:30:00+00:00', 'permission': 'owner'},
          }),
          201,
        );
      }),
    );

    final local = DateTime(2026, 10, 3, 10, 30);
    final list = await api.createList(name: 'A', scheduledAt: local);

    expect(DateTime.parse(body['scheduled_at'] as String), local.toUtc());
    expect(list.id, 5);
  });

  test('createList invia promemoria e destinatari', () async {
    late Map<String, dynamic> body;
    final api = ApiClient(
      baseUrl: 'http://x',
      httpClient: MockClient((request) async {
        body = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({
            'data': {
              'id': 5,
              'name': 'A',
              'scheduled_at': '2026-10-03T08:30:00+00:00',
              'permission': 'owner',
              'reminder_minutes': 60,
              'reminder_target': 'members',
            },
          }),
          201,
        );
      }),
    );

    final list = await api.createList(
      name: 'A',
      scheduledAt: DateTime(2026, 10, 3, 10, 30),
      reminderMinutes: 60,
      reminderTarget: ReminderTarget.members,
      shares: const [ShareRequest('anna@example.com'), ShareRequest('luca@example.com', canEdit: false)],
    );

    expect(body['reminder_minutes'], 60);
    expect(body['reminder_target'], 'members');
    expect(body['shares'], [
      {'email': 'anna@example.com', 'can_edit': true},
      {'email': 'luca@example.com', 'can_edit': false},
    ]);
    expect(list.reminderMinutes, 60);
    expect(list.reminderTarget, ReminderTarget.members);
  });

  test('messaggi della chat: pagina precedente con ?before e has_more', () async {
    late Uri url;
    final api = ApiClient(
      baseUrl: 'http://x',
      httpClient: MockClient((request) async {
        url = request.url;
        return http.Response(
          jsonEncode({
            'data': [
              {
                'id': 7,
                'shopping_list_id': 3,
                'body': 'Ciao',
                'user': {'id': 2, 'name': 'Anna'},
                'created_at': '2026-10-03T08:30:00+00:00',
              },
              {'id': 6, 'shopping_list_id': 3, 'body': 'Vecchio', 'user': null, 'created_at': '2026-10-03T08:00:00Z'},
            ],
            'has_more': true,
          }),
          200,
        );
      }),
    );

    final page = await api.messages(3, before: 8);

    expect(url.toString(), 'http://x/api/lists/3/messages?before=8');
    expect(page.hasMore, isTrue);
    expect(page.messages.first.userName, 'Anna');
    expect(page.messages.last.userId, isNull);
    expect(page.messages.first.createdAt.toUtc(), DateTime.utc(2026, 10, 3, 8, 30));
  });

  test('notifiche: elenco, contatore e segna come lette', () async {
    final bodies = <String>[];
    final api = ApiClient(
      baseUrl: 'http://x',
      httpClient: MockClient((request) async {
        bodies.add(request.body);
        if (request.method == 'GET') {
          return http.Response(
            jsonEncode({
              'data': [
                {
                  'id': 'abc',
                  'kind': 'reminder',
                  'title': 'Promemoria: Spesa',
                  'body': 'La spesa è tra 10 minuti.',
                  'list_id': 4,
                  'read': false,
                  'created_at': '2026-10-03T08:30:00+00:00',
                },
              ],
              'unread_count': 1,
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        return http.Response(jsonEncode({'unread_count': 0}), 200);
      }),
    );

    final page = await api.notifications();
    expect(page.unreadCount, 1);
    expect(page.notifications.single.listId, 4);
    expect(page.notifications.single.body, 'La spesa è tra 10 minuti.');

    expect(await api.markNotificationsRead(['abc']), 0);
    expect(await api.markNotificationsRead(), 0);
    expect(jsonDecode(bodies[1]), {
      'ids': ['abc'],
    });
    expect(jsonDecode(bodies[2]), <String, dynamic>{});
  });

  test('serverConfig indica se le notifiche push sono attive sul server', () async {
    final api = ApiClient(
      baseUrl: 'http://x',
      httpClient: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'realtime': {'key': 'k', 'host': 'x', 'port': 80, 'scheme': 'http'},
            'push': true,
          }),
          200,
        ),
      ),
    );

    expect((await api.serverConfig()).push, isTrue);
  });

  test('addItem invia peso e unità solo se c\'è il peso', () async {
    final bodies = <Map<String, dynamic>>[];
    final api = ApiClient(
      baseUrl: 'http://x',
      httpClient: MockClient((request) async {
        bodies.add(jsonDecode(request.body) as Map<String, dynamic>);
        return http.Response(
          jsonEncode({
            'data': {'id': 1, 'shopping_list_id': 3, 'name': 'Farina', 'category': 'dispensa', 'icon': '🌾'},
          }),
          201,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );

    final item = await api.addItem(3, 'Farina', quantity: '2', amount: 1, unit: 'kg');
    await api.addItem(3, 'Farina', unit: 'kg');

    expect(bodies[0], {'name': 'Farina', 'quantity': '2', 'amount': 1.0, 'unit': 'kg'});
    expect(bodies[1], {'name': 'Farina', 'quantity': null});
    expect(item.icon, '🌾');
  });
}
