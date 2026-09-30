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
    this.currency = 'EUR',
    required this.pricedCount,
    required this.itemsCount,
    required this.items,
  });

  final Supermarket supermarket;

  /// È la catena scelta per la lista.
  final bool current;

  /// Totale stimato degli articoli con un prezzo (i non trovati non contano).
  final double total;
  final String currency;
  final int pricedCount;
  final int itemsCount;
  final List<ComparedItem> items;

  factory PriceComparison.fromJson(Map<String, dynamic> json) => PriceComparison(
    supermarket: Supermarket.fromJson(json),
    current: json['current'] as bool? ?? false,
    total: (json['total'] as num).toDouble(),
    currency: json['currency'] as String? ?? 'EUR',
    pricedCount: json['priced_count'] as int? ?? 0,
    itemsCount: json['items_count'] as int? ?? 0,
    items: (json['items'] as List<dynamic>? ?? [])
        .map((e) => ComparedItem.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}

/// Un articolo della lista con il suo prezzo in una catena (null se la catena non ce l'ha).
class ComparedItem {
  const ComparedItem({
    required this.id,
    required this.name,
    required this.icon,
    this.price,
    this.currency = 'EUR',
    this.missing = false,
  });

  final int id;
  final String name;
  final String icon;
  final double? price;
  final String currency;

  /// Segnato come non trovato: non conta nel totale.
  final bool missing;

  factory ComparedItem.fromJson(Map<String, dynamic> json) => ComparedItem(
    id: json['id'] as int,
    name: json['name'] as String,
    icon: json['icon'] as String? ?? '🛒',
    price: (json['price'] as num?)?.toDouble(),
    currency: json['currency'] as String? ?? 'EUR',
    missing: json['status'] == 'missing',
  );
}

/// Un prezzo di un prodotto in una catena: proposto da un utente o importato da Open Prices, con le sue conferme.
class PriceInfo {
  const PriceInfo({
    this.reportId,
    this.line,
    required this.price,
    this.currency = 'EUR',
    required this.per,
    required this.source,
    this.reporter,
    this.observedAt,
    this.country,
    this.province,
    this.city,
    this.locality,
    this.supermarket,
    this.productName,
    this.status = 'approved',
    this.approvals = 0,
    this.rejections = 0,
    this.mine = false,
    this.myVote,
    this.nearby = false,
  });

  final int? reportId;

  /// Prezzo dell'articolo con quantità e peso (solo per la propria proposta in attesa).
  final double? line;

  /// Prezzo a confezione (per = pz), al kg o al litro.
  final double price;

  /// Valuta del prezzo (ISO), es. EUR, CHF, NOK.
  final String currency;
  final String per;

  /// user oppure open_prices.
  final String source;

  /// Nome di chi l'ha segnalato (null se l'account è stato eliminato); l'email non arriva mai all'app.
  final String? reporter;
  final DateTime? observedAt;
  final String? country;
  final String? province;
  final String? city;
  final String? locality;

  /// Solo nello storico: catena e prodotto a cui si riferisce la segnalazione.
  final String? supermarket;
  final String? productName;

  /// pending (proposto, in attesa di conferma), approved (visibile a tutti) o rejected (smentito).
  final String status;
  final int approvals;
  final int rejections;

  /// Solo nello storico: proposto da me, il mio voto (true = confermato, false = smentito), nella mia città.
  final bool mine;
  final bool? myVote;
  final bool nearby;

  bool get fromUser => source == 'user';
  bool get pending => status == 'pending';
  bool get rejected => status == 'rejected';

  /// Es. "Milano, Città Studi".
  String? get zone {
    final parts = [?city, ?locality].where((p) => p.trim().isNotEmpty).toList();
    return parts.isEmpty ? null : parts.join(', ');
  }

  factory PriceInfo.fromJson(Map<String, dynamic> json) => PriceInfo(
    reportId: (json['report_id'] ?? json['id']) as int?,
    line: (json['line'] as num?)?.toDouble(),
    price: (json['price'] as num).toDouble(),
    currency: json['currency'] as String? ?? 'EUR',
    per: json['per'] as String? ?? 'pz',
    source: json['source'] as String? ?? 'open_prices',
    reporter: json['reporter'] as String?,
    observedAt: json['observed_at'] == null ? null : DateTime.parse(json['observed_at'] as String).toLocal(),
    country: json['country'] as String?,
    province: json['province'] as String?,
    city: json['city'] as String?,
    locality: json['locality'] as String?,
    supermarket: json['supermarket'] as String?,
    productName: json['product_name'] as String?,
    status: json['status'] as String? ?? 'approved',
    approvals: json['approvals'] as int? ?? 0,
    rejections: json['rejections'] as int? ?? 0,
    mine: json['mine'] as bool? ?? false,
    myVote: json['my_vote'] as bool?,
    nearby: json['nearby'] as bool? ?? false,
  );
}

/// Prezzi di un articolo nella catena della lista: quello mostrato (il più confermato della zona più vicina),
/// la mia proposta in attesa e tutti i prezzi, dalla zona più vicina e con più conferme.
class ItemPrices {
  const ItemPrices({this.supermarket, this.current, this.mine, this.reports = const []});

  final String? supermarket;
  final PriceInfo? current;
  final PriceInfo? mine;
  final List<PriceInfo> reports;

  factory ItemPrices.fromJson(Map<String, dynamic> json) => ItemPrices(
    supermarket: json['supermarket'] as String?,
    current: json['current'] == null ? null : PriceInfo.fromJson(json['current'] as Map<String, dynamic>),
    mine: json['mine'] == null ? null : PriceInfo.fromJson(json['mine'] as Map<String, dynamic>),
    reports: (json['reports'] as List<dynamic>? ?? [])
        .map((e) => PriceInfo.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}
