import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/l10n.dart';
import '../models/branded_product.dart';
import '../models/list_item.dart';
import '../models/product_suggestion.dart';
import '../services/api_client.dart';
import '../services/list_export.dart';
import '../services/notification_service.dart';
import '../services/realtime_client.dart';
import '../services/spoken_item.dart';
import '../state/auth_controller.dart';
import '../state/chat_controller.dart';
import '../state/list_detail_controller.dart';
import '../state/lists_controller.dart';
import '../widgets/chat_panel.dart';
import '../widgets/item_price_sheet.dart';
import '../widgets/photo_picker.dart';
import '../widgets/price_comparison.dart';
import '../theme/app_theme.dart';
import '../widgets/ui.dart';
import '../widgets/voice_input.dart';
import 'list_form_screen.dart';
import 'list_share_screen.dart';

class ListDetailScreen extends StatefulWidget {
  const ListDetailScreen({super.key, this.openChat = false});

  /// Apre subito la chat (notifica di un messaggio toccata).
  final bool openChat;

  @override
  State<ListDetailScreen> createState() => _ListDetailScreenState();
}

class _ListDetailScreenState extends State<ListDetailScreen> {
  bool _closing = false;

  /// Chat aperta sotto la lista, nella stessa schermata.
  late bool _chatOpen = widget.openChat;

  late final NotificationService _notifications;
  late final int _listId;

  @override
  void initState() {
    super.initState();
    // Mentre la lista è aperta le sue modifiche non generano notifiche e la sua conversazione sparisce.
    _listId = context.read<ListDetailController>().listId;
    _notifications = context.read<NotificationService>()..activeListId = _listId;
  }

  @override
  void dispose() {
    if (_notifications.activeListId == _listId) _notifications.activeListId = null;
    super.dispose();
  }

