import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../l10n/l10n.dart';
import '../models/list_item.dart';
import '../models/shopping_list.dart';
import '../models/supermarket.dart';
import '../services/api_client.dart';
import 'price_comparison.dart';
import 'ui.dart';

/// Prezzo proposto nel dialogo: importo, a cosa si riferisce (pz, kg, l) e zona.
typedef PriceCorrection = ({double price, String per, String? province, String? city, String? locality});

/// Scheda del prezzo di un articolo: il prezzo mostrato (il più confermato nella zona più vicina) e da dove viene,
/// la mia proposta in attesa, tutti i prezzi della zona da confermare o smentire e il pulsante per proporne uno.
Future<void> showItemPriceSheet(
  BuildContext context, {
  required ApiClient api,
  required ShoppingList list,
  required ListItem item,
  required Future<void> Function(PriceCorrection correction) onPropose,
  required Future<ItemPrices> Function(PriceInfo report, bool approve) onVote,
}) => showModalBottomSheet<void>(
  context: context,
  showDragHandle: true,
  isScrollControlled: true,
  builder: (_) => _ItemPriceSheet(api: api, list: list, item: item, onPropose: onPropose, onVote: onVote),
);

/// "a confezione", "al kg", "al litro".
String perLabel(String per, AppLocalizations l) => switch (per) {
  'kg' => l.perKg,
  'l' => l.perLitre,
  _ => l.perPiece,
};

/// Es. "Mario · 12 set 2026, 18:30 · Milano" oppure "Open Prices · 5 set 2026 · Milano".
String priceSourceLabel(PriceInfo info, AppLocalizations l, String locale) {
  final when = info.observedAt == null ? null : DateFormat.yMMMd(locale).add_Hm().format(info.observedAt!);
  final who = info.fromUser ? info.reporter ?? l.deletedUser : 'Open Prices';
  return [who, ?when, ?info.zone].join(' · ');
}

class _ItemPriceSheet extends StatefulWidget {
  const _ItemPriceSheet({
    required this.api,
    required this.list,
    required this.item,
    required this.onPropose,
    required this.onVote,
  });

  final ApiClient api;
  final ShoppingList list;
  final ListItem item;
  final Future<void> Function(PriceCorrection correction) onPropose;
  final Future<ItemPrices> Function(PriceInfo report, bool approve) onVote;

  @override
  State<_ItemPriceSheet> createState() => _ItemPriceSheetState();
}

class _ItemPriceSheetState extends State<_ItemPriceSheet> {
  late Future<ItemPrices> _prices = _load();
  bool _busy = false;

  Future<ItemPrices> _load() => widget.api.itemPrices(widget.list.id, widget.item.id);

  Future<void> _propose(PriceInfo? current) async {
    final correction = await showDialog<PriceCorrection>(
      context: context,
      builder: (_) => _CorrectPriceDialog(list: widget.list, item: widget.item, current: current),
    );
    if (correction == null || !mounted) return;
    await _run(() async {
      await widget.onPropose(correction);
      _prices = _load();
    }, context.l10n.priceProposed);
  }

  Future<void> _vote(PriceInfo report, bool approve) async {
    final l = context.l10n;
    await _run(() async {
      final updated = await widget.onVote(report, approve);
      _prices = Future.value(updated);
    }, approve ? l.priceConfirmed : l.priceDisputed);
  }

