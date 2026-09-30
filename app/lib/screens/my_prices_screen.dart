import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../l10n/l10n.dart';
import '../models/user_price.dart';
import '../services/api_client.dart';
import '../widgets/prices.dart';
import '../widgets/ui.dart';

/// "I miei prezzi": i prezzi che l'utente si è annotato per i prodotti. Li vede solo lui; si cercano, si aggiungono,
/// si modificano (toccandoli) e si eliminano (scorrendo verso sinistra o dal menu).
class MyPricesScreen extends StatefulWidget {
  const MyPricesScreen({super.key});

  @override
  State<MyPricesScreen> createState() => _MyPricesScreenState();
}

class _MyPricesScreenState extends State<MyPricesScreen> {
  final _search = TextEditingController();
  Timer? _searchTimer;
  List<UserPrice>? _prices;
  String? _error;

  ApiClient get _api => context.read<ApiClient>();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchTimer?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final prices = await _api.myPrices(query: _search.text.trim());
      if (mounted) {
        setState(() {
          _prices = prices;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  void _onSearch(String _) {
    _searchTimer?.cancel();
    _searchTimer = Timer(const Duration(milliseconds: 350), _load);
  }

  Future<void> _add() async {
    final price = await showMyPriceDialog(context, initial: const UserPrice(id: 0, productName: '', price: 0));
    if (price == null) return;
    await _run(() => _api.addMyPrice(price));
  }

  Future<void> _edit(UserPrice existing) async {
    final price = await showMyPriceDialog(context, initial: existing, editing: true);
    if (price == null) return;
    await _run(() => _api.updateMyPrice(existing.id, price));
  }

  Future<void> _delete(UserPrice price) async {
    final l = context.l10n;
    if (!await confirm(context, title: l.deleteMyPriceQuestion(price.productName))) return;
    await _run(() => _api.deleteMyPrice(price.id));
  }

  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
      await _load();
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final prices = _prices;
    final date = DateFormat.yMMMd(Localizations.localeOf(context).toLanguageTag());
    return Scaffold(
      appBar: AppBar(title: Text(l.myPrices)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _add,
        icon: const Icon(Icons.add),
        label: Text(l.addMyPrice),
      ),
      body: Wallpaper(
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: TextField(
                  controller: _search,
                  onChanged: _onSearch,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    hintText: l.searchMyPrices,
                    isDense: true,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(l.myPricesPrivate, style: theme.textTheme.bodySmall?.copyWith(color: muted)),
              ),
              Expanded(
                child: switch ((prices, _error)) {
                  (null, null) => const Center(child: CircularProgressIndicator()),
                  (null, final String error) => Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(error, textAlign: TextAlign.center),
                        TextButton(onPressed: _load, child: Text(l.retry)),
                      ],
                    ),
                  ),
                  (final List<UserPrice> list, _) when list.isEmpty => Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        _search.text.trim().isEmpty ? l.noMyPrices : l.noMyPricesFound,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                  (final List<UserPrice> list, _) => RefreshIndicator(
                    onRefresh: _load,
                    child: ListView.builder(
                      // Spazio in fondo per il pulsante "Aggiungi".
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                      itemCount: list.length,
                      itemBuilder: (context, i) {
                        final p = list[i];
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Dismissible(
                            key: ValueKey(p.id),
                            direction: DismissDirection.endToStart,
                            confirmDismiss: (_) async {
                              await _delete(p);
                              return false;
                            },
                            background: Container(
                              decoration: BoxDecoration(
                                color: theme.colorScheme.errorContainer,
                                borderRadius: BorderRadius.circular(22),
                              ),
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 24),
                              child: Icon(Icons.delete_outline, color: theme.colorScheme.onErrorContainer),
                            ),
                            child: Card(
                              margin: EdgeInsets.zero,
                              child: ListTile(
                                onTap: () => _edit(p),
                                title: Text(p.productName),
                                subtitle: Text(
                                  [
                                    ?p.supermarket,
                                    if (p.updatedAt != null) date.format(p.updatedAt!),
                                    ?p.note,
                                  ].join(' · '),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          formatPrice(context, p.price),
                                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                                        ),
                                        Text(perLabel(p.per, l), style: theme.textTheme.bodySmall),
                                      ],
                                    ),
                                    PopupMenuButton<String>(
                                      onSelected: (v) => v == 'edit' ? _edit(p) : _delete(p),
                                      itemBuilder: (_) => [
                                        PopupMenuItem(value: 'edit', child: Text(l.edit)),
                                        PopupMenuItem(value: 'delete', child: Text(l.delete)),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