  /// La lista è stata eliminata o la condivisione revocata mentre era aperta.
  void _closeBecauseGone() {
    if (_closing) return;
    _closing = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showMessage(context, context.l10n.listUnavailable);
      Navigator.pop(context);
    });
  }

  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _edit(ListDetailController detail) async {
    final lists = context.read<ListsController>();
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider.value(
          value: lists,
          child: ListFormScreen(list: detail.list),
        ),
      ),
    );
    await detail.load(silent: true);
  }

  Future<void> _onMenu(String value, ListDetailController detail) async {
    final lists = context.read<ListsController>();
    final l = context.l10n;
    switch (value) {
      case 'photo':
        await _photoMenu(detail);
      case 'clear':
        await _run(detail.clearChecked);
      case 'delete':
        if (await confirm(context, title: l.deleteListQuestion, message: l.deleteListInfo)) {
          await _leaveScreenAfter(() => lists.delete(detail.listId));
        }
      case 'leave':
        if (await confirm(context, title: l.leaveListQuestion, message: l.leaveListInfo, action: l.leave)) {
          await _leaveScreenAfter(() async {
            await detail.leave();
            await lists.load();
          });
        }
    }
  }

  /// Esegue l'azione e chiude la schermata; _closing evita la doppia chiusura
  /// quando nel frattempo arriva l'evento in tempo reale "list.deleted".
  Future<void> _leaveScreenAfter(Future<void> Function() action) async {
    final navigator = Navigator.of(context);
    _closing = true;
    try {
      await action();
      navigator.pop();
    } catch (e) {
      _closing = false;
      if (mounted) showError(context, e);
    }
  }

  // ── Foto della lista ────────────────────────────────────────────

  Future<void> _photoMenu(ListDetailController detail) async {
    final choice = await askPhotoSource(context, canRemove: detail.list?.imageVersion != null);
    if (choice == null || !mounted) return;
    if (choice == PhotoChoice.remove) {
      await _run(detail.removeImage);
      return;
    }
    await _run(() async {
      final path = await pickPhoto(choice);
      if (path == null) return;
      await detail.setImage(path);
      if (mounted) showMessage(context, context.l10n.listPhotoUpdated);
    });
  }

  /// Foto del prodotto: dalla galleria, dalla fotocamera o rimossa.
  Future<void> _itemPhotoMenu(ListDetailController detail, ListItem item) async {
    final choice = await askPhotoSource(
      context,
      canRemove: item.imageVersion != null,
      title: context.l10n.photoOf(item.name),
    );
    if (choice == null || !mounted) return;
    await _run(() async {
      if (choice == PhotoChoice.remove) {
        await detail.removeItemImage(item);
        return;
      }
      final path = await pickPhoto(choice);
      if (path != null) await detail.setItemImage(item, path);
    });
  }

  /// Eliminare un articolo è diverso da segnarlo come preso: sparisce dalla lista per tutti.
  Future<void> _deleteItem(ListDetailController detail, ListItem item) async {
    if (!await _confirmDelete(item)) return;
    await _run(() => detail.deleteItem(item));
  }

  Future<bool> _confirmDelete(ListItem item) =>
      confirm(context, title: context.l10n.deleteItemQuestion(item.name), message: context.l10n.deleteItemInfo);

  /// Tenendo premuto un articolo: tutte le azioni, con "Elimina" ben separato da "Preso".
  /// Scheda del prezzo: da dove viene, segnalazioni precedenti e rettifica.
  Future<void> _openPrice(ListDetailController detail, ListItem item) => showItemPriceSheet(
    context,
    api: context.read<ApiClient>(),
    list: detail.list!,
    item: item,
    onPropose: (c) =>
        detail.reportPrice(item, price: c.price, per: c.per, province: c.province, city: c.city, locality: c.locality),
    onVote: (report, approve) => detail.votePrice(item, report, approve: approve),
  );

  Future<void> _itemActions(ListDetailController detail, ListItem item) async {
    final error = Theme.of(context).colorScheme.error;
    final l = context.l10n;
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text('${item.icon}  ${item.name}', style: Theme.of(context).textTheme.titleMedium),
            ),
            ListTile(
              leading: Icon(item.checked ? Icons.check_box : Icons.check_box_outline_blank),
              title: Text(item.checked ? l.putBackToBuy : l.takenInCart),
              onTap: () => Navigator.pop(context, 'taken'),
            ),
            ListTile(
              leading: Icon(item.missing ? Icons.cancel : Icons.cancel_outlined),
              title: Text(item.missing ? l.putBackToBuy : l.notFound),
              onTap: () => Navigator.pop(context, 'missing'),
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: Text(l.edit),
              onTap: () => Navigator.pop(context, 'edit'),
            ),
            ListTile(
              leading: const Icon(Icons.add_a_photo_outlined),
              title: Text(item.imageVersion == null ? l.addPhoto : l.changePhoto),
              onTap: () => Navigator.pop(context, 'photo'),
            ),
            if (detail.list?.supermarketChain != null)
              ListTile(
                leading: const Icon(Icons.euro),
                title: Text(l.priceMenu),
                onTap: () => Navigator.pop(context, 'price'),
              ),
            const Divider(),
            ListTile(
              leading: Icon(Icons.delete_outline, color: error),
              title: Text(l.deleteFromList, style: TextStyle(color: error)),
              subtitle: Text(l.deleteFromListInfo),
              onTap: () => Navigator.pop(context, 'delete'),
            ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    switch (action) {
      case 'taken':
        await _run(() => detail.setStatus(item, ItemStatus.taken));
      case 'missing':
        await _run(() => detail.setStatus(item, ItemStatus.missing));
      case 'edit':
        await _editItem(detail, item);
      case 'photo':
        await _itemPhotoMenu(detail, item);
      case 'price':
        await _openPrice(detail, item);
      case 'delete':
        await _deleteItem(detail, item);
    }
  }

  // ── Esportazione ────────────────────────────────────────────────

  Future<void> _exportMenu(ListDetailController detail) async {
    final list = detail.list;
    if (list == null) return;
    final export = ListExport(list: list, items: detail.items, categories: _categories);
    final l = context.l10n;
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 8), child: Text(l.sendOrExportList)),
            ListTile(
              leading: const Text('💬', style: TextStyle(fontSize: 24)),
              title: const Text('WhatsApp'),
              subtitle: Text(l.exportTextInfo),
              onTap: () => Navigator.pop(context, 'whatsapp'),
            ),
            ListTile(
              leading: const Text('✈️', style: TextStyle(fontSize: 24)),
              title: const Text('Telegram'),
              subtitle: Text(l.exportTextInfo),
              onTap: () => Navigator.pop(context, 'telegram'),
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf_outlined),
              title: const Text('PDF'),
              subtitle: Text(l.exportPdfInfo),
              onTap: () => Navigator.pop(context, 'pdf'),
            ),
            ListTile(
              leading: const Icon(Icons.share_outlined),
              title: Text(l.otherApps),
              onTap: () => Navigator.pop(context, 'other'),
            ),
          ],
        ),
      ),
    );
    if (choice == null || !mounted) return;
    final api = context.read<ApiClient>();
    await _run(() async {
      switch (choice) {
        case 'whatsapp':
          if (!await export.toWhatsApp()) throw l.appNotInstalled('WhatsApp');
        case 'telegram':
          if (!await export.toTelegram()) throw l.appNotInstalled('Telegram');
        case 'pdf':
          final bytes = list.imageVersion == null ? null : await api.listImageBytes(list.id, list.imageVersion!);
          await export.sharePdf(image: bytes == null ? null : Uint8List.fromList(bytes));
        case 'other':
          await export.toOtherApps();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final detail = context.watch<ListDetailController>();
    final list = detail.list;
    if (detail.gone) _closeBecauseGone();
    final chat = _chatOpen && list != null;
    final l = context.l10n;

    final round = roundButtonStyle(context);

    return Scaffold(
      appBar: AppBar(
        // Il nome della lista è il titolo grande nella pagina; qui solo i pulsanti tondi.
        leading: Center(
          child: IconButton(
            style: round,
            tooltip: MaterialLocalizations.of(context).backButtonTooltip,
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.maybePop(context),
          ),
        ),
        actions: [
          if (list != null)
            IconButton(
              style: round,
              tooltip: chat ? l.closeChat : l.chat,
              isSelected: chat,
              icon: const Icon(Icons.chat_bubble_outline),
              selectedIcon: const Icon(Icons.chat_bubble),
              onPressed: () => setState(() => _chatOpen = !_chatOpen),
            ),
          if (list != null)
            IconButton(
              style: round,
              tooltip: l.sendOrExport,
              icon: const Icon(Icons.ios_share),
              onPressed: () => _exportMenu(detail),
            ),
          if (list != null && list.isOwner)
            IconButton(
              style: round,
              tooltip: l.share,
              icon: const Icon(Icons.person_add_alt_outlined),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ListShareScreen(listId: list.id, listName: list.name),
                ),
              ).then((_) => detail.load(silent: true)),
            ),
          if (list != null)
            PopupMenuButton<String>(
              style: round,
              onSelected: (v) => v == 'edit' ? _edit(detail) : _onMenu(v, detail),
              itemBuilder: (_) => [
                if (detail.canEdit) PopupMenuItem(value: 'edit', child: Text(l.editList)),
                if (detail.canEdit)
                  PopupMenuItem(value: 'photo', child: Text(list.imageVersion == null ? l.addPhoto : l.changePhoto)),
                if (detail.canEdit)
                  PopupMenuItem(value: 'clear', enabled: detail.checkedCount > 0, child: Text(l.clearTaken)),
                if (list.isOwner) PopupMenuItem(value: 'delete', child: Text(l.deleteList)),
                if (detail.canLeave) PopupMenuItem(value: 'leave', child: Text(l.leaveList)),
              ],
            ),
          const SizedBox(width: 8),
        ],
      ),
      // Con la chat aperta: lista in alto (si spunta e si aggiunge), chat in basso.
      body: Wallpaper(
        child: chat
            ? Column(
                children: [
                  Expanded(flex: 5, child: _body(detail)),
                  if (detail.canEdit) _addBar(detail, compact: true),
                  Expanded(
                    flex: 4,
                    child: _ChatSheet(
                      onClose: () => setState(() => _chatOpen = false),
                      child: ChangeNotifierProvider(
                        create: (context) => ChatController(
                          api: context.read<ApiClient>(),
                          realtime: context.read<RealtimeClient>(),
                          listId: detail.listId,
                          userId: detail.userId,
                        )..start(),
                        child: ChatPanel(isOwner: list.isOwner),
                      ),
                    ),
                  ),
                ],
              )
            : _body(detail),
      ),
      bottomNavigationBar: detail.canEdit && !chat ? _addBar(detail) : null,
    );
  }

  Widget _addBar(ListDetailController detail, {bool compact = false}) => _AddItemBar(
    units: _units,
    compact: compact,
    suggestions: detail.suggestions,
    existing: [for (final item in detail.items) item.name],
    search: detail.searchProducts,
    onAdd: (name, qty, amount, unit, imagePath, product) =>
        detail.addItem(name, quantity: qty, amount: amount, unit: unit, imagePath: imagePath, product: product),
  );

  Widget _body(ListDetailController detail) {
    final list = detail.list;
    final l = context.l10n;
    if (detail.loading && list == null) return const Center(child: CircularProgressIndicator());
    if (list == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(detail.error ?? l.cannotLoadList),
            TextButton(onPressed: detail.load, child: Text(l.retry)),
          ],
        ),
      );
    }

    final items = detail.items;
    final api = context.read<ApiClient>();
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return RefreshIndicator(
      onRefresh: () => detail.load(silent: true),
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: PageHeading(
              list.name,
              compact: _chatOpen,
              subtitle: _ListMeta(detail: detail),
            ),
          ),
          if (items.isNotEmpty && !_chatOpen)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: ShoppingProgress(done: detail.checkedCount, total: items.length),
            ),
          if (list.imageVersion != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: GestureDetector(
                onTap: detail.canEdit ? () => _photoMenu(detail) : null,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: Image.network(
                    api.listImageUrl(list.id, list.imageVersion!),
                    headers: api.authHeaders,
                    height: _chatOpen ? 90 : 180,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const SizedBox.shrink(),
                  ),
                ),
              ),
            ),
          if (list.notes != null && list.notes!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Card(
                child: ListTile(leading: const Icon(Icons.notes), title: Text(list.notes!)),
              ),
            ),
          if (list.reminderMinutes != null && !_chatOpen)
            ListTile(
              dense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 20),
              leading: Icon(Icons.notifications_active_outlined, color: muted),
              title: Text(l.reminderBefore(durationLabel(list.reminderMinutes!, l))),
              subtitle: Text(list.reminderTarget.label(l)),
            ),
          if (!detail.canEdit)
            ListTile(
              dense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 20),
              leading: Icon(Icons.visibility_outlined, color: muted),
              title: Text(l.readOnlyAccess),
            ),
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Text(l.emptyList, textAlign: TextAlign.center),
            ),
          for (final group in groupByCategory(items, _categories.map((c) => c.slug).toList())) ...[
            _CategoryHeader(
              category: _categories.firstWhere(
                (c) => c.slug == group.category,
                orElse: () => ProductCategory(slug: 'altro', label: l.other, icon: '🛒'),
              ),
            ),
            for (final item in group.items) _itemTile(detail, item),
          ],
          if (items.isNotEmpty) _PriceSummary(detail: detail),
          if (items.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                [
                  l.inCart(detail.checkedCount, items.length),
                  if (detail.missingCount > 0) l.notFoundCount(detail.missingCount),
                ].join(' · '),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: muted),
              ),
            ),
        ],
      ),
    );
  }

  /// Reparti nell'ordine del giro al supermercato (dal server; se non disponibili, quelli predefiniti).
  List<ProductCategory> get _categories {
    final fromServer = context.read<AuthController>().serverConfig?.productCategories ?? const [];
    return fromServer.isNotEmpty
        ? fromServer
        : [for (final slug in defaultCategoryOrder) ProductCategory(slug: slug, label: slug, icon: '')];
  }

  List<String> get _units => context.read<AuthController>().serverConfig?.units ?? defaultUnits;

  Widget _itemTile(ListDetailController detail, ListItem item) {
    final theme = Theme.of(context);
    final error = theme.colorScheme.error;
    final l = context.l10n;
    final details = [
      ?item.measureLabel,
      if (item.checked && item.checkedBy != null) l.takenBy(item.checkedBy!),
      if (item.missing) item.checkedBy == null ? l.notFoundLower : l.notFoundBy(item.checkedBy!),
    ].join(' · ');
    final taken = detail.canEdit ? () => _run(() => detail.setStatus(item, ItemStatus.taken)) : null;

    final scheme = theme.colorScheme;
    final tile = Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: taken,
        onLongPress: detail.canEdit ? () => _itemActions(detail, item) : null,
        child: Padding(
          padding: EdgeInsets.fromLTRB(8, 6, detail.canEdit ? 0 : 12, 6),
          child: Row(
            children: [
              // Cerchio: vuoto = da prendere, verde con ✓ = preso, rosso con ✗ = non trovato.
              IconButton(
                tooltip: item.checked ? l.putBackToBuy : l.takenInCart,
                onPressed: taken,
                icon: _StatusCircle(status: item.status),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          decoration: item.checked ? TextDecoration.lineThrough : null,
                          color: switch (item.status) {
                            ItemStatus.todo => null,
                            ItemStatus.taken => scheme.onSurfaceVariant,
                            ItemStatus.missing => error,
                          },
                        ),
                      ),
                      if (details.isNotEmpty)
                        Text(
                          details,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: item.missing ? error : scheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              // Prezzo nella catena scelta (quantità e peso compresi): il più confermato della zona, oppure la mia
              // proposta in attesa (con la clessidra). Toccandolo si conferma o se ne propone un altro; il pallino
              // dice che ci sono prezzi di altri da confermare. Senza prezzo, un "€" per aggiungerlo.
              if (detail.list?.supermarketChain != null)
                Badge(
                  isLabelVisible: item.pendingPrices > 0,
                  smallSize: 8,
                  child: item.shownPrice != null
                      ? InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () => _openPrice(detail, item),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (item.myPrice != null)
                                  Padding(
                                    padding: const EdgeInsets.only(right: 2),
                                    child: Icon(Icons.hourglass_top, size: 14, color: scheme.onSurfaceVariant),
                                  ),
                                Text(
                                  formatPrice(context, item.shownPrice!, item.currency),
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: item.status == ItemStatus.todo ? null : scheme.onSurfaceVariant,
                                    decoration: item.missing ? TextDecoration.lineThrough : null,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : IconButton(
                          visualDensity: VisualDensity.compact,
                          tooltip: l.addPrice,
                          icon: Icon(Icons.euro, size: 18, color: scheme.onSurfaceVariant),
                          onPressed: () => _openPrice(detail, item),
                        ),
                ),
              Opacity(
                opacity: item.status == ItemStatus.todo ? 1 : 0.5,
                child: _ItemImage(item: item, listId: detail.listId),
              ),
              if (detail.canEdit)
                IconButton(
                  icon: Icon(Icons.more_vert, size: 20, color: scheme.onSurfaceVariant),
                  tooltip: l.itemMenu,
                  onPressed: () => _itemActions(detail, item),
                ),
            ],
          ),
        ),
      ),
    );

    const margin = EdgeInsets.symmetric(horizontal: 16, vertical: 4);
    if (!detail.canEdit) return Padding(padding: margin, child: tile);
    return Padding(
      padding: margin,
      child: Dismissible(
        key: ValueKey(item.id),
        direction: DismissDirection.endToStart,
        background: Container(
          decoration: BoxDecoration(color: scheme.errorContainer, borderRadius: BorderRadius.circular(22)),
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 24),
          child: Icon(Icons.delete_outline, color: scheme.onErrorContainer),
        ),
        confirmDismiss: (_) => _confirmDelete(item),
        onDismissed: (_) => _run(() => detail.deleteItem(item)),
        child: tile,
      ),
    );
  }

  Future<void> _editItem(ListDetailController detail, ListItem item) async {
    final categories = context.read<AuthController>().serverConfig?.productCategories ?? const [];
    final result = await showDialog<_ItemEdit>(
      context: context,
      builder: (_) => _EditItemDialog(item: item, listId: detail.listId, units: _units, categories: categories),
    );
    if (result == null || !mounted) return;
    if (result.delete) {
      await _deleteItem(detail, item);
      return;
    }
    await _run(() async {
      await detail.editItem(
        item,
        name: result.name,
        quantity: result.quantity,
        amount: result.amount,
        unit: result.unit,
        category: result.category,
        customIcon: result.customIcon,
        imageUrl: result.imageUrl,
      );
      if (result.photoPath != null) {
        await detail.setItemImage(item, result.photoPath!);
      } else if (result.removePhoto) {
        await detail.removeItemImage(item);
      }
    });
  }
}

