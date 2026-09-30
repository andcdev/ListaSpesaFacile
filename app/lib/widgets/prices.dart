import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../l10n/l10n.dart';
import '../models/user_price.dart';

/// 1.5 → "1,50 €" (nel formato della lingua dell'app).
String formatPrice(BuildContext context, double value) =>
    NumberFormat.simpleCurrency(locale: Localizations.localeOf(context).toLanguageTag(), name: 'EUR').format(value);

/// "a confezione", "al kg", "al litro".
String perLabel(String per, AppLocalizations l) => switch (per) {
  'kg' => l.perKg,
  'l' => l.perLitre,
  _ => l.perPiece,
};

/// Nuovo prezzo personale ([initial] senza id) o modifica di uno esistente: prodotto, prezzo, a confezione / al kg /
/// al litro, supermercato e nota. Restituisce il prezzo compilato (con l'id di [initial]) o null se annullato.
Future<UserPrice?> showMyPriceDialog(BuildContext context, {required UserPrice initial, bool editing = false}) =>
    showDialog<UserPrice>(
      context: context,
      builder: (_) => _MyPriceDialog(initial: initial, editing: editing),
    );

class _MyPriceDialog extends StatefulWidget {
  const _MyPriceDialog({required this.initial, required this.editing});

  final UserPrice initial;
  final bool editing;

  @override
  State<_MyPriceDialog> createState() => _MyPriceDialogState();
}

class _MyPriceDialogState extends State<_MyPriceDialog> {
  late final _product = TextEditingController(text: widget.initial.productName);
  late final _price = TextEditingController(
    text: widget.initial.price > 0 ? widget.initial.price.toStringAsFixed(2).replaceAll('.', ',') : '',
  );
  late final _supermarket = TextEditingController(text: widget.initial.supermarket);
  late final _note = TextEditingController(text: widget.initial.note);
  late String _per = widget.initial.per;
  String? _productError;
  String? _priceError;

  @override
  void dispose() {
    for (final c in [_product, _price, _supermarket, _note]) {
      c.dispose();
    }
    super.dispose();
  }

  void _confirm() {
    final l = context.l10n;
    final product = _product.text.trim();
    final price = double.tryParse(_price.text.trim().replaceAll('€', '').replaceAll(',', '.'));
    setState(() {
      _productError = product.isEmpty ? l.productRequired : null;
      _priceError = price == null || price < 0.01 ? l.invalidPrice : null;
    });
    if (_productError != null || _priceError != null) return;
    String? text(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();
    Navigator.pop(
      context,
      UserPrice(
        id: widget.initial.id,
        productName: product,
        price: price!,
        per: _per,
        barcode: widget.initial.barcode,
        brand: widget.initial.brand,
        supermarket: text(_supermarket),
        note: text(_note),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    return AlertDialog(
      title: Text(widget.editing ? l.editMyPrice : l.addMyPrice),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _product,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(labelText: l.product, errorText: _productError),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _price,
              autofocus: widget.initial.productName.isNotEmpty,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onSubmitted: (_) => _confirm(),
              decoration: InputDecoration(labelText: l.priceLabel, suffixText: '€', errorText: _priceError),
            ),
            const SizedBox(height: 12),
            SegmentedButton<String>(
              segments: [
                for (final per in const ['pz', 'kg', 'l']) ButtonSegment(value: per, label: Text(perLabel(per, l))),
              ],
              selected: {_per},
              showSelectedIcon: false,
              onSelectionChanged: (v) => setState(() => _per = v.single),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _supermarket,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(labelText: l.supermarketLabel),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _note,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(labelText: l.noteOptional),
            ),
            if (widget.initial.barcode != null) ...[
              const SizedBox(height: 8),
              Text('${l.barcode}: ${widget.initial.barcode}', style: theme.textTheme.bodySmall),
            ],
            const SizedBox(height: 8),
            Text(
              l.myPricesPrivate,
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l.cancel)),
        FilledButton(onPressed: _confirm, child: Text(l.save)),
      ],
    );
  }
}
