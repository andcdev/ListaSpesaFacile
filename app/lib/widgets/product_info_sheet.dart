import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/l10n.dart';
import '../models/list_item.dart';
import '../models/product_info.dart';
import 'photo_gallery.dart';
import 'ui.dart';

/// Scheda "Info" di un articolo (menu ⋮): codice a barre, foto, se è adatto a celiaci, vegetariani e vegani,
/// calorie e valori nutrizionali (per le acque i minerali in mg/L), allergeni, ingredienti, Nutri-Score e NOVA,
/// da Open Food Facts.
Future<void> showProductInfo(BuildContext context, {required ListItem item, required Future<ProductInfo?> info}) =>
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => _ProductInfoSheet(item: item, info: info),
    );

/// Nome di un allergene di Open Food Facts ("milk" → "Latte"); quelli non noti come scritti ("sesame-seeds" → "sesame seeds").
String allergenLabel(String tag, AppLocalizations l) => switch (tag) {
  'gluten' => l.allergenGluten,
  'crustaceans' => l.allergenCrustaceans,
  'eggs' => l.allergenEggs,
  'fish' => l.allergenFish,
  'peanuts' => l.allergenPeanuts,
  'soybeans' => l.allergenSoybeans,
  'milk' => l.allergenMilk,
  'nuts' => l.allergenNuts,
  'celery' => l.allergenCelery,
  'mustard' => l.allergenMustard,
  'sesame-seeds' => l.allergenSesame,
  'sulphur-dioxide-and-sulphites' => l.allergenSulphites,
  'lupin' => l.allergenLupin,
  'molluscs' => l.allergenMolluscs,
  _ => tag.replaceAll('-', ' '),
};

class _ProductInfoSheet extends StatelessWidget {
  const _ProductInfoSheet({required this.item, required this.info});

  final ListItem item;
  final Future<ProductInfo?> info;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.85),
        child: FutureBuilder<ProductInfo?>(
          future: info,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const SizedBox(height: 160, child: Center(child: CircularProgressIndicator()));
            }
            if (snapshot.hasError) {
              return Padding(
                padding: const EdgeInsets.all(24),
                child: Text('${snapshot.error}', textAlign: TextAlign.center),
              );
            }
            final p = snapshot.data;
            if (p == null) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('${item.icon}  ${item.name}', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 12),
                    Text(l.noProductInfo, textAlign: TextAlign.center),
                  ],
                ),
              );
            }
            return _Details(item: item, product: p);
          },
        ),
      ),
    );
  }
}

class _Details extends StatelessWidget {
  const _Details({required this.item, required this.product});