/// Chat aperta sotto la lista: un foglio con gli angoli arrotondati e l'ombra verso l'alto, appoggiato sulla lista.
class _ChatSheet extends StatelessWidget {
  const _ChatSheet({required this.onClose, required this.child});

  final VoidCallback onClose;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    const radius = BorderRadius.vertical(top: Radius.circular(24));
    return Container(
      margin: const EdgeInsets.only(top: 6),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: dark ? 0.6 : 0.24),
            blurRadius: 24,
            offset: const Offset(0, -6),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: dark ? 0.3 : 0.06),
            blurRadius: 3,
            offset: const Offset(0, -1),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Column(
          children: [
            _ChatHeader(onClose: onClose),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}

/// Barra minima in cima alla chat: maniglia, icona e freccia per chiuderla (tocca ovunque).
class _ChatHeader extends StatelessWidget {
  const _ChatHeader({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onClose,
        child: Tooltip(
          message: context.l10n.closeChat,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 2),
            child: Column(
              children: [
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: scheme.onSurfaceVariant.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Row(
                  children: [
                    Icon(Icons.chat_bubble_outline, size: 18, color: scheme.primary),
                    const Spacer(),
                    Icon(Icons.keyboard_arrow_down, size: 22, color: scheme.onSurfaceVariant),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Icona dell'articolo: la foto caricata o l'immagine esterna se c'è (tocca per ingrandirla), altrimenti l'emoji.
class _ItemImage extends StatelessWidget {
  const _ItemImage({required this.item, required this.listId});

  final ListItem item;
  final int listId;

  @override
  Widget build(BuildContext context) {
    final color = categoryColor(item.category, Theme.of(context).brightness);
    final emoji = Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(14)),
      child: Text(item.icon, style: const TextStyle(fontSize: 22)),
    );
    final image = itemImageProvider(context.read<ApiClient>(), item, listId);
    if (image == null) return emoji;
    return GestureDetector(
      onTap: () => showPhoto(context, image, caption: '${item.icon}  ${item.name}'),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Image(image: image, width: 44, height: 44, fit: BoxFit.cover, errorBuilder: (_, _, _) => emoji),
      ),
    );
  }
}

/// Foto caricata dal telefono (ha la precedenza) o link esterno; null se l'articolo non ha immagini.
ImageProvider? itemImageProvider(ApiClient api, ListItem item, int listId) {
  if (item.imageVersion != null) {
    return NetworkImage(api.itemImageUrl(listId, item.id, item.imageVersion!), headers: api.authHeaders);
  }
  return item.imageUrl == null ? null : NetworkImage(item.imageUrl!);
}

/// In fondo alla lista: totale stimato nella catena scelta (se è una catena nota e ci sono prezzi), con l'asterisco
/// dei prezzi indicativi, e il pulsante per confrontare il costo della lista nelle altre catene.
class _PriceSummary extends StatelessWidget {
  const _PriceSummary({required this.detail});

  final ListDetailController detail;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final chain = detail.list!.supermarketChain;
    final total = detail.estimatedTotal;
    final activeCount = detail.items.where((i) => !i.missing).length;
    final compare = TextButton.icon(
      onPressed: () => showPriceComparison(context, detail.listId),
      icon: const Icon(Icons.compare_arrows),
      label: Text(l.compareChains),
    );
    if (chain == null) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Center(child: compare),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (total == null)
                Text(l.noPricesForChain(chain.name), style: theme.textTheme.bodyMedium?.copyWith(color: muted))
              else ...[
                Row(
                  children: [
                    const Icon(Icons.storefront_outlined),
                    const SizedBox(width: 8),
                    Expanded(child: Text(l.estimatedTotal(chain.name), style: theme.textTheme.titleMedium)),
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Text(
                        formatPrice(context, total, detail.currency),
                        style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
                if (detail.pricedCount < activeCount)
                  Text(l.pricedOf(detail.pricedCount, activeCount), style: theme.textTheme.bodySmall),
                const SizedBox(height: 6),
                Text(l.pricesIndicativeNote, style: theme.textTheme.bodySmall?.copyWith(color: muted)),
              ],
              Align(alignment: Alignment.centerRight, child: compare),
            ],
          ),
        ),
      ),
    );
  }
}

/// Riga sotto il nome della lista: giorno e ora, chi la sta guardando (canale presence) e, finché scrive
/// nella chat, chi sta scrivendo.
class _ListMeta extends StatelessWidget {
  const _ListMeta({required this.detail});

  final ListDetailController detail;

  @override
  Widget build(BuildContext context) {
    final list = detail.list!;
    final l = context.l10n;
    final primary = Theme.of(context).colorScheme.primary;
    final others = detail.viewers.where((v) => v.id != detail.userId).map((v) => v.name).toList();
    final typing = detail.typingNames;
    return Text.rich(
      TextSpan(
        text: '${dayLabel(list.scheduledAt)} · ${timeLabel(list.scheduledAt)}',
        children: [
          if (list.supermarket != null) TextSpan(text: ' · ${list.supermarket}'),
          if (others.isNotEmpty) TextSpan(text: ' · ${l.viewingNowShort(others.join(', '))}'),
          // Temporaneo, finché la persona scrive nella chat.
          if (typing.isNotEmpty)
            TextSpan(
              text: ' · ${l.typing(typing.length, typing.join(', '))}',
              style: TextStyle(color: primary, fontWeight: FontWeight.w600),
            ),
        ],
      ),
    );
  }
}

/// Stato dell'articolo: cerchio vuoto, verde con ✓ (preso) o rosso con ✗ (non trovato).
class _StatusCircle extends StatelessWidget {
  const _StatusCircle({required this.status});

  final ItemStatus status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (fill, border, icon) = switch (status) {
      ItemStatus.todo => (Colors.transparent, scheme.outline, null),
      ItemStatus.taken => (scheme.primary, scheme.primary, Icon(Icons.check, size: 18, color: scheme.onPrimary)),
      ItemStatus.missing => (Colors.transparent, scheme.error, Icon(Icons.close, size: 16, color: scheme.error)),
    };
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: fill,
        shape: BoxShape.circle,
        border: Border.all(color: border, width: 2),
      ),
      child: icon,
    );
  }
}

