import 'package:flutter_test/flutter_test.dart';
import 'package:lista_spesa_facile/l10n/l10n.dart';
import 'package:lista_spesa_facile/models/list_item.dart';
import 'package:lista_spesa_facile/models/measure_mode.dart';
import 'package:lista_spesa_facile/models/product_suggestion.dart';
import 'package:lista_spesa_facile/models/shopping_list.dart';
import 'package:lista_spesa_facile/services/notification_service.dart';

void main() {
  test('ShoppingList.fromJson converte la data UTC nel fuso locale e legge i permessi', () {
    final list = ShoppingList.fromJson({
      'id': 1,
      'name': 'Spesa',
      'notes': null,
      'scheduled_at': '2026-10-03T08:30:00+00:00',
      'permission': 'view',
      'owner': {'id': 2, 'name': 'Anna', 'email': 'anna@example.com'},
      'items': [
        {'id': 10, 'shopping_list_id': 1, 'name': 'Latte', 'quantity': '2 l', 'checked': true, 'position': 1},
        {'id': 11, 'shopping_list_id': 1, 'name': 'Pane', 'checked': false, 'position': 2},
      ],
    });

    expect(list.scheduledAt.isUtc, isFalse);
    expect(list.scheduledAt.toUtc(), DateTime.utc(2026, 10, 3, 8, 30));
    expect(list.canEdit, isFalse);
    expect(list.isOwner, isFalse);
    expect(list.itemsCount, 2);
    expect(list.checkedCount, 1);
    expect(list.owner!.name, 'Anna');
  });

  test('withMeta aggiorna nome e data mantenendo gli articoli', () {
    final list = ShoppingList.fromJson({
      'id': 1,
      'name': 'Vecchio',
      'scheduled_at': '2026-10-03T08:30:00+00:00',
      'permission': 'owner',
      'items': [
        {'id': 10, 'shopping_list_id': 1, 'name': 'Latte'},
      ],
    });

    final updated = list.withMeta({'name': 'Nuovo', 'notes': 'Coop', 'scheduled_at': '2026-10-04T10:00:00+00:00'});

    expect(updated.name, 'Nuovo');
    expect(updated.notes, 'Coop');
    expect(updated.scheduledAt.toUtc(), DateTime.utc(2026, 10, 4, 10));
    expect(updated.items.single.name, 'Latte');
    expect(updated.isOwner, isTrue);
  });

  test('promemoria: a chi è destinato e aggiornamento in tempo reale', () {
    Map<String, dynamic> json(String permission, String target) => {
      'id': 1,
      'name': 'Spesa',
      'scheduled_at': '2026-10-03T08:30:00+00:00',
      'permission': permission,
      'reminder_minutes': 10,
      'reminder_target': target,
    };

    expect(ShoppingList.fromJson(json('owner', 'owner')).remindsMe, isTrue);
    expect(ShoppingList.fromJson(json('edit', 'owner')).remindsMe, isFalse);
    expect(ShoppingList.fromJson(json('owner', 'members')).remindsMe, isFalse);
    expect(ShoppingList.fromJson(json('view', 'members')).remindsMe, isTrue);
    expect(ShoppingList.fromJson(json('view', 'all')).remindsMe, isTrue);
    expect(ShoppingList.fromJson({...json('owner', 'all'), 'reminder_minutes': null}).remindsMe, isFalse);

    final list = ShoppingList.fromJson(json('owner', 'all'));
    expect(list.withMeta({'name': 'Spesa'}).reminderMinutes, 10);
    final updated = list.withMeta({'reminder_minutes': null, 'reminder_target': 'owner'});
    expect(updated.reminderMinutes, isNull);
    expect(updated.reminderTarget, ReminderTarget.owner);
  });

  test('destinazione delle notifiche toccate', () {
    expect(NotificationTarget.parse('chat:12')!.chat, isTrue);
    expect(NotificationTarget.parse('list:12')!.listId, 12);
    expect(NotificationTarget.parse(null), isNull);
    expect(NotificationTarget.parse('rotto'), isNull);
    final push = NotificationTarget.fromPushData({'kind': 'chat_message', 'list_id': '5'})!;
    expect((push.listId, push.chat), (5, true));
    expect(NotificationTarget.fromPushData({'kind': 'global_share'}), isNull);
    expect(NotificationTarget(3, chat: true).toPayload(), 'chat:3');
  });

  test('testo dell\'anticipo del promemoria', () {
    expect(durationLabel(10), '10 minuti');
    expect(durationLabel(60), '1 ora');
    expect(durationLabel(90), '1 ora e 30 minuti');
    expect(durationLabel(1561), '1 giorno, 2 ore e 1 minuto');
    expect(durationLabel(2880), '2 giorni');
  });

  test('articolo: icona, reparto e peso', () {
    final item = ListItem.fromJson({
      'id': 1,
      'shopping_list_id': 2,
      'name': 'Parmigiano',
      'category': 'latticini',
      'icon': '🧀',
      'quantity': '2',
      'amount': 1.5,
      'unit': 'kg',
    });
    expect(item.icon, '🧀');
    expect(item.category, 'latticini');
    expect(item.measureLabel, '2 · 1,5 kg');
    expect(item.copyWith(status: ItemStatus.taken).amount, 1.5);

    final plain = ListItem.fromJson({'id': 1, 'shopping_list_id': 2, 'name': 'X', 'amount': 500, 'unit': 'g'});
    expect(plain.measureLabel, '500 g');
    expect(plain.icon, '🛒');
    expect(ListItem.fromJson({'id': 1, 'shopping_list_id': 2, 'name': 'X'}).measureLabel, isNull);
    expect(formatAmount(0.25), '0,25');
  });

  test('articoli raggruppati per reparto e in ordine alfabetico', () {
    var id = 0;
    ListItem item(String name, String category, {bool checked = false}) => ListItem(
      id: ++id,
      listId: 1,
      name: name,
      category: category,
      status: checked ? ItemStatus.taken : ItemStatus.todo,
    );

    final groups = groupByCategory([
      item('mele', 'frutta'),
      item('spinaci', 'verdura'),
      item('pere', 'frutta'),
      item('Detersivo', 'casa'),
      item('Ananas', 'frutta', checked: true),
      item('arance', 'frutta'),
      item('boh', 'sconosciuto'),
    ], defaultCategoryOrder);

    expect(groups.map((g) => g.category), ['frutta', 'verdura', 'casa', 'sconosciuto']);
    // Prima quelli da prendere in ordine alfabetico, poi quelli già nel carrello.
    expect(groups.first.items.map((i) => i.name), ['arance', 'mele', 'pere', 'Ananas']);
    expect(groups[1].items.single.name, 'spinaci');
  });

  test('modo di misura: sfuso a peso, a peso e pezzi, in confezione', () {
    expect(MeasureMode.fromJson('weight'), MeasureMode.weight);
    expect(MeasureMode.fromJson('weight_count'), MeasureMode.weightCount);
    expect(MeasureMode.fromJson('count'), MeasureMode.count);
    expect(MeasureMode.fromJson(null), isNull);
    // Salumi e formaggi al banco: solo peso. Mele: peso e pezzi. Kinder: solo confezioni. Sconosciuto: tutto.
    expect([MeasureMode.weight.asksQuantity, MeasureMode.weight.asksWeight], [false, true]);
    expect([MeasureMode.weightCount.asksQuantity, MeasureMode.weightCount.asksWeight], [true, true]);
    expect([MeasureMode.count.asksQuantity, MeasureMode.count.asksWeight], [true, false]);
    const MeasureMode? unknown = null;
    expect([unknown.asksQuantity, unknown.asksWeight, unknown.isLoose], [true, true, false]);

    final item = ListItem.fromJson({'id': 1, 'shopping_list_id': 1, 'name': 'Salame', 'measure': 'weight'});
    expect(item.measure, MeasureMode.weight);
    expect(item.copyWith(status: ItemStatus.taken).measure, MeasureMode.weight);
    final suggestion = ProductSuggestion.fromJson({'name': 'Mele', 'icon': '🍎', 'measure': 'weight_count'});
    expect(suggestion.measure, MeasureMode.weightCount);
  });
}
