import 'measure_mode.dart';

/// Prodotto suggerito mentre si scrive: già usato nelle liste (con quante volte) o tra i più comuni.
class ProductSuggestion {
  const ProductSuggestion({
    required this.name,
    required this.icon,
    this.category = 'altro',
    this.measure,
    this.times = 0,
  });

  final String name;
  final String icon;
  final String category;

  /// Come si misura: solo peso, peso e pezzi o confezioni (null = non si sa).
  final MeasureMode? measure;

  /// Quante volte è stato messo in lista (0 = prodotto comune mai usato).
  final int times;

  factory ProductSuggestion.fromJson(Map<String, dynamic> json) => ProductSuggestion(
    name: json['name'] as String,
    icon: json['icon'] as String? ?? '🛒',
    category: json['category'] as String? ?? 'altro',
    measure: MeasureMode.fromJson(json['measure']),
    times: json['times'] as int? ?? 0,
  );
}

/// Suggerimenti per [query]: le parole scritte devono essere l'inizio di parole del prodotto ("lat scr" →
/// "Latte parzialmente scremato"), senza badare a maiuscole e accenti. Prima quelli che iniziano proprio con
/// il testo scritto, poi i più usati. Senza testo: i prodotti comprati più spesso. Esclusi quelli già in lista.
List<ProductSuggestion> suggestProducts(
  List<ProductSuggestion> all,
  String query, {
  Iterable<String> exclude = const [],
  int limit = 8,
}) {
  final excluded = {for (final name in exclude) normalizeProductName(name)};
  final q = normalizeProductName(query);
  final candidates = all.where((s) => !excluded.contains(normalizeProductName(s.name)));

  if (q.isEmpty) {
    return candidates.where((s) => s.times > 0).take(limit).toList();
  }

  final terms = q.split(' ');
  final matches = <(ProductSuggestion, bool)>[];
  for (final s in candidates) {
    final name = normalizeProductName(s.name);
    if (name == q) continue; // già scritto per intero
    final words = name.split(' ');
    if (terms.every((t) => words.any((w) => w.startsWith(t)))) matches.add((s, name.startsWith(q)));
  }
  // Ordinamento stabile: l'ordine del server (più usati, poi comuni) resta a parità.
  final ranked = [...matches.where((m) => m.$2), ...matches.where((m) => !m.$2)];
  return ranked.map((m) => m.$1).take(limit).toList();
}

/// Minuscolo, senza accenti né spazi doppi: "Caffè  Lungo" → "caffe lungo".
String normalizeProductName(String name) {
  const accents = {'à': 'a', 'á': 'a', 'è': 'e', 'é': 'e', 'ì': 'i', 'í': 'i', 'ò': 'o', 'ó': 'o', 'ù': 'u', 'ú': 'u'};
  final lower = name.toLowerCase().trim().split('').map((c) => accents[c] ?? c).join();
  return lower.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).join(' ');
}
