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

/// Da dove viene il prezzo mostrato per un articolo: segnalato da un utente, da Open Prices o dal listino.
class PriceInfo {
  const PriceInfo({
    required this.price,
    required this.per,
    required this.source,
    this.reporter,
    this.observedAt,
    this.country,
    this.city,
    this.locality,
    this.supermarket,
    this.productName,
  });

  /// Prezzo a confezione (per = pz), al kg o al litro.
  final double price;
  final String per;

  /// user, open_prices oppure catalog.
  final String source;

  /// Nome di chi l'ha segnalato (null se l'account è stato eliminato); l'email non arriva mai all'app.
  final String? reporter;
  final DateTime? observedAt;
  final String? country;
  final String? city;
  final String? locality;

  /// Solo nello storico: catena e prodotto a cui si riferisce la segnalazione.
  final String? supermarket;
  final String? productName;

  bool get fromUser => source == 'user';

  /// Es. "Milano, Città Studi".
  String? get zone {
    final parts = [?city, ?locality].where((p) => p.trim().isNotEmpty).toList();
    return parts.isEmpty ? null : parts.join(', ');
  }

  factory PriceInfo.fromJson(Map<String, dynamic> json) => PriceInfo(
    price: (json['price'] as num).toDouble(),
    per: json['per'] as String? ?? 'pz',
    source: json['source'] as String? ?? 'catalog',
    reporter: json['reporter'] as String?,
    observedAt: json['observed_at'] == null ? null : DateTime.parse(json['observed_at'] as String).toLocal(),
    country: json['country'] as String?,
    city: json['city'] as String?,
    locality: json['locality'] as String?,
    supermarket: json['supermarket'] as String?,
    productName: json['product_name'] as String?,
  );
}

/// Prezzi di un articolo nella catena della lista: quello mostrato e le segnalazioni, dalla più recente.
class ItemPrices {
  const ItemPrices({this.supermarket, this.current, this.reports = const []});

  final String? supermarket;
  final PriceInfo? current;
  final List<PriceInfo> reports;

  factory ItemPrices.fromJson(Map<String, dynamic> json) => ItemPrices(
    supermarket: json['supermarket'] as String?,
    current: json['current'] == null ? null : PriceInfo.fromJson(json['current'] as Map<String, dynamic>),
    reports: (json['reports'] as List<dynamic>? ?? [])
        .map((e) => PriceInfo.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}