/// Intestazione del reparto: pallino colorato e nome in maiuscolo.
class _CategoryHeader extends StatelessWidget {
  const _CategoryHeader({required this.category});

  final ProductCategory category;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 18, 20, 6),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: categoryColor(category.slug, theme.brightness), shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              category.label.toUpperCase(),
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Unità di peso e volume se il server non le indica.
const defaultUnits = ['g', 'hg', 'kg', 'ml', 'cl', 'l'];

/// "1,5" → 1.5; testo vuoto → null; testo non valido → NaN.
double? _parseAmount(String text) {
  final t = text.trim().replaceAll(',', '.');
  if (t.isEmpty) return null;
  final value = double.tryParse(t);
  return value == null || value <= 0 ? double.nan : value;
}

/// Menu dell'unità di misura (g, kg, l…).
class _UnitPicker extends StatelessWidget {
  const _UnitPicker({required this.units, required this.value, required this.onChanged});

  final List<String> units;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: value,
        isDense: true,
        items: [for (final u in units) DropdownMenuItem(value: u, child: Text(u))],
        onChanged: (v) => onChanged(v ?? value),
      ),
    );
  }
}

class _AddItemBar extends StatefulWidget {
  const _AddItemBar({
    required this.onAdd,
    required this.units,
    required this.search,
    this.compact = false,
    this.suggestions = const [],
    this.existing = const [],
  });

