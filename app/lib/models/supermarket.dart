/// Catena di supermercati (distribuzione) riconosciuta dal server, con i suoi prezzi indicativi.
class Supermarket {
  const Supermarket({required this.id, required this.name, this.description, this.hasPrices = true});

  final int id;
  final String name;

  /// Es. "Discount, in tutta Italia".
  final String? description;

  /// Il server ha dei prezzi per questa catena.
  final bool hasPrices;

  factory Supermarket.fromJson(Map<String, dynamic> json) => Supermarket(
    id: json['id'] as int,
    name: json['name'] as String,
    description: json['description'] as String?,
    hasPrices: json['has_prices'] as bool? ?? true,
  );
}

/// Quanto costerebbe la lista in una catena (GET /lists/{id}/price-comparison).
class PriceComparison {
  const PriceComparison({
    required this.supermarket,
    required this.current,
    required this.total,
    required this.pricedCount,
    required this.itemsCount,
    required this.items,
  });

  final Supermarket supermarket;

  /// È la catena scelta per la lista.
  final bool current;

  /// Totale stimato degli articoli con un prezzo (i non trovati non contano).
  final double total;
  final int pricedCount;
  final int itemsCount;
  final List<ComparedItem> items;

  factory PriceComparison.fromJson(Map<String, dynamic> json) => PriceComparison(
    supermarket: Supermarket.fromJson(json),
    current: json['current'] as bool? ?? false,
    total: (json['total'] as num).toDouble(),
    pricedCount: json['priced_count'] as int? ?? 0,
    itemsCount: json['items_count'] as int? ?? 0,
    items: (json['items'] as List<dynamic>? ?? [])
        .map((e) => ComparedItem.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}

/// Un articolo della lista con il suo prezzo in una catena (null se la catena non ce l'ha).
class ComparedItem {
  const ComparedItem({required this.id, required this.name, required this.icon, this.price, this.missing = false});

  final int id;
  final String name;
  final String icon;
  final double? price;

  /// Segnato come non trovato: non conta nel totale.
  final bool missing;

  factory ComparedItem.fromJson(Map<String, dynamic> json) => ComparedItem(
    id: json['id'] as int,
    name: json['name'] as String,
    icon: json['icon'] as String? ?? '🛒',
    price: (json['price'] as num?)?.toDouble(),
    missing: json['status'] == 'missing',
  );
}
