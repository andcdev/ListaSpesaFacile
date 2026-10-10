import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lista_spesa_facile/models/app_user.dart';
import 'package:lista_spesa_facile/services/api_client.dart';

void main() {
  final sent = <http.Request>[];
  ApiClient api(Object? Function(http.Request) reply) => ApiClient(
    baseUrl: 'https://spesa.example.com',
    httpClient: MockClient((request) async {
      sent.add(request);
      final body = reply(request);
      return http.Response(body == null ? '' : jsonEncode(body), body == null ? 204 : 200);
    }),
  );

  setUp(sent.clear);

  test('segnala un messaggio con lista e messaggio', () async {
    await api((_) => {'message': 'ok'}).report('message', listId: 3, messageId: 9, body: 'Offensivo');
    expect(sent.single.method, 'POST');
    expect(sent.single.url.path, '/api/reports');
    expect(jsonDecode(sent.single.body), {'type': 'message', 'body': 'Offensivo', 'list_id': 3, 'message_id': 9});
  });

  test('blocca e sblocca una persona', () async {
    final client = api((_) => null);
    await client.blockUser(7);
    await client.unblockUser(7);
    expect(sent.map((r) => '${r.method} ${r.url.path}'), ['POST /api/blocks', 'DELETE /api/blocks/7']);
    expect(jsonDecode(sent.first.body), {'user_id': 7});
  });

  test('la copia di una lista manda copy_from', () async {
    final list = {
      'id': 2,
      'name': 'Spesa domenica',
      'scheduled_at': '2026-10-12T09:00:00Z',
      'permission': 'owner',
      'items': [],
    };
    final created = await api((_) => {'data': list})
        .createList(name: 'Spesa domenica', scheduledAt: DateTime.utc(2026, 10, 12, 9), copyFrom: 1);
    expect(created.id, 2);
    expect(jsonDecode(sent.single.body)['copy_from'], 1);
  });

  test("l'utente corrente sa chi ha bloccato", () {
    final me = AppUser.fromJson({
      'id': 1,
      'name': 'Anna',
      'email': 'anna@example.com',
      'blocked_ids': [4, 5],
    });
    expect(me.blockedIds, {4, 5});
    expect(AppUser.fromJson({'id': 2}).blockedIds, isEmpty);
  });

  test("un 403 mostra il motivo dato dal server (es. account sospeso), non quello generico di Laravel", () async {
    ApiClient replying(String message) => ApiClient(
      baseUrl: 'https://spesa.example.com',
      httpClient: MockClient((_) async => http.Response(jsonEncode({'message': message}), 403)),
    );
    await expectLater(
      replying('Il tuo account è sospeso.').login('a@b.it', 'x'),
      throwsA(isA<ApiException>().having((e) => e.message, 'message', 'Il tuo account è sospeso.')),
    );
    await expectLater(
      replying('This action is unauthorized.').deleteList(1),
      throwsA(isA<ApiException>().having((e) => e.message, 'message', isNot('This action is unauthorized.'))),
    );
  });
}
