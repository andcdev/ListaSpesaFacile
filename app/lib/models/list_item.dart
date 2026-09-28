/// Stato di un articolo: da prendere, preso (nel carrello) o non preso (non trovato / esaurito).
enum ItemStatus {
  todo('todo'),
  taken('taken'),
  missing('missing');

  const ItemStatus(this.value);

  final String value;

  static ItemStatus parse(String? value, {bool checked = false}) =>
      ItemStatus.values.firstWhere((s) => s.value == value, orElse: () => checked ? ItemStatus.taken : ItemStatus.todo);
}

class ListItem {
  const ListItem({
    required this.id,
    required this.listId,
    required this.name,
    this.category = 'altro',
    this.icon = '🛒',
    this.customIcon,
    this.imageUrl,
    this.imageVersion,
    this.quantity,
    this.amount,
    this.unit,
    this.status = ItemStatus.todo,
    this.position = 0,
    this.createdBy,
    this.checkedBy,
  });

  final int id;
  final int listId;
  final String name;

  /// Reparto riconosciuto dal server (o scelto a mano) e icona mostrata (emoji).
  final String category;
  final String icon;

  /// Emoji scelta dall'utente (null = quella riconosciuta dal nome).
  final String? customIcon;

  /// Link a un'immagine esterna del prodotto, mostrata come miniatura.
  final String? imageUrl;

  /// Versione della foto caricata dal telefono (null se non c'è): vedi ApiClient.itemImageUrl.
  /// Se c'è ha la precedenza sul link esterno.
  final String? imageVersion;

  /// Numero di pezzi o confezioni (testo libero, es. "2").
  final String? quantity;

  /// Peso o volume, es. 500 g, 1,5 l.
  final double? amount;
  final String? unit;
  final ItemStatus status;
  final int position;
  final String? createdBy;

  /// Chi l'ha segnato come preso o non preso.
  final String? checkedBy;

  bool get checked => status == ItemStatus.taken;
  bool get missing => status == ItemStatus.missing;

  /// Es. "2 · 500 g", "1,5 l", "3": null se non ci sono né quantità né peso.
  String? get measureLabel {
    final parts = [
      if (quantity != null && quantity!.isNotEmpty) quantity!,
      if (amount != null && unit != null) '${formatAmount(amount!)} $unit',
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }

  factory ListItem.fromJson(Map<String, dynamic> json) => ListItem(
    id: json['id'] as int,
    listId: json['shopping_list_id'] as int,
    name: json['name'] as String,
    category: json['category'] as String? ?? 'altro',
    icon: json['icon'] as String? ?? '🛒',
    customIcon: json['custom_icon'] as String?,
    imageUrl: json['image_url'] as String?,
    imageVersion: json['image_version'] as String?,
    quantity: json['quantity'] as String?,
    amount: (json['amount'] as num?)?.toDouble(),
    unit: json['unit'] as String?,
    status: ItemStatus.parse(json['status'] as String?, checked: json['checked'] as bool? ?? false),
    position: json['position'] as int? ?? 0,
    createdBy: json['created_by'] as String?,
    checkedBy: json['checked_by'] as String?,
  );

  ListItem copyWith({ItemStatus? status}) => ListItem(
    id: id,
    listId: listId,
    name: name,
    category: category,
    icon: icon,
    customIcon: customIcon,
    imageUrl: imageUrl,
    imageVersion: imageVersion,
    quantity: quantity,
    amount: amount,
    unit: unit,
    status: status ?? this.status,
    position: position,
    createdBy: createdBy,
    checkedBy: checkedBy,
  );
}

/// 500 → "500", 1.5 → "1,5", 0.25 → "0,25".
String formatAmount(double value) {
  final text = value == value.roundToDouble() ? value.toInt().toString() : value.toString();
  return text.replaceAll('.', ',');
}

/// Ordine dei reparti (giro al supermercato) se il server non lo indica: come ProductCatalog::CATEGORIES.
const defaultCategoryOrder = [
  'frutta',
  'verdura',
  'pane',
  'latticini',
  'carne',
  'pesce',
  'pasta',
  'dispensa',
  'dolci',
  'bevande',
  'surgelati',
  'igiene',
  'casa',
  'animali',
  'altro',
];

/// Articoli di uno stesso reparto.
class ItemGroup {
  const ItemGroup(this.category, this.items);

  final String category;
  final List<ListItem> items;
}

/// Raggruppa per reparto nell'ordine [categoryOrder]; dentro il reparto prima quelli da prendere,
/// poi quelli presi e infine quelli non trovati, ciascuno in ordine alfabetico. Es. mele, spinaci, pere →
/// Frutta: mele, pere · Verdura: spinaci.
List<ItemGroup> groupByCategory(Iterable<ListItem> items, List<String> categoryOrder) {
  int rank(String category) {
    final i = categoryOrder.indexOf(category);
    return i < 0 ? categoryOrder.length : i;
  }

  final byCategory = <String, List<ListItem>>{};
  for (final item in items) {
    (byCategory[item.category] ??= []).add(item);
  }
  final categories = byCategory.keys.toList()..sort((a, b) => rank(a).compareTo(rank(b)));
  return [
    for (final category in categories)
      ItemGroup(
        category,
        byCategory[category]!..sort((a, b) {
          // Da prendere, poi presi, poi non presi.
          if (a.status != b.status) return a.status.index.compareTo(b.status.index);
          final byName = _sortKey(a.name).compareTo(_sortKey(b.name));
          return byName != 0 ? byName : a.id.compareTo(b.id);
        }),
      ),
  ];
}

/// Confronto alfabetico senza maiuscole né accenti ("Ananas" < "arance" < "Èrba").
String _sortKey(String name) {
  const accents = {'à': 'a', 'á': 'a', 'è': 'e', 'é': 'e', 'ì': 'i', 'í': 'i', 'ò': 'o', 'ó': 'o', 'ù': 'u', 'ú': 'u'};
  return name.toLowerCase().split('').map((c) => accents[c] ?? c).join();
}
