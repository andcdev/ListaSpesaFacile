import 'package:flutter_test/flutter_test.dart';
import 'package:lista_spesa_facile/models/app_user.dart';
import 'package:lista_spesa_facile/models/list_filter.dart';
import 'package:lista_spesa_facile/models/shopping_list.dart';

void main() {
  const me = AppUser(id: 1, name: 'Io', email: 'io@example.com');
  const anna = AppUser(id: 2, name: 'Anna', email: 'anna@example.com');
  const bruno = AppUser(id: 3, name: 'bruno', email: 'bruno@example.com');
  final now = DateTime(2026, 10, 15, 10);
  ShoppingList list(int id, DateTime at, {AppUser owner = me, List<AppUser> shared = const []}) =>
      ShoppingList(id: id, name: 'L$id', scheduledAt: at, owner: owner, sharedWith: shared, permission: 'owner');

  final past = [
    list(1, DateTime(2026, 10, 14, 18)), // ieri
    list(2, DateTime(2026, 10, 1), shared: [anna]), // 14 giorni fa
    list(3, DateTime(2026, 9, 20), owner: anna), // 25 giorni fa
    list(4, DateTime(2026, 8, 1), shared: [bruno]), // 75 giorni fa
  ];
  final upcoming = [
    list(5, DateTime(2026, 10, 15, 18)), // oggi
    list(6, DateTime(2026, 10, 25), shared: [anna]),
    list(7, DateTime(2026, 11, 20)),
  ];
  List<int> ids(List<ShoppingList> lists) => [for (final l in lists) l.id];

  test('ordine predefinito: in programma dalla più vicina, passate dalla più recente; si può invertire', () {
    expect(ids(const ListFilter().apply(upcoming.reversed.toList(), past: false, now: now)), [5, 6, 7]);
    expect(ids(const ListFilter().apply(past.reversed.toList(), past: true, now: now)), [1, 2, 3, 4]);
    expect(ids(const ListFilter(ascending: true).apply(past, past: true, now: now)), [4, 3, 2, 1]);
    expect(ids(const ListFilter(ascending: false).apply(upcoming, past: false, now: now)), [7, 6, 5]);
    expect(const ListFilter().isActive, isFalse);
    expect(const ListFilter(ascending: true).isActive, isTrue);
  });

  test('ultimi o prossimi 15 e 30 giorni, e intervallo da… a… con gli estremi inclusi', () {
    expect(ids(const ListFilter(period: ListPeriod.days15).apply(past, past: true, now: now)), [1, 2]);
    expect(ids(const ListFilter(period: ListPeriod.days30).apply(past, past: true, now: now)), [1, 2, 3]);
    expect(ids(const ListFilter(period: ListPeriod.days15).apply(upcoming, past: false, now: now)), [5, 6]);
    expect(ids(const ListFilter(period: ListPeriod.days30).apply(upcoming, past: false, now: now)), [5, 6]);
    final range = ListFilter(period: ListPeriod.range, from: DateTime(2026, 9, 20), to: DateTime(2026, 10, 1));
    expect(ids(range.apply(past, past: true, now: now)), [2, 3]);
  });

  test('per persona (proprietaria o invitata) e per prodotto trovato dal server', () {
    expect(ids(const ListFilter(personId: 2).apply(past, past: true, now: now)), [2, 3]);
    expect(ids(const ListFilter(personId: 3).apply(past + upcoming, past: true, now: now)), [4]);
    expect(ids(const ListFilter(product: 'latte', productListIds: {1, 6}).apply(past, past: true, now: now)), [1]);
    // Finché il server non risponde non si nasconde niente.
    expect(ids(const ListFilter(product: 'latte').apply(past, past: true, now: now)), [1, 2, 3, 4]);
  });

  test('persone con cui si condivide: proprietari e invitati, senza di me, per nome', () {
    expect([for (final p in peopleIn(past + upcoming, me.id)) p.name], ['Anna', 'bruno']);
  });
}
