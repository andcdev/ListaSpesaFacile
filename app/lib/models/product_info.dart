/// Scheda di un prodotto da Open Food Facts (menu ⋮ → Info): codice a barre, foto, valori nutrizionali,
/// ingredienti, allergeni e se è adatto a celiaci, vegetariani e vegani (true = sì, false = no, null = non si sa).
class ProductInfo {
  const ProductInfo({
    required this.barcode,
    required this.name,
    this.brand,
    this.quantity,
    this.images = const [],
    this.nutriments = const {},
    this.isWater = false,
    this.minerals = const {},
    this.ingredients,
    this.allergens = const [],
    this.traces = const [],
    this.glutenFree,
    this.lactoseFree,
    this.vegetarian,
    this.vegan,
    this.palmOilFree,
    this.nutriscore,
    this.nova,
    this.url,
    this.matchedByName = false,
  });

  final String barcode;
  final String name;
  final String? brand;
  final String? quantity;

  /// Confezione, ingredienti, tabella nutrizionale, imballaggio.
  final List<String> images;

  /// Per 100 g o 100 ml: energy-kcal, fat, saturated-fat, carbohydrates, sugars, fiber, proteins, salt.
  final Map<String, double?> nutriments;

  /// Acqua: al posto dei valori nutrizionali ha i minerali in mg/L (calcium, magnesium, sodium, potassium,
  /// bicarbonate, chloride, sulphate, nitrate, fluoride, silica).
  final bool isWater;
  final Map<String, double?> minerals;
  final String? ingredients;

  /// Allergeni e tracce come tag di Open Food Facts senza lingua ("milk", "gluten", "nuts"…).
  final List<String> allergens;
  final List<String> traces;
  final bool? glutenFree;
  final bool? lactoseFree;
  final bool? vegetarian;
  final bool? vegan;
  final bool? palmOilFree;

  /// Nutri-Score (a–e) e gruppo NOVA (1–4).
  final String? nutriscore;
  final int? nova;

  /// Pagina del prodotto su Open Food Facts.
  final String? url;

  /// L'articolo era scritto a mano: è il prodotto più simile al nome, non quello esatto.
  final bool matchedByName;

  factory ProductInfo.fromJson(Map<String, dynamic> json) {
    List<String> strings(String key) => (json[key] as List<dynamic>? ?? []).whereType<String>().toList();
    // Un oggetto JSON vuoto arriva da PHP come lista vuota.
    Map<String, double?> numbers(String key) => switch (json[key]) {
      final Map<String, dynamic> map => map.map((k, v) => MapEntry(k, (v as num?)?.toDouble())),
      _ => const {},
    };
    return ProductInfo(
      barcode: json['barcode'] as String? ?? '',
      name: json['name'] as String? ?? '',
      brand: json['brand'] as String?,
      quantity: json['quantity'] as String?,
      images: strings('images'),
      nutriments: numbers('nutriments'),
      isWater: json['kind'] == 'water',
      minerals: numbers('minerals'),
      ingredients: json['ingredients'] as String?,
      allergens: strings('allergens'),
      traces: strings('traces'),
      glutenFree: json['gluten_free'] as bool?,
      lactoseFree: json['lactose_free'] as bool?,
      vegetarian: json['vegetarian'] as bool?,
      vegan: json['vegan'] as bool?,
      palmOilFree: json['palm_oil_free'] as bool?,
      nutriscore: json['nutriscore'] as String?,
      nova: json['nova'] as int?,
      url: json['url'] as String?,
      matchedByName: json['matched_by'] == 'name',
    );
  }
}