  /// Proposti sotto il campo mentre si scrive; [existing] (già in lista) non vengono proposti.
  final List<ProductSuggestion> suggestions;
  final List<String> existing;

  final Future<void> Function(
    String name,
    String? quantity,
    double? amount,
    String? unit,
    String? imagePath,
    BrandedProduct? product,
  )
  onAdd;
  final List<String> units;

  /// Prodotti di marca per quanto scritto (Open Food Facts).
  final Future<List<BrandedProduct>> Function(String text) search;

  /// Solo il nome (con la chat aperta sotto): quantità e peso si aggiungono con la matita.
  final bool compact;

  @override
  State<_AddItemBar> createState() => _AddItemBarState();
}

class _AddItemBarState extends State<_AddItemBar> {
  final _name = TextEditingController();
  final _focus = FocusNode();

  /// Quantità e peso/volume del prodotto da aggiungere: si scelgono con il pulsante accanto al nome.
  _Measure _measure = const _Measure();
  bool _busy = false;

  /// Foto scelta per il prodotto che si sta aggiungendo.
  String? _photoPath;

  /// Prodotti di marca per il testo scritto, cercati dopo una breve pausa; [_chosen] è quello toccato.
  List<BrandedProduct> _branded = const [];
  BrandedProduct? _chosen;
  String _searched = '';
  Timer? _searchTimer;

  @override
  void initState() {
    super.initState();
    // I suggerimenti seguono il testo scritto e compaiono solo mentre si sta scrivendo.
    _name.addListener(_refresh);
    _name.addListener(_onTextChanged);
    _focus.addListener(_refresh);
  }

  /// Cambiando il testo il prodotto di marca scelto non vale più; con almeno 3 lettere si cercano quelli nuovi.
  void _onTextChanged() {
    final text = _name.text.trim();
    if (_chosen != null && text != _chosen!.name) _chosen = null;
    if (text == _searched) return;
    _searchTimer?.cancel();
    if (text.length < 3 || _chosen != null) {
      _searched = text;
      if (_branded.isNotEmpty) setState(() => _branded = const []);
      return;
    }
    _searchTimer = Timer(const Duration(milliseconds: 450), () async {
      _searched = text;
      try {
        final found = await widget.search(text);
        // Nel frattempo l'utente ha scritto altro: questi risultati non servono più.
        if (mounted && _name.text.trim() == text && _chosen == null) setState(() => _branded = found);
      } catch (_) {
        // Senza prodotti di marca si aggiunge comunque quello scritto.
      }
    });
  }

