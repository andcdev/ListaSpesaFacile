import 'app_user.dart';
import 'shopping_list.dart';

/// Periodo delle liste (per data dell'evento): in "Passate" gli ultimi giorni, in "In programma" i prossimi.
enum ListPeriod { all, days15, days30, range }

/// Filtri e ordine dell'elenco delle liste, uno per sezione ("In programma", "Passate").
class ListFilter {
  const ListFilter({
    this.ascending,
    this.personId,
    this.period = ListPeriod.all,
    this.from,
    this.to,
    this.product = '',
    this.productListIds,
  });

  /// Ordine per data dell'evento; null = quello della sezione: in programma dalla più vicina, passate dalla più
  /// recente.
  final bool? ascending;

  /// Solo le liste di questa persona o condivise con lei (null = tutti).
  final int? personId;
  final ListPeriod period;

  /// Intervallo di date (giorni interi, inclusi) per [ListPeriod.range].
  final DateTime? from;
  final DateTime? to;

  /// Nome di un prodotto: lo cerca il server negli articoli, [productListIds] sono le liste trovate.
  final String product;
  final Set<int>? productListIds;

  bool get isActive => ascending != null || personId != null || period != ListPeriod.all || product.isNotEmpty;

  ListFilter copyWith({
    bool? Function()? ascending,
    int? Function()? personId,
    ListPeriod? period,
    DateTime? Function()? from,
    DateTime? Function()? to,
    String? product,
    Set<int>? Function()? productListIds,
  }) => ListFilter(
    ascending: ascending == null ? this.ascending : ascending(),
    personId: personId == null ? this.personId : personId(),
    period: period ?? this.period,
    from: from == null ? this.from : from(),
    to: to == null ? this.to : to(),
    product: product ?? this.product,
    productListIds: productListIds == null ? this.productListIds : productListIds(),
  );

  /// Le liste della sezione ([past] = passate) filtrate e ordinate; [now] per i periodi.
  List<ShoppingList> apply(List<ShoppingList> lists, {required bool past, required DateTime now}) {
    final today = DateTime(now.year, now.month, now.day);
    final (DateTime? start, DateTime? end) = switch (period) {
      ListPeriod.all => (null, null),
      ListPeriod.days15 => past ? (today.subtract(const Duration(days: 15)), today) : (today, _days(today, 16)),
      ListPeriod.days30 => past ? (today.subtract(const Duration(days: 30)), today) : (today, _days(today, 31)),
      ListPeriod.range => (from == null ? null : _day(from!), to == null ? null : _days(_day(to!), 1)),
    };
    final shown = lists.where((l) {
      if (start != null && l.scheduledAt.isBefore(start)) return false;
      if (end != null && !l.scheduledAt.isBefore(end)) return false;
      if (personId != null && l.owner?.id != personId && !l.sharedWith.any((u) => u.id == personId)) return false;
      if (product.isNotEmpty && productListIds != null && !productListIds!.contains(l.id)) return false;
      return true;
    }).toList();
    final up = ascending ?? !past;
    shown.sort((a, b) {
      final byDate = a.scheduledAt.compareTo(b.scheduledAt);
      return up ? (byDate != 0 ? byDate : a.id.compareTo(b.id)) : (byDate != 0 ? -byDate : b.id.compareTo(a.id));
    });
    return shown;
  }

  static DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);
  static DateTime _days(DateTime d, int days) => DateTime(d.year, d.month, d.day + days);
}

/// Le persone con cui l'utente [meId] condivide le liste (proprietari e invitati), in ordine di nome.
List<AppUser> peopleIn(List<ShoppingList> lists, int? meId) {
  final people = <int, AppUser>{};
  for (final list in lists) {
    for (final user in [?list.owner, ...list.sharedWith]) {
      if (user.id != meId) people[user.id] = user;
    }
  }
  return people.values.toList()..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
}
