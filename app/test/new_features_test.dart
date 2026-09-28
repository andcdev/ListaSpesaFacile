import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lista_spesa_facile/models/app_notification.dart';
import 'package:lista_spesa_facile/models/chat_message.dart';
import 'package:lista_spesa_facile/models/list_item.dart';
import 'package:lista_spesa_facile/models/shopping_list.dart';
import 'package:lista_spesa_facile/services/api_client.dart';
import 'package:lista_spesa_facile/services/notification_service.dart';
import 'package:lista_spesa_facile/services/spoken_item.dart';

Map<String, dynamic> _list({String permission = 'edit', bool? membersCanRename}) => {
  'id': 1,
  'name': 'Spesa',
  'scheduled_at': '2026-09-28T10:00:00Z',
  'permission': permission,
  'members_can_rename': ?membersCanRename,
};

void main() {
  group('articolo dettato a voce', () {
    SpokenItem parse(String text) => SpokenItem.parse(text);

    test('peso o volume con unità pronunciata', () {
      final mele = parse('2 kg di mele');
      expect((mele.name, mele.amount, mele.unit, mele.quantity), ('Mele', 2.0, 'kg', null));

      final pane = parse('mezzo chilo di pane');
      expect((pane.name, pane.amount, pane.unit), ('Pane', 0.5, 'kg'));

      final latte = parse('1,5 litri latte');
      expect((latte.name, latte.amount, latte.unit), ('Latte', 1.5, 'l'));

      final prosciutto = parse('due etti di prosciutto cotto');
      expect((prosciutto.name, prosciutto.amount, prosciutto.unit), ('Prosciutto cotto', 2.0, 'hg'));
    });

    test('quantità in cifre o in lettere', () {
      final yogurt = parse('3 yogurt');
      expect((yogurt.name, yogurt.quantity, yogurt.amount), ('Yogurt', '3', null));
      expect(parse('sei uova').quantity, '6');
    });

    test('senza numeri il testo è il nome; "una" è un articolo, non una quantità', () {
      expect(parse('detersivo piatti').name, 'Detersivo piatti');
      expect(parse('detersivo piatti').quantity, isNull);
      final pizza = parse('una pizza margherita');
      expect((pizza.name, pizza.quantity), ('Pizza margherita', null));
      expect(parse('latte').name, 'Latte');
    });

    test('unità non gestita dal server: resta nel nome come quantità', () {
      final item = SpokenItem.parse('2 kg di mele', units: const ['g']);
      expect((item.name, item.quantity, item.amount), ('Kg di mele', '2', null));
    });
  });

  test('permesso di rinominare la lista', () {
    expect(ShoppingList.fromJson(_list(permission: 'owner')).canRename, isTrue);
    expect(ShoppingList.fromJson(_list()).canRename, isFalse);
    expect(ShoppingList.fromJson(_list(membersCanRename: true)).canRename, isTrue);
    expect(ShoppingList.fromJson(_list(permission: 'view', membersCanRename: true)).canRename, isFalse);

    // Il proprietario cambia il permesso mentre la lista è aperta.
    final updated = ShoppingList.fromJson(_list()).withMeta({'name': 'Spesa', 'members_can_rename': true});
    expect(updated.canRename, isTrue);
  });

  test('foto: messaggio solo foto, articolo con foto caricata', () {
    final message = ChatMessage.fromJson({
      'id': 5,
      'shopping_list_id': 1,
      'body': null,
      'has_image': true,
      'user': {'id': 2, 'name': 'Anna'},
      'created_at': '2026-09-28T10:00:00Z',
    });
    expect((message.body, message.hasImage), ('', true));

    final item = ListItem.fromJson({'id': 3, 'shopping_list_id': 1, 'name': 'Biscotti', 'image_version': 'abc'});
    expect(item.imageVersion, 'abc');
    expect(item.copyWith(status: ItemStatus.taken).imageVersion, 'abc');
  });

  test('chat e modifiche diventano righe della conversazione della lista', () {
    final activity = AppNotification.fromJson({
      'id': 'x',
      'kind': 'list_activity',
      'title': 'Spesa',
      'body': 'Mario ha preso 🥛 Latte',
      'list_id': 1,
      'sender': 'Mario',
      'list_name': 'Spesa',
      'stored': false,
    });
    expect(activity.stored, isFalse);
    final line = ConversationLine.from(activity);
    expect((line.sender, line.text, line.chat), ('Mario', 'ha preso 🥛 Latte', false));

    final chat = ConversationLine.from(
      AppNotification(
        id: 'y',
        kind: 'chat_message',
        title: 'Anna · Spesa',
        body: '📷 Foto',
        createdAt: DateTime(2026),
        sender: 'Anna',
      ),
    );
    expect((chat.sender, chat.text, chat.chat), ('Anna', '📷 Foto', true));
    expect(isConversationKind('list_shared'), isFalse);
  });

  test('foto in chat inviata come multipart con la didascalia', () async {
    late http.BaseRequest sent;
    final api = ApiClient(
      baseUrl: 'https://spesa.example.com',
      httpClient: MockClient.streaming((request, body) async {
        sent = request;
        final bytes = await body.toBytes();
        expect(utf8.decode(bytes, allowMalformed: true), contains('name="body"'));
        return http.StreamedResponse(
          Stream.value(
            utf8.encode(
              jsonEncode({
                'data': {
                  'id': 1,
                  'shopping_list_id': 7,
                  'body': 'Questo?',
                  'has_image': true,
                  'created_at': '2026-09-28T10:00:00Z',
                },
              }),
            ),
          ),
          201,
        );
      }),
    )..token = 'abc';
    final file = await _tempImage();

    final message = await api.sendMessage(7, 'Questo?', imagePath: file);

    expect(sent.url.path, '/api/lists/7/messages');
    expect(sent.headers['Authorization'], 'Bearer abc');
    expect(message.hasImage, isTrue);
    expect(api.messageImageUrl(7, 1), 'https://spesa.example.com/api/lists/7/messages/1/image');
    expect(api.itemImageUrl(7, 3, 'v1'), 'https://spesa.example.com/api/lists/7/items/3/image?v=v1');
  });

  test('recupero password: codice e nuova password', () async {
    final requests = <http.Request>[];
    final api = ApiClient(
      baseUrl: 'https://spesa.example.com',
      httpClient: MockClient((request) async {
        requests.add(request);
        return request.url.path.endsWith('forgot-password')
            ? http.Response(jsonEncode({'message': 'Controlla la posta.'}), 200)
            : http.Response(
                jsonEncode({
                  'token': 't',
                  'user': {'id': 1, 'name': 'Anna', 'email': 'anna@example.com'},
                }),
                200,
              );
      }),
    );

    expect(await api.forgotPassword('anna@example.com'), 'Controlla la posta.');
    final (token, user) = await api.resetPassword('anna@example.com', '123456', 'nuova-password');

    expect((token, user.name), ('t', 'Anna'));
    expect(jsonDecode(requests.last.body), {
      'email': 'anna@example.com',
      'code': '123456',
      'password': 'nuova-password',
      'password_confirmation': 'nuova-password',
      'device_name': anything,
    });
  });
}

Future<String> _tempImage() async {
  final dir = await Directory.systemTemp.createTemp('chat');
  final file = File('${dir.path}/foto.png')..writeAsBytesSync([137, 80, 78, 71]);
  return file.path;
}