  /// Prodotto di marca toccato: nome, peso o volume della confezione; marca, codice e foto arrivano al server.
  void _useBranded(BrandedProduct product) {
    setState(() {
      _chosen = product;
      _branded = const [];
      _searched = product.name;
      if (product.amount != null && widget.units.contains(product.unit)) {
        _measure = _Measure(quantity: _measure.quantity, amount: product.amount, unit: product.unit!);
      }
    });
    _name.value = TextEditingValue(
      text: product.name,
      selection: TextSelection.collapsed(offset: product.name.length),
    );
    _focus.requestFocus();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  void _useSuggestion(ProductSuggestion suggestion) {
    _name.value = TextEditingValue(
      text: suggestion.name,
      selection: TextSelection.collapsed(offset: suggestion.name.length),
    );
    _focus.requestFocus();
  }

  @override
  void dispose() {
    _searchTimer?.cancel();
    _name.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _editMeasure() async {
    final result = await showModalBottomSheet<_Measure>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => _MeasureSheet(initial: _measure, units: widget.units),
    );
    if (result != null && mounted) setState(() => _measure = result);
    _focus.requestFocus();
  }

  Future<void> _pickPhoto() async {
    final choice = await askPhotoSource(context, canRemove: _photoPath != null, title: context.l10n.productPhoto);
    if (choice == null) return;
    if (choice == PhotoChoice.remove) {
      setState(() => _photoPath = null);
      return;
    }
    try {
      final path = await pickPhoto(choice);
      if (path != null && mounted) setState(() => _photoPath = path);
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  /// Dettato a voce: "2 kg di mele" → Mele, 2 kg; "3 yogurt" → Yogurt, quantità 3.
  void _onDictated(String text) {
    final spoken = SpokenItem.parse(text, units: widget.units);
    setState(() {
      _name.text = spoken.name;
      _measure = _Measure(
        quantity: spoken.quantity ?? _measure.quantity,
        amount: spoken.amount ?? _measure.amount,
        unit: spoken.unit ?? _measure.unit,
      );
    });
  }

  Future<void> _submit() async {
    final name = _name.text.trim();
    if (name.isEmpty || _busy) return;
    setState(() => _busy = true);
    try {
      final m = _measure;
      await widget.onAdd(name, m.quantity, m.amount, m.amount == null ? null : m.unit, _photoPath, _chosen);
      _name.clear();
      setState(() {
        _photoPath = null;
        _chosen = null;
        _branded = const [];
        _measure = const _Measure();
      });
      _focus.requestFocus();
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Chip con i prodotti suggeriti, sotto il nome: tocca per scriverlo.
  Widget _suggestionsRow() {
    final matches = suggestProducts(widget.suggestions, _name.text, exclude: widget.existing);
    if (matches.isEmpty) return const SizedBox.shrink();
    final empty = _name.text.trim().isEmpty;
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: SizedBox(
        height: 36,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: matches.length + (empty ? 1 : 0),
          separatorBuilder: (_, _) => const SizedBox(width: 6),
          itemBuilder: (context, i) {
            if (empty && i == 0) {
              return Center(child: Text(context.l10n.oftenBought, style: Theme.of(context).textTheme.labelMedium));
            }
            final s = matches[empty ? i - 1 : i];
            return ActionChip(
              avatar: Text(s.icon),
              label: Text(s.name),
              tooltip: s.times > 0 ? context.l10n.timesInList(s.times) : null,
              visualDensity: VisualDensity.compact,
              onPressed: () => _useSuggestion(s),
            );
          },
        ),
      ),
    );
  }

  /// Prodotti di marca con foto e formato, in una riga che scorre: tocca per sceglierne uno.
  Widget _brandedRow() {
    if (_branded.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: SizedBox(
        height: 64,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: _branded.length,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (context, i) {
            final p = _branded[i];
            return SizedBox(
              width: 220,
              child: Card(
                margin: EdgeInsets.zero,
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => _useBranded(p),
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: p.imageUrl == null
                              ? const SizedBox(width: 48, height: 48, child: Icon(Icons.shopping_basket_outlined))
                              : Image.network(
                                  p.imageUrl!,
                                  width: 48,
                                  height: 48,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => const SizedBox(
                                    width: 48,
                                    height: 48,
                                    child: Icon(Icons.shopping_basket_outlined),
                                  ),
                                ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                p.name,
                                maxLines: p.quantity == null ? 2 : 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodyMedium,
                              ),
                              if (p.quantity != null)
                                Text(
                                  p.quantity!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodySmall,
                                ),
                            ],
                          ),
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final onBar = scheme.onInverseSurface;
    // Barra scura arrotondata, sospesa sopra la pagina: foto, nome, voce, quantità e "+" arancio.
    final bar = Material(
      color: scheme.inverseSurface,
      shape: const StadiumBorder(),
      elevation: widget.compact ? 0 : 6,
      shadowColor: Colors.black38,
      child: IconButtonTheme(
        data: IconButtonThemeData(style: IconButton.styleFrom(foregroundColor: onBar)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(6, 4, 6, 4),
          child: Row(
            children: [
              _PhotoButton(path: _photoPath, onPressed: _pickPhoto),
              Expanded(
                child: TextField(
                  controller: _name,
                  focusNode: _focus,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _submit(),
                  style: TextStyle(color: onBar, fontSize: 16),
                  cursorColor: scheme.secondary,
                  decoration: InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    hintText: context.l10n.addProductHint,
                    hintStyle: TextStyle(color: onBar.withValues(alpha: 0.65)),
                  ),
                ),
              ),
              VoiceInputButton(controller: _name, onResult: _onDictated, compact: true),
              // Quantità e peso accanto al nome: un'icona, o il valore scelto (es. "2 · 500 g").
              _MeasureButton(measure: _measure, onPressed: _editMeasure),
              const SizedBox(width: 4),
              IconButton.filled(
                style: IconButton.styleFrom(backgroundColor: scheme.secondary, foregroundColor: scheme.onSecondary),
                onPressed: _busy ? null : _submit,
                icon: const Icon(Icons.add),
                tooltip: context.l10n.add,
              ),
            ],
          ),
        ),
      ),
    );
    return SafeArea(
      top: false,
      bottom: !widget.compact,
      child: Padding(
        // Nel corpo della pagina (compact) la tastiera la gestisce già lo Scaffold.
        padding: EdgeInsets.fromLTRB(
          12,
          widget.compact ? 4 : 6,
          12,
          (widget.compact ? 6 : 12) + (widget.compact ? 0 : MediaQuery.viewInsetsOf(context).bottom),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_focus.hasFocus) _brandedRow(),
            if (_focus.hasFocus) _suggestionsRow(),
            const SizedBox(height: 6),
            bar,
          ],
        ),
      ),
    );
  }
}

/// Quantità (pezzi) e peso o volume del prodotto che si sta aggiungendo.
class _Measure {
  const _Measure({this.quantity, this.amount, this.unit = 'g'});

  final String? quantity;
  final double? amount;
  final String unit;

  bool get isEmpty => quantity == null && amount == null;

  /// Es. "2", "500 g", "2 · 1,5 l".
  String get label => [?quantity, if (amount != null) '${formatAmount(amount!)} $unit'].join(' · ');
}

/// Pulsante accanto al nome del prodotto: bilancia se non c'è nulla, altrimenti il valore scelto.
class _MeasureButton extends StatelessWidget {
  const _MeasureButton({required this.measure, required this.onPressed});

  final _Measure measure;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    if (measure.isEmpty) {
      return IconButton(
        icon: const Icon(Icons.scale_outlined),
        tooltip: context.l10n.quantityAndWeight,
        visualDensity: VisualDensity.compact,
        onPressed: onPressed,
      );
    }
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: context.l10n.changeQuantityAndWeight,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 88),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(color: scheme.secondaryContainer, borderRadius: BorderRadius.circular(999)),
          child: Text(
            measure.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(color: scheme.onSecondaryContainer),
          ),
        ),
      ),
    );
  }
}

