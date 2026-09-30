import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../l10n/l10n.dart';
import '../models/supermarket.dart';
import '../services/api_client.dart';

/// 1.5 → "1,50 €", in CHF "1,50 CHF", in USD "1,50 $" (nel formato della lingua dell'app).
String formatPrice(BuildContext context, double value, [String currency = 'EUR']) =>
    NumberFormat.simpleCurrency(locale: Localizations.localeOf(context).toLanguageTag(), name: currency).format(value);

/// Popup con il costo della lista in ogni catena che ha dei prezzi: una fisarmonica con nome, descrizione e totale;
/// toccando una catena si aprono i prezzi articolo per articolo.
Future<void> showPriceComparison(BuildContext context, int listId) => showDialog<void>(
  context: context,
  builder: (_) => _PriceComparisonDialog(api: context.read<ApiClient>(), listId: listId),
);

class _PriceComparisonDialog extends StatefulWidget {
  const _PriceComparisonDialog({required this.api, required this.listId});

  final ApiClient api;
  final int listId;

  @override
  State<_PriceComparisonDialog> createState() => _PriceComparisonDialogState();
}

class _PriceComparisonDialogState extends State<_PriceComparisonDialog> {
  late Future<List<PriceComparison>> _rows = widget.api.priceComparison(widget.listId);

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    return AlertDialog(
      title: Text(l.compareChains),
      contentPadding: const EdgeInsets.fromLTRB(8, 16, 8, 0),
      content: SizedBox(
        width: double.maxFinite,
        child: FutureBuilder<List<PriceComparison>>(
          future: _rows,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const SizedBox(height: 120, child: Center(child: CircularProgressIndicator()));
            }
            if (snapshot.hasError) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('${snapshot.error}', textAlign: TextAlign.center),
                  TextButton(
                    onPressed: () => setState(() => _rows = widget.api.priceComparison(widget.listId)),
                    child: Text(l.retry),
                  ),
                ],
              );
            }
            final rows = snapshot.data!;
            if (rows.isEmpty) {
              return Padding(
                padding: const EdgeInsets.all(16),
                child: Text(l.noChainPrices, textAlign: TextAlign.center),
              );
            }
            // Poche catene: una colonna che scorre, alta quanto serve (fino al limite del dialogo).
            return SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final row in rows) _ChainTile(row: row),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: Text(
                      l.pricesIndicativeNote,
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text(l.close))],
    );
  }
}

class _ChainTile extends StatelessWidget {
  const _ChainTile({required this.row});

  final PriceComparison row;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final chain = row.supermarket;
    return Card(
      clipBehavior: Clip.antiAlias,
      color: row.current ? theme.colorScheme.primaryContainer : null,
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ExpansionTile(
        shape: const Border(),
        title: Text(row.current ? '${chain.name} · ${l.currentChain}' : chain.name),
        subtitle: Text(
          [
            ?chain.description,
            if (row.pricedCount < row.itemsCount) l.pricedOf(row.pricedCount, row.itemsCount),
          ].join('\n'),
        ),
        trailing: Text(
          '${formatPrice(context, row.total, row.currency)}*',
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        children: [
          for (final item in row.items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  Text(item.icon),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item.name,
                      style: item.missing ? TextStyle(color: muted, decoration: TextDecoration.lineThrough) : null,
                    ),
                  ),
                  Text(
                    item.price == null ? '—' : formatPrice(context, item.price!, item.currency),
                    style: TextStyle(color: item.price == null || item.missing ? muted : null),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
