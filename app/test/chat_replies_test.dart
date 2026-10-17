import 'package:flutter_test/flutter_test.dart';
import 'package:lista_spesa_facile/models/chat_message.dart';
import 'package:lista_spesa_facile/widgets/chat_panel.dart';

void main() {
  test('un messaggio porta la citazione a cui risponde; un evento è riconosciuto', () {
    final reply = ChatMessage.fromJson({
      'id': 5,
      'shopping_list_id': 1,
      'body': 'Sì, grazie',
      'created_at': '2026-10-18T08:00:00+00:00',
      'user': {'id': 2, 'name': 'Anna'},
      'reply_to': {
        'id': 4,
        'body': 'Prendo il caffè?',
        'has_image': false,
        'user': {'id': 1, 'name': 'Mario'},
      },
    });
    expect(reply.replyTo?.id, 4);
    expect(reply.replyTo?.userName, 'Mario');
    expect(reply.isEvent, isFalse);

    final event = ChatMessage.fromJson({
      'id': 6,
      'shopping_list_id': 1,
      'body': 'Giulia ha finito la spesa',
      'created_at': '2026-10-18T08:05:00+00:00',
      'user': {'id': 3, 'name': 'Giulia'},
      'event': 'finished',
      'event_params': {'missing': 2},
    });
    expect(event.isEvent, isTrue);
    expect(event.eventParams['missing'], 2);
    expect(event.replyTo, isNull);
  });

  test('dal messaggio ai prodotti: uno per riga o separati da virgole', () {
    expect(chatProductNames('pane, latte\nuova;  '), ['pane', 'latte', 'uova']);
    expect(chatProductNames('   '), isEmpty);
  });
}