/// Scelta di quantità (− / +) e peso o volume con l'unità, in un foglio dal basso che non copre la lista.
class _MeasureSheet extends StatefulWidget {
  const _MeasureSheet({required this.initial, required this.units});

  final _Measure initial;
  final List<String> units;

  @override
  State<_MeasureSheet> createState() => _MeasureSheetState();
}

class _MeasureSheetState extends State<_MeasureSheet> {
  late int _quantity = int.tryParse(widget.initial.quantity ?? '') ?? 0;
  late final _amount = TextEditingController(
    text: widget.initial.amount == null ? '' : formatAmount(widget.initial.amount!),
  );
  late String _unit = widget.units.contains(widget.initial.unit)
      ? widget.initial.unit
      : (widget.units.contains('g') ? 'g' : widget.units.first);
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  void _done() {
    final amount = _parseAmount(_amount.text);
    if (amount != null && amount.isNaN) {
      setState(() => _error = context.l10n.amountExampleError);
      return;
    }
    Navigator.pop(context, _Measure(quantity: _quantity > 0 ? '$_quantity' : null, amount: amount, unit: _unit));
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final l = context.l10n;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 16 + MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(l.quantity, style: text.titleSmall)),
                IconButton.outlined(
                  icon: const Icon(Icons.remove),
                  tooltip: l.less,
                  onPressed: _quantity > 0 ? () => setState(() => _quantity--) : null,
                ),
                SizedBox(
                  width: 44,
                  child: Text(_quantity == 0 ? '–' : '$_quantity', textAlign: TextAlign.center, style: text.titleLarge),
                ),
                IconButton.outlined(
                  icon: const Icon(Icons.add),
                  tooltip: l.more,
                  onPressed: () => setState(() => _quantity++),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(l.weightOrVolume, style: text.titleSmall),
            SizedBox(
              width: 140,
              child: TextField(
                controller: _amount,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(hintText: l.amountHint, isDense: true, errorText: _error),
                onChanged: (_) => setState(() => _error = null),
                onSubmitted: (_) => _done(),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final u in widget.units)
                  ChoiceChip(
                    label: Text(u),
                    selected: u == _unit,
                    showCheckmark: false,
                    visualDensity: VisualDensity.compact,
                    onSelected: (_) => setState(() => _unit = u),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context, _Measure(unit: _unit)),
                  child: Text(l.clearMeasure),
                ),
                const Spacer(),
                FilledButton(onPressed: _done, child: Text(l.done)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Fotocamera della barra di aggiunta: diventa la miniatura della foto scelta.
class _PhotoButton extends StatelessWidget {
  const _PhotoButton({required this.path, required this.onPressed});

  final String? path;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    if (path == null) {
      return IconButton(
        icon: const Icon(Icons.add_a_photo_outlined),
        tooltip: context.l10n.productPhoto,
        onPressed: onPressed,
      );
    }
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.file(File(path!), width: 40, height: 40, fit: BoxFit.cover),
        ),
      ),
    );
  }
}

/// Valori confermati nel dialogo di modifica.
class _ItemEdit {
  const _ItemEdit({
    required this.name,
    this.quantity,
    this.amount,
    this.unit,
    this.category,
    this.customIcon,
    this.imageUrl,
    this.photoPath,
    this.removePhoto = false,
  }) : delete = false;

  /// L'utente ha scelto "Elimina articolo".
  const _ItemEdit.delete()
    : name = '',
      quantity = null,
      amount = null,
      unit = null,
      category = null,
      customIcon = null,
      imageUrl = null,
      photoPath = null,
      removePhoto = false,
      delete = true;

  final bool delete;

  /// Nuova foto scelta dalla galleria o dalla fotocamera.
  final String? photoPath;

  /// Togliere la foto caricata.
  final bool removePhoto;

  final String name;
  final String? quantity;
  final double? amount;
  final String? unit;

  /// Emoji scelta dall'utente (null = quella riconosciuta dal nome).
  final String? customIcon;

  /// Link a un'immagine esterna (null = nessuna).
  final String? imageUrl;

  /// Solo se l'utente ha scelto un reparto diverso.
  final String? category;
}

class _EditItemDialog extends StatefulWidget {
  const _EditItemDialog({required this.item, required this.listId, required this.units, required this.categories});

  final ListItem item;
  final int listId;
  final List<String> units;
  final List<ProductCategory> categories;

  @override
  State<_EditItemDialog> createState() => _EditItemDialogState();
}

