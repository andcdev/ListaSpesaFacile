// ignore_for_file: avoid_print
// Test end-to-end contro un backend reale (API + Reverb). Disattivati di default, vedi dart_test.yaml.
//   cd backend && php artisan serve & php artisan reverb:start & php artisan schedule:work &
//   cd app && flutter test --tags e2e --exclude-tags manual --run-skipped test/e2e
@Tags(['e2e'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lista_spesa_facile/models/list_item.dart';
import 'package:lista_spesa_facile/models/shopping_list.dart';
import 'package:lista_spesa_facile/services/api_client.dart';
import 'package:lista_spesa_facile/services/notification_service.dart';
import 'package:lista_spesa_facile/services/realtime_client.dart';
import 'package:lista_spesa_facile/state/chat_controller.dart';
import 'package:lista_spesa_facile/state/list_detail_controller.dart';
import 'package:lista_spesa_facile/state/lists_controller.dart';
import 'package:lista_spesa_facile/state/notifications_controller.dart';

final apiUrl = Platform.environment['E2E_API_URL'] ?? 'http://127.0.0.1:8000';

Future<void> waitFor(bool Function() cond, String what, {int seconds = 10}) async {
  for (var i = 0; i < seconds * 10; i++) {
    if (cond()) return;
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
  fail('Timeout: $what');
}

void main() {
  test('due utenti sulla stessa lista in tempo reale', () async {
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final annaApi = ApiClient(baseUrl: apiUrl);
    final brunoApi = ApiClient(baseUrl: apiUrl);
    final (annaToken, anna) = await annaApi.register(
      'Anna Rossi',
      'anna$stamp@example.com',
      'password123',
      privacy: true,
      terms: true,
    );
    final (brunoToken, bruno) = await brunoApi.register(
      'Bruno',
      'bruno$stamp@example.com',
      'password123',
      privacy: true,
      terms: true,
    );
    annaApi.token = annaToken;
    brunoApi.token = brunoToken;

    final list = await annaApi.createList(name: 'Spesa', scheduledAt: DateTime.now().add(const Duration(days: 1)));
    await annaApi.addShare(list.id, bruno.email);

    final annaRt = RealtimeClient(annaApi);
    final brunoRt = RealtimeClient(brunoApi);
    await annaRt.connect(await annaApi.realtimeConfig());
    await brunoRt.connect(await brunoApi.realtimeConfig());
    await waitFor(() => annaRt.connected.value && brunoRt.connected.value, 'connessione');

    final annaLists = ListsController(api: annaApi, realtime: annaRt, userId: anna.id)..start();
    final annaDetail = ListDetailController(api: annaApi, realtime: annaRt, listId: list.id, userId: anna.id)..start();
    await waitFor(() => annaDetail.list != null && annaLists.lists.isNotEmpty, 'caricamento');
    await waitFor(() => annaDetail.viewers.length == 1, 'Anna presente');

    final brunoDetail = ListDetailController(api: brunoApi, realtime: brunoRt, listId: list.id, userId: bruno.id)
      ..start();
    await waitFor(() => annaDetail.viewers.length == 2, 'Anna vede Bruno nella lista');
    await waitFor(
      () => brunoDetail.viewers.map((v) => v.name).toSet().containsAll({'Anna Rossi', 'Bruno'}),
      'Bruno vede Anna',
    );

    await brunoDetail.addItem('Latte', quantity: '2 l');
    await waitFor(() => annaDetail.items.any((i) => i.name == 'Latte'), 'articolo di Bruno arriva ad Anna');
    await waitFor(() => annaLists.lists.single.itemsCount == 1, 'contatori aggiornati nell\'elenco di Anna');

    final latte = annaDetail.items.single;
    await annaDetail.setStatus(latte, ItemStatus.taken);
    await waitFor(
      () => brunoDetail.items.single.checked && brunoDetail.items.single.checkedBy == 'Anna Rossi',
      'spunta arriva a Bruno',
    );

    await annaApi.updateList(list.id, name: 'Spesa sabato', scheduledAt: list.scheduledAt);
    await waitFor(() => brunoDetail.list!.name == 'Spesa sabato', 'rinomina arriva a Bruno');

    await annaDetail.clearChecked();
    await waitFor(() => brunoDetail.items.isEmpty, 'cancellazione arriva a Bruno');

    brunoDetail.dispose();
    await waitFor(() => annaDetail.viewers.length == 1, 'Bruno esce dalla lista');

    // Revoca: Bruno riapre la lista e poi perde l'accesso mentre la sta guardando.
    final brunoAgain = ListDetailController(api: brunoApi, realtime: brunoRt, listId: list.id, userId: bruno.id)
      ..start();
    await waitFor(() => brunoAgain.list != null, 'Bruno riapre');
    await annaApi.removeShare(list.id, bruno.id);
    await waitFor(() => brunoAgain.gone, 'Bruno viene espulso dopo la revoca');

    await annaLists.delete(list.id);
    await waitFor(() => annaDetail.gone, 'eliminazione notificata');

    annaDetail.dispose();
    annaLists.dispose();
    brunoAgain.dispose();
    annaRt.disconnect();
    brunoRt.disconnect();
  }, timeout: const Timeout(Duration(minutes: 2)));

  // Il promemoria lo invia lo scheduler (ogni minuto): il test dura fino a ~2 minuti.
  test('condivisione alla creazione, notifiche, chat e promemoria', () async {
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final annaApi = ApiClient(baseUrl: apiUrl);
    final brunoApi = ApiClient(baseUrl: apiUrl);
    final (annaToken, anna) = await annaApi.register(
      'Anna',
      'anna-chat$stamp@example.com',
      'password123',
      privacy: true,
      terms: true,
    );
    final (brunoToken, bruno) = await brunoApi.register(
      'Bruno',
      'bruno-chat$stamp@example.com',
      'password123',
      privacy: true,
      terms: true,
    );
    annaApi.token = annaToken;
    brunoApi.token = brunoToken;

    final annaRt = RealtimeClient(annaApi);
    final brunoRt = RealtimeClient(brunoApi);
    await annaRt.connect(await annaApi.realtimeConfig());
    await brunoRt.connect(await brunoApi.realtimeConfig());
    await waitFor(() => annaRt.connected.value && brunoRt.connected.value, 'connessione');

    final brunoNotifications = NotificationsController(
      api: brunoApi,
      realtime: brunoRt,
      service: NotificationService(),
      userId: bruno.id,
    )..start();
    await waitFor(() => !brunoNotifications.loading, 'notifiche caricate');
    // La sottoscrizione al canale personale richiede un giro di autorizzazione.
    await Future<void>.delayed(const Duration(seconds: 1));

    // Lista alle "ora + 11 minuti" con promemoria 10 minuti prima: parte al prossimo giro dello scheduler.
    final at = DateTime.now().add(const Duration(minutes: 11));
    final list = await annaApi.createList(
      name: 'Spesa $stamp',
      scheduledAt: at,
      reminderMinutes: 10,
      reminderTarget: ReminderTarget.members,
      shares: [ShareRequest(bruno.email, canEdit: false)],
    );
    expect(list.sharedWith.single.canEdit, isFalse);

    await waitFor(
      () => brunoNotifications.items.any((n) => n.kind == 'list_shared' && n.listId == list.id),
      'Bruno riceve la notifica di condivisione in tempo reale',
    );
    expect(brunoNotifications.unreadCount, 1);

    final annaChat = ChatController(api: annaApi, realtime: annaRt, listId: list.id, userId: anna.id)..start();
    final brunoChat = ChatController(api: brunoApi, realtime: brunoRt, listId: list.id, userId: bruno.id)..start();
    await waitFor(() => !annaChat.loading && !brunoChat.loading, 'chat caricate');
    await Future<void>.delayed(const Duration(seconds: 1));

    // Bruno è in sola lettura ma può scrivere in chat.
    await brunoChat.send('Prendo io il pane');
    await waitFor(() => annaChat.messages.any((m) => m.body == 'Prendo io il pane'), 'messaggio arriva ad Anna');
    await annaChat.send('Perfetto, grazie!');
    await waitFor(() => brunoChat.messages.length == 2, 'risposta arriva a Bruno');
    expect(brunoChat.messages.last.userName, 'Anna');

    await annaChat.delete(annaChat.messages.last);
    await waitFor(() => brunoChat.messages.length == 1, 'eliminazione arriva a Bruno');

    await waitFor(
      () => brunoNotifications.items.any((n) => n.kind == 'reminder' && n.listId == list.id),
      'promemoria inviato dallo scheduler',
      seconds: 130,
    );
    final reminder = brunoNotifications.items.firstWhere((n) => n.kind == 'reminder');
    expect(reminder.body, 'La spesa è tra 10 minuti.');

    await brunoNotifications.markAllRead();
    expect((await brunoApi.notifications()).unreadCount, 0);

    await annaApi.deleteList(list.id);
    await waitFor(
      () => brunoNotifications.items.any((n) => n.kind == 'list_deleted'),
      'Bruno viene avvisato dell\'eliminazione',
    );

    annaChat.dispose();
    brunoChat.dispose();
    brunoNotifications.dispose();
    annaRt.disconnect();
    brunoRt.disconnect();
  }, timeout: const Timeout(Duration(minutes: 4)));

  // Richiede di riavviare Reverb manualmente quando compare READY_FOR_RESTART.
  test(
    'riconnessione dopo riavvio di Reverb',
    () async {
      final stamp = DateTime.now().millisecondsSinceEpoch;
      final api = ApiClient(baseUrl: apiUrl);
      final other = ApiClient(baseUrl: apiUrl);
      final (t1, me) = await api.register('Carla', 'c$stamp@example.com', 'password123', privacy: true, terms: true);
      final (t2, _) = await other.register('Dario', 'd$stamp@example.com', 'password123', privacy: true, terms: true);
      api.token = t1;
      other.token = t2;
      final list = await api.createList(name: 'R', scheduledAt: DateTime.now());
      await api.addShare(list.id, 'd$stamp@example.com');

      final rt = RealtimeClient(api);
      var reconnects = 0;
      rt.reconnected.listen((_) => reconnects++);
      await rt.connect(await api.realtimeConfig());
      final detail = ListDetailController(api: api, realtime: rt, listId: list.id, userId: me.id)..start();
      await waitFor(() => detail.viewers.length == 1, 'presenza iniziale');
      // Riavviare Reverb ora (es. docker compose restart reverb).
      print('READY_FOR_RESTART');

      await waitFor(() => !rt.connected.value, 'disconnessione rilevata', seconds: 20);
      print('DISCONNECTED');
      // Mentre Reverb è giù un altro utente aggiunge un articolo: l'evento va perso ma il reload lo recupera.
      await other.addItem(list.id, 'Uova');
      await waitFor(() => rt.connected.value && reconnects == 1, 'riconnessione', seconds: 40);
      await waitFor(() => detail.items.any((i) => i.name == 'Uova'), 'dati ricaricati dopo riconnessione');
      await waitFor(() => detail.viewers.length == 1, 'presenza ripristinata');
      await other.addItem(list.id, 'Farina');
      await waitFor(() => detail.items.any((i) => i.name == 'Farina'), 'eventi di nuovo in tempo reale');
      print('RECONNECT_OK');
      detail.dispose();
      rt.disconnect();
    },
    timeout: const Timeout(Duration(minutes: 2)),
    tags: ['manual'],
  );
}