  final ListItem item;
  final ProductInfo product;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final p = product;
    final kcal = p.nutriments['energy-kcal'];
    String number(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toString().replaceAll('.', ',');
    final nutrients = {
      'fat': l.nutrientFat,
      'saturated-fat': l.nutrientSaturatedFat,
      'carbohydrates': l.nutrientCarbohydrates,
      'sugars': l.nutrientSugars,
      'fiber': l.nutrientFiber,
      'proteins': l.nutrientProteins,
      'salt': l.nutrientSalt,
    };
    final minerals = {
      'calcium': l.mineralCalcium,
      'magnesium': l.mineralMagnesium,
      'sodium': l.mineralSodium,
      'potassium': l.mineralPotassium,
      'bicarbonate': l.mineralBicarbonate,
      'chloride': l.mineralChloride,
      'sulphate': l.mineralSulphate,
      'nitrate': l.mineralNitrate,
      'fluoride': l.mineralFluoride,
      'silica': l.mineralSilica,
    };
    // Solo le voci con un valore: "non indicato" non dice niente a chi legge.
    final suitability = [
      if (p.glutenFree != null)
        _Suitability(label: l.forCoeliacs, value: p.glutenFree!, yes: l.glutenFree, no: l.containsGluten),
      if (p.vegetarian != null) _Suitability(label: l.vegetarian, value: p.vegetarian!, yes: l.yes, no: l.no),
      if (p.vegan != null) _Suitability(label: l.vegan, value: p.vegan!, yes: l.yes, no: l.no),
      if (p.palmOilFree != null)
        _Suitability(label: l.palmOil, value: p.palmOilFree!, yes: l.palmOilFree, no: l.containsPalmOil),
      if (p.lactoseFree == true) _Suitability(label: l.lactose, value: true, yes: l.lactoseFree, no: ''),
    ];
    Widget row(String label, String value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(value),
        ],
      ),
    );
    final mineralRows = [
      for (final MapEntry(key: key, value: label) in minerals.entries)
        if (p.minerals[key] != null) row(label, '${number(p.minerals[key]!)} mg/L'),
    ];
    final nutrientRows = [
      for (final MapEntry(key: key, value: label) in nutrients.entries)
        if (p.nutriments[key] != null) row(label, '${number(p.nutriments[key]!)} g'),
    ];

    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      children: [
        Text(p.name.isEmpty ? item.name : p.name, style: theme.textTheme.titleLarge),
        if (p.brand != null || p.quantity != null)
          Text([?p.brand, ?p.quantity].join(' · '), style: theme.textTheme.bodyMedium?.copyWith(color: muted)),
        if (p.matchedByName)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(l.similarProductNotice, style: theme.textTheme.bodySmall?.copyWith(color: muted)),
          ),
        if (p.images.isNotEmpty) ...[
          const SizedBox(height: 12),
          SizedBox(
            height: 96,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: p.images.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, i) => GestureDetector(
                onTap: () => showPhotoGallery(context, [
                  for (final url in p.images.sublist(i)) NetworkImage(url),
                  for (final url in p.images.sublist(0, i)) NetworkImage(url),
                ], caption: p.name),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    p.images[i],
                    width: 96,
                    height: 96,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const SizedBox(width: 96, child: Icon(Icons.broken_image_outlined)),
                  ),
                ),
              ),
            ),
          ),
        ],
        const SizedBox(height: 12),
        if (p.barcode.isNotEmpty)
          ListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            leading: const Icon(Icons.qr_code_2),
            title: Text(l.barcode),
            subtitle: Text(p.barcode),
            trailing: IconButton(
              tooltip: l.copy,
              icon: const Icon(Icons.copy),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: p.barcode));
                showMessage(context, l.copied);
              },
            ),
          ),
        if (suitability.isNotEmpty) Wrap(spacing: 8, runSpacing: 8, children: suitability),
        const SizedBox(height: 16),
        // Acqua: i minerali in mg/L. Cibo e bevande: calorie e valori nutrizionali per 100 g.
        if (p.isWater && mineralRows.isNotEmpty) ...[
          Text(l.waterMinerals, style: theme.textTheme.titleSmall),
          ...mineralRows,
        ] else if (!p.isWater && (kcal != null || nutrientRows.isNotEmpty)) ...[
          Text(l.nutritionPer100, style: theme.textTheme.titleSmall),
          if (kcal != null)
            Text('${number(kcal)} kcal', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
          ...nutrientRows,
        ] else
          Text(l.noNutritionInfo, style: theme.textTheme.bodyMedium?.copyWith(color: muted)),
        if (p.allergens.isNotEmpty || p.traces.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(l.allergens, style: theme.textTheme.titleSmall),
          if (p.allergens.isNotEmpty) Text(p.allergens.map((a) => allergenLabel(a, l)).join(', ')),
          if (p.traces.isNotEmpty)
            Text(
              l.mayContainTraces(p.traces.map((a) => allergenLabel(a, l)).join(', ')),
              style: theme.textTheme.bodySmall,
            ),
        ],
        if (p.ingredients != null) ...[
          const SizedBox(height: 16),
          Text(l.ingredients, style: theme.textTheme.titleSmall),
          Text(p.ingredients!),
        ],
        if (p.nutriscore != null || p.nova != null) ...[
          const SizedBox(height: 16),
          Text(
            [
              if (p.nutriscore != null) 'Nutri-Score ${p.nutriscore!.toUpperCase()}',
              if (p.nova != null) 'NOVA ${p.nova}',
            ].join(' · '),
            style: theme.textTheme.titleSmall,
          ),
        ],
        const SizedBox(height: 16),
        if (p.url != null)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => launchUrl(Uri.parse(p.url!), mode: LaunchMode.externalApplication),
              icon: const Icon(Icons.open_in_new),
              label: Text(l.openFoodFactsPage),
            ),
          ),
        Text(l.openFoodFactsSource, style: theme.textTheme.bodySmall?.copyWith(color: muted)),
      ],
    );
  }
}

/// Adatto sì / no, con un colore.
class _Suitability extends StatelessWidget {
  const _Suitability({required this.label, required this.value, required this.yes, required this.no});

  final String label;
  final bool value;
  final String yes;
  final String no;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (icon, color, text) = value
        ? (Icons.check_circle, Colors.green.shade700, yes)
        : (Icons.cancel, scheme.error, no);
    return Chip(
      avatar: Icon(icon, size: 18, color: color),
      label: Text('$label: $text'),
      visualDensity: VisualDensity.compact,
    );
  }
}
