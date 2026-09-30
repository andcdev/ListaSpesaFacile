import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../l10n/l10n.dart';
import '../models/list_item.dart';
import '../models/shopping_list.dart';
import '../models/supermarket.dart';
import '../services/api_client.dart';
import 'price_comparison.dart';
import 'ui.dart';

/// Rettifica scelta nel dialogo: prezzo, a cosa si riferisce (pz, kg, l) e zona.
typedef PriceCorrection = ({double price, String per, String? city, String? locality});

/// Scheda del prezzo di un articolo: il prezzo mostrato e da dove viene (chi l'ha segnalato, quando, dove),
/// le segnalazioni precedenti nella stessa catena e il pulsante per correggerlo.
Future<void> showItemPriceSheet(
  BuildContext context, {
  required ApiClient api,
  required ShoppingList list,
  required ListItem item,
  required Future<void> Function(PriceCorrection correction) onCorrect,
}) => showModalBottomSheet<void>(
  context: context,
  showDragHandle: true,
  isScrollControlled: true,
  builder: (_) => _ItemPriceSheet(api: api, list: list, item: item, onCorrect: onCorrect),
);

/// "a confezione", "al kg", "al litro".
String perLabel(String per, AppLocalizations l) => switch (per) {
  'kg' => l.perKg,
  'l' => l.perLitre,
  _ => l.perPiece,
};

/// Es. "Mario · 12 set, 18:30 · Milano" oppure "Open Prices · 5 set 2026 · Milano" oppure "Listino indicativo".
String priceSourceLabel(PriceInfo info, AppLocalizations l, String locale) {
  final when = info.observedAt == null ? null : DateFormat.yMMMd(locale).add_Hm().format(info.observedAt!);
  final who = switch (info.source) {
    'user' => info.reporter ?? l.deletedUser,
    'open_prices' => 'Open Prices',
    _ => l.listPrice,
  };
  return [who, ?when, ?info.zone].join(' · ');
}

class _ItemPriceSheet extends StatefulWidget {
  const _ItemPriceSheet({required this.api, required this.list, required this.item, required this.onCorrect});

  final ApiClient api;
  final ShoppingList list;
  final ListItem item;
  final Future<void> Function(PriceCorrection correction) onCorrect;

  @override
  State<_ItemPriceSheet> createState() => _ItemPriceSheetState();
}

class _ItemPriceSheetState extends State<_ItemPriceSheet> {
  late Future<ItemPrices> _prices = widget.api.itemPrices(widget.list.id, widget.item.id);
  bool _busy = false;

  Future<void> _correct(PriceInfo? current) async {
    final correction = await showDialog<PriceCorrection>(
      context: context,
      builder: (_) => _CorrectPriceDialog(list: widget.list, item: widget.item, current: current),
    );
    if (correction == null || !mounted) return;
    setState(() => _busy = true);
    try {
      await widget.onCorrect(correction);
      if (!mounted) return;
      setState(() => _prices = widget.api.itemPrices(widget.list.id, widget.item.id));
      showMessage(context, context.l10n.priceCorrected);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final locale = Localizations.localeOf(context).toLanguageTag();
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.8),
        child: FutureBuilder<ItemPrices>(
          future: _prices,
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
            final prices = snapshot.data!;
            final current = prices.current;
            return ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              children: [
                Text('${widget.item.icon}  ${widget.item.name}', style: theme.textTheme.titleMedium),
                if (prices.supermarket != null)
                  Text(
                    [prices.supermarket!, ?widget.list.city].join(' · '),
                    style: theme.textTheme.bodySmall?.copyWith(color: muted),
                  ),
                const SizedBox(height: 16),
                if (current == null)
                  Text(l.noPriceYet, style: theme.textTheme.bodyMedium)
                else ...[
                  Wrap(
                    spacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.end,
                    children: [
                      Text(
                        '${formatPrice(context, current.price)}*',
                        style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      Text(perLabel(current.per, l), style: theme.textTheme.bodyMedium?.copyWith(color: muted)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(priceSourceLabel(current, l, locale), style: theme.textTheme.bodySmall),
                  const SizedBox(height: 4),
                  Text(l.pricesIndicativeNote, style: theme.textTheme.bodySmall?.copyWith(color: muted)),
                ],
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _busy || prices.supermarket == null ? null : () => _correct(current),
                  icon: const Icon(Icons.edit_outlined),
                  label: Text(current == null ? l.addPrice : l.correctPrice),
                ),
                if (prices.supermarket == null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(l.chooseKnownSupermarket, style: theme.textTheme.bodySmall?.copyWith(color: muted)),
                  ),
                if (prices.reports.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Text(l.previousReports, style: theme.textTheme.titleSmall),
                  for (final report in prices.reports)
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(report.fromUser ? Icons.person_outline : Icons.receipt_long_outlined, color: muted),
                      title: Text(
                        '${formatPrice(context, report.price)} ${perLabel(report.per, l)}'
                        '${report.productName != null && report.productName != widget.item.name ? ' · ${report.productName}' : ''}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(priceSourceLabel(report, l, locale)),
                    ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Correzione del prezzo: importo, a confezione / al kg / al litro, città e località (dalla lista).
/// Il nome e l'ora di chi corregge saranno visibili agli altri; l'email no.
class _CorrectPriceDialog extends StatefulWidget {
  const _CorrectPriceDialog({required this.list, required this.item, this.current});

  final ShoppingList list;
  final ListItem item;
  final PriceInfo? current;

  @override
  State<_CorrectPriceDialog> createState() => _CorrectPriceDialogState();
}

class _CorrectPriceDialogState extends State<_CorrectPriceDialog> {
  late final _price = TextEditingController(
    text: widget.current == null ? '' : widget.current!.price.toStringAsFixed(2).replaceAll('.', ','),
  );
  late final _city = TextEditingController(text: widget.list.city);
  late final _locality = TextEditingController(text: widget.list.locality);

  /// Con un peso o volume il prezzo più naturale resta quello della confezione; al kg/litro si sceglie a mano.
  late String _per = widget.current?.per ?? 'pz';
  String? _error;

  @override
  void dispose() {
    _price.dispose();
    _city.dispose();
    _locality.dispose();
    super.dispose();
  }

  void _confirm() {
    final price = double.tryParse(_price.text.trim().replaceAll('€', '').replaceAll(',', '.'));
    if (price == null || price < 0.01 || price > 10000) {
      setState(() => _error = context.l10n.invalidPrice);
      return;
    }
    String? text(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();
    Navigator.pop<PriceCorrection>(context, (price: price, per: _per, city: text(_city), locality: text(_locality)));
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    return AlertDialog(
      title: Text(widget.current == null ? l.addPrice : l.correctPrice),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text([?widget.list.supermarketChain?.name, widget.item.name].join(' · '), style: theme.textTheme.bodySmall),
            const SizedBox(height: 12),
            TextField(
              controller: _price,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onSubmitted: (_) => _confirm(),
              decoration: InputDecoration(labelText: l.priceLabel, suffixText: '€', errorText: _error),
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
              controller: _city,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(labelText: l.cityLabel),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _locality,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(labelText: l.localityLabel),
            ),
            const SizedBox(height: 12),
            Text(
              l.priceReportPrivacy,
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
