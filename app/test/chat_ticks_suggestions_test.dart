import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lista_spesa_facile/models/app_user.dart';
import 'package:lista_spesa_facile/models/chat_message.dart';
import 'package:lista_spesa_facile/models/product_suggestion.dart';
import 'package:lista_spesa_facile/services/api_client.dart';
import 'package:lista_spesa_facile/services/notification_service.dart';
import 'package:lista_spesa_facile/services/realtime_client.dart';
import 'package:lista_spesa_facile/state/chat_controller.dart';

Map<String, dynamic> _message(int id, int userId) => {
  'id': id,
  'shopping_list_id': 1,
  'body': 'm$id',
  'user': {'id': userId, 'name': 'U$userId'},
  'created_at': '2026-09-28T10:00:00Z',
};

void main() {
  group('suggerimenti dei prodotti', () {
    const all = [
      ProductSuggestion(name: 'Latte parzialmente scremato', icon: '🥛', times: 5),
      ProductSuggestion(name: 'Biscotti al latte', icon: '🍪', times: 2),
      ProductSuggestion(name: 'Caffè', icon: '☕', times: 1),
      ProductSuggestion(name: 'Lattuga', icon: '🥬'),
      ProductSuggestion(name: 'Limoni', icon: '🍋'),
    ];
    List<String> names(List<ProductSuggestion> list) => [for (final s in list) s.name];

    test('prima quelli che iniziano con il testo, poi le altre parole', () {
      expect(names(suggestProducts(all, 'lat')), ['Latte parzialmente scremato', 'Lattuga', 'Biscotti al latte']);
      expect(names(suggestProducts(all, 'lat scr')), ['Latte parzialmente scremato']);
    });

    test('senza accenti né maiuscole; esclusi quelli già in lista o già scritti', () {
      expect(names(suggestProducts(all, 'CAFFE')), isEmpty); // già scritto per intero
      expect(names(suggestProducts(all, 'caf')), ['Caffè']);
      expect(names(suggestProducts(all, 'la', exclude: ['lattuga'])), [
        'Latte parzialmente scremato',
        'Biscotti al latte',
      ]);
    });

    test('campo vuoto: i prodotti comprati più spesso', () {
      expect(names(suggestProducts(all, '  ', limit: 2)), ['Latte parzialmente scremato', 'Biscotti al latte']);
    });
  });

  test('spunte: una verde finché gli altri non hanno ricevuto, poi due blu', () async {
    final delivered = <Object?>[];
    final api = ApiClient(
      baseUrl: 'https://spesa.example.com',
      httpClient: MockClient((request) async {
        if (request.method == 'POST') {
          delivered.add(jsonDecode(request.body));
          return http.Response('', 204);
        }
        return http.Response(
          jsonEncode({
            'data': [_message(3, 2), _message(2, 1), _message(1, 1)],
            'has_more': false,
            'delivered': {'1': 2, '2': 1},
          }),
          200,
        );
      }),
    );
    final chat = ChatController(api: api, realtime: RealtimeClient(api), listId: 1, userId: 1);

    await chat.load();
    await Future<void>.delayed(Duration.zero); // la conferma parte senza bloccare la chat

    final [first, second, _] = chat.messages;
    expect(chat.ticks(first), MessageTicks.received); // l'utente 2 ha ricevuto fino all'1
    expect(chat.ticks(second), MessageTicks.sent);
    // Il messaggio 3 dell'altro utente è arrivato: si conferma al server.
    expect(delivered, [
      {'up_to': 3},
    ]);
  });

  test('push di Firebase letto come notifica dell\'app', () {
    final n = NotificationService.fromPush(
      const RemoteMessage(
        data: {
          'id': 'abc',
          'kind': 'chat_message',
          'title': 'Anna · Spesa',
          'body': 'Sono al banco frigo',
          'list_id': '7',
          'sender': 'Anna',
          'list_name': 'Spesa',
          'message_id': '42',
        },
      ),
    );
    expect(
      (n.kind, n.listId, n.messageId, n.sender, n.listName, n.stored),
      ('chat_message', 7, 42, 'Anna', 'Spesa', false),
    );

    final shared = NotificationService.fromPush(
      const RemoteMessage(data: {'kind': 'list_shared', 'title': 'Mario ha condiviso con te «Spesa»', 'list_id': '7'}),
    );
    expect((shared.stored, shared.body, shared.messageId), (true, '', null));
  });

  test('foto profilo: utente e autore dei messaggi', () {
    final api = ApiClient(baseUrl: 'https://spesa.example.com');
    final user = AppUser.fromJson({'id': 2, 'name': 'Anna', 'email': 'a@x.it', 'avatar_version': 'v1'});
    expect(user.avatarVersion, 'v1');
    expect(api.avatarUrl(2, 'v1'), 'https://spesa.example.com/api/users/2/avatar?v=v1');
    expect(
      ChatMessage.fromJson({
        ..._message(1, 2),
        'user': {'id': 2, 'name': 'Anna', 'avatar_version': 'v1'},
      }).userAvatarVersion,
      'v1',
    );
    expect(ChatMessage.fromJson(_message(1, 2)).userAvatarVersion, isNull); // nessuna foto: sagoma vuota
  });

  test('righe della conversazione salvate e rilette', () {
    final line = ConversationLine(
      sender: 'Mario',
      text: 'ha preso 🥛 Latte',
      at: DateTime.utc(2026, 9, 28),
      chat: false,
    );
    final copy = ConversationLine.fromJson(jsonDecode(jsonEncode(line.toJson())) as Map<String, dynamic>);
    expect((copy.sender, copy.text, copy.at, copy.chat), (line.sender, line.text, line.at, false));
  });
}