class _EditItemDialogState extends State<_EditItemDialog> {
  late final _name = TextEditingController(text: widget.item.name);
  late final _quantity = TextEditingController(text: widget.item.quantity);
  late final _amount = TextEditingController(text: widget.item.amount == null ? '' : formatAmount(widget.item.amount!));
  late String _unit = widget.item.unit ?? (widget.units.contains('g') ? 'g' : widget.units.first);
  late String _category = widget.item.category;
  late final _emoji = TextEditingController(text: widget.item.customIcon);
  late final _imageUrl = TextEditingController(text: widget.item.imageUrl);
  String? _amountError;
  String? _emojiError;
  String? _imageUrlError;
  String? _photoPath;
  bool _removePhoto = false;

  Future<void> _pickPhoto() async {
    final hasPhoto = _photoPath != null || (widget.item.imageVersion != null && !_removePhoto);
    final choice = await askPhotoSource(context, canRemove: hasPhoto, title: context.l10n.productPhoto);
    if (choice == null) return;
    if (choice == PhotoChoice.remove) {
      setState(() {
        _photoPath = null;
        _removePhoto = true;
      });
      return;
    }
    try {
      final path = await pickPhoto(choice);
      if (path != null && mounted) {
        setState(() {
          _photoPath = path;
          _removePhoto = false;
        });
      }
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  /// Emoji proposte (si può anche scriverne una qualsiasi con la tastiera).
  static const _suggestions = [
    '⭐', '❤️', '🔥', '❗', '🎉', '🎂', '🍕', '🍔', '🥗', '🍷', '☕', '🍫', //
    '🥩', '🐟', '🥦', '🍓', '🧃', '🍼', '👶', '🐶', '🐱', '💊', '🧻', '🎁',
  ];

  @override
  void dispose() {
    _name.dispose();
    _quantity.dispose();
    _amount.dispose();
    _emoji.dispose();
    _imageUrl.dispose();
    super.dispose();
  }

  /// Link http(s) valido oppure null se vuoto; lancia un messaggio d'errore se non valido.
  String? _checkUrl(String text) {
    final t = text.trim();
    if (t.isEmpty) return null;
    final uri = Uri.tryParse(t);
    if (uri == null || !(uri.isScheme('http') || uri.isScheme('https')) || uri.host.isEmpty) {
      throw context.l10n.invalidImageUrl;
    }
    return t;
  }

  void _save() {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    final amount = _parseAmount(_amount.text);
    if (amount != null && amount.isNaN) {
      setState(() => _amountError = context.l10n.invalidNumber);
      return;
    }
    final emoji = _emoji.text.trim();
    if (emoji.length > 16) {
      setState(() => _emojiError = context.l10n.emojiTooLong);
      return;
    }
    final String? imageUrl;
    try {
      imageUrl = _checkUrl(_imageUrl.text);
    } on String catch (message) {
      setState(() => _imageUrlError = message);
      return;
    }
    final qty = _quantity.text.trim();
    Navigator.pop(
      context,
      _ItemEdit(
        name: name,
        quantity: qty.isEmpty ? null : qty,
        amount: amount,
        unit: amount == null ? null : _unit,
        category: _category == widget.item.category ? null : _category,
        customIcon: emoji.isEmpty ? null : emoji,
        imageUrl: imageUrl,
        photoPath: _photoPath,
        removePhoto: _removePhoto && widget.item.imageVersion != null,
      ),
    );
  }

  Widget _photoPreview() {
    final ImageProvider? image = _photoPath != null
        ? FileImage(File(_photoPath!))
        : (_removePhoto || widget.item.imageVersion == null)
        ? null
        : itemImageProvider(context.read<ApiClient>(), widget.item, widget.listId);
    return InkWell(
      onTap: _pickPhoto,
      borderRadius: BorderRadius.circular(12),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: image == null
                ? Container(
                    width: 64,
                    height: 64,
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    child: const Icon(Icons.add_a_photo_outlined),
                  )
                : Image(image: image, width: 64, height: 64, fit: BoxFit.cover),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(image == null ? context.l10n.addProductPhoto : context.l10n.changeOrRemovePhoto)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final known = widget.categories.any((c) => c.slug == _category);
    final l = context.l10n;
    return AlertDialog(
      title: Text(l.editItem),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _photoPreview(),
            const SizedBox(height: 8),
            TextField(
              controller: _name,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: l.product,
                suffixIcon: VoiceInputButton(controller: _name, compact: true),
              ),
            ),
            TextField(
              controller: _quantity,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: l.quantityOptional),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: _amount,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(labelText: l.weightOptional, errorText: _amountError),
                  ),
                ),
                const SizedBox(width: 12),
                _UnitPicker(units: widget.units, value: _unit, onChanged: (u) => setState(() => _unit = u)),
              ],
            ),
            if (known) ...[
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _category,
                isExpanded: true,
                decoration: InputDecoration(labelText: l.department, helperText: l.departmentHelper),
                items: [
                  for (final c in widget.categories)
                    DropdownMenuItem(value: c.slug, child: Text('${c.icon}  ${c.label}')),
                ],
                onChanged: (v) => setState(() => _category = v ?? _category),
              ),
            ],
            const SizedBox(height: 16),
            TextField(
              controller: _emoji,
              decoration: InputDecoration(
                labelText: l.emojiOptional,
                hintText: l.recognizedEmoji(widget.item.customIcon == null ? widget.item.icon : l.fromName),
                errorText: _emojiError,
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear),
                  tooltip: l.useRecognizedEmoji,
                  onPressed: () => setState(() => _emoji.clear()),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 2,
              children: [
                for (final e in _suggestions)
                  InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => setState(() {
                      _emoji.text = e;
                      _emojiError = null;
                    }),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Text(e, style: const TextStyle(fontSize: 22)),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _imageUrl,
              keyboardType: TextInputType.url,
              decoration: InputDecoration(
                labelText: l.imageLinkOptional,
                hintText: 'https://…/foto.jpg',
                errorText: _imageUrlError,
                prefixIcon: const Icon(Icons.image_outlined),
              ),
              onChanged: (_) => setState(() => _imageUrlError = null),
            ),
          ],
        ),
      ),
      actions: [
        TextButton.icon(
          onPressed: () => Navigator.pop(context, const _ItemEdit.delete()),
          icon: const Icon(Icons.delete_outline),
          label: Text(l.delete),
          style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
        ),
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l.cancel)),
        FilledButton(onPressed: _save, child: Text(l.save)),
      ],
    );
  }
}