  Future<void> _run(Future<void> Function() action, String done) async {
    setState(() => _busy = true);
    try {
      await action();
      if (mounted) showMessage(context, done);
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
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.85),
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
            final mine = prices.mine;
            // Il prezzo mostrato si vota in alto (con il mio voto, dall'elenco); sotto gli altri.
            final shown = current == null
                ? null
                : prices.reports.where((r) => r.reportId == current.reportId).firstOrNull ?? current;
            final others = prices.reports.where((r) => r.reportId != current?.reportId).toList();
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
                if (shown == null)
                  Text(l.noPriceYet, style: theme.textTheme.bodyMedium)
                else ...[
                  Wrap(
                    spacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.end,
                    children: [
                      Text(
                        '${formatPrice(context, shown.price, shown.currency)}*',
                        style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      Text(perLabel(shown.per, l), style: theme.textTheme.bodyMedium?.copyWith(color: muted)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(priceSourceLabel(shown, l, locale), style: theme.textTheme.bodySmall),
                  Text(l.confirmations(shown.approvals), style: theme.textTheme.bodySmall?.copyWith(color: muted)),
                  const SizedBox(height: 8),
                  _VoteButtons(report: shown, busy: _busy, onVote: _vote),
                ],
                if (mine != null) ...[
                  const SizedBox(height: 12),
                  Card(
                    color: theme.colorScheme.secondaryContainer,
                    margin: EdgeInsets.zero,
                    child: ListTile(
                      leading: const Icon(Icons.hourglass_top),
                      title: Text(
                        l.yourProposal('${formatPrice(context, mine.price, mine.currency)} ${perLabel(mine.per, l)}'),
                      ),
                      subtitle: Text(l.waitingConfirmation),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _busy || prices.supermarket == null ? null : () => _propose(current),
                  icon: const Icon(Icons.edit_outlined),
                  label: Text(current == null ? l.addPrice : l.proposeOtherPrice),
                ),
                if (prices.supermarket == null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(l.chooseKnownSupermarket, style: theme.textTheme.bodySmall?.copyWith(color: muted)),
                  ),
                if (others.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Text(l.otherPrices, style: theme.textTheme.titleSmall),
                  for (final report in others)
                    _ReportTile(item: widget.item, report: report, busy: _busy, onVote: _vote),
                ],
                const SizedBox(height: 12),
                Text(l.pricesIndicativeNote, style: theme.textTheme.bodySmall?.copyWith(color: muted)),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Un prezzo della zona: importo, chi e quando, conferme, stato e i pulsanti per votarlo.
class _ReportTile extends StatelessWidget {
  const _ReportTile({required this.item, required this.report, required this.busy, required this.onVote});

  final ListItem item;
  final PriceInfo report;
  final bool busy;
  final void Function(PriceInfo report, bool approve) onVote;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final status = switch (report.status) {
      'pending' => l.toBeConfirmed,
      'rejected' => l.disputed,
      _ => null,
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            [
              '${formatPrice(context, report.price, report.currency)} ${perLabel(report.per, l)}',
              if (report.productName != null && report.productName != item.name) report.productName!,
            ].join(' · '),
            style: theme.textTheme.bodyLarge?.copyWith(decoration: report.rejected ? TextDecoration.lineThrough : null),
          ),
          Text(
            [
              priceSourceLabel(report, l, locale),
              l.confirmations(report.approvals),
              ?status,
              if (report.mine) l.proposedByYou,
            ].join(' · '),
            style: theme.textTheme.bodySmall?.copyWith(color: muted),
          ),
          if (!report.mine) _VoteButtons(report: report, busy: busy, onVote: onVote),
        ],
      ),
    );
  }
}

/// "Confermo" e "Non è giusto": il mio voto è evidenziato e si può cambiare.
class _VoteButtons extends StatelessWidget {
  const _VoteButtons({required this.report, required this.busy, required this.onVote});

  final PriceInfo report;
  final bool busy;
  final void Function(PriceInfo report, bool approve) onVote;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    if (report.reportId == null || report.mine) return const SizedBox.shrink();
    return Wrap(
      spacing: 8,
      children: [
        FilterChip(
          avatar: const Icon(Icons.thumb_up_alt_outlined, size: 18),
          label: Text(l.confirmPrice),
          selected: report.myVote == true,
          showCheckmark: false,
          onSelected: busy || report.myVote == true ? null : (_) => onVote(report, true),
        ),
        FilterChip(
          avatar: const Icon(Icons.thumb_down_alt_outlined, size: 18),
          label: Text(l.notRightPrice),
          selected: report.myVote == false,
          showCheckmark: false,
          onSelected: busy || report.myVote == false ? null : (_) => onVote(report, false),
        ),
      ],
    );
  }
}

/// Proposta di un prezzo: importo, a confezione / al kg / al litro, zona (dalla lista). Gli altri la vedono dopo
/// la conferma di altri utenti; il nome e l'ora di chi propone saranno visibili, l'email no.
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
  late final _province = TextEditingController(text: widget.list.province);
  late final _city = TextEditingController(text: widget.list.city);
  late final _locality = TextEditingController(text: widget.list.locality);

  /// Con un peso o volume il prezzo più naturale resta quello della confezione; al kg/litro si sceglie a mano.
  late String _per = widget.current?.per ?? 'pz';
  String? _error;

  @override
  void dispose() {
    _price.dispose();
    _province.dispose();
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
    Navigator.pop<PriceCorrection>(context, (
      price: price,
      per: _per,
      province: text(_province),
      city: text(_city),
      locality: text(_locality),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    return AlertDialog(
      title: Text(widget.current == null ? l.addPrice : l.proposeOtherPrice),
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
              controller: _province,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(labelText: l.provinceLabel),
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
