import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/l10n.dart';
import '../models/branded_product.dart';
import '../models/chat_message.dart';
import '../models/list_item.dart';
import '../models/user_price.dart';
import '../models/measure_mode.dart';
import '../models/shopping_list.dart';
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
import '../widgets/photo_gallery.dart';
import '../widgets/photo_picker.dart';
import '../widgets/prices.dart';
import '../widgets/product_info_sheet.dart';
import '../widgets/report.dart';
import '../theme/app_theme.dart';
import '../widgets/guide.dart';
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

  /// Chat della lista: esiste solo con almeno due persone (vedi _syncChat). Si apre in un foglio sopra la lista.
  ChatController? _chat;
  StreamSubscription<ChatMessage>? _incomingSub;

  /// Chat aperta sotto la lista, nella stessa schermata.
  bool _chatOpen = false;

  /// Da aprire appena la chat esiste (notifica di un messaggio toccata).
  late bool _openChatPending = widget.openChat;

  /// Ultimo messaggio arrivato, mostrato per 15 secondi sopra la barra (compare e svanisce in dissolvenza).
  ChatMessage? _incoming;

  /// Messaggio da evidenziare aprendo la chat (toccando l'anteprima sopra la barra).
  int? _highlightId;

  /// Prodotti mostrati: tutti (null), solo da prendere o solo presi.
  ItemStatus? _filter;

  late final NotificationService _notifications;
  late final int _listId;

  /// Comandi illuminati dalla guida passo passo (dopo "Nuova lista").
  final _addFieldKey = GlobalKey();
  final _addButtonKey = GlobalKey();
  final _shareKey = GlobalKey();
  bool _guideChecked = false;

  @override
  void initState() {
    super.initState();
    // Mentre la lista è aperta le sue modifiche non generano notifiche e la sua conversazione sparisce.
    _listId = context.read<ListDetailController>().listId;
    _notifications = context.read<NotificationService>()..activeListId = _listId;
  }

  /// Seconda parte della guida, la prima volta che si apre una lista dopo "Nuova lista": scrivere un prodotto, il
  /// + con quantità e peso, la condivisione.
  Future<void> _maybeContinueGuide(ListDetailController detail) async {
    final me = context.read<AuthController>().user;
    if (_guideChecked || me == null || detail.list == null || !detail.canEdit) return;
    _guideChecked = true;
    if (await GuideProgress.stage(me.id) != GuideStage.detail || !mounted) return;
    final l = context.l10n;
    await GuideProgress.set(me.id, GuideStage.done);
    if (!mounted) return;
    await showGuide(
      context,
      [
        GuideStep(target: _addFieldKey, title: l.guideAddTitle, text: l.guideAddText),
        GuideStep(target: _addButtonKey, title: l.guidePlusTitle, text: l.guidePlusText),
        GuideStep(target: _shareKey, title: l.guideShareTitle, text: l.guideShareText),
      ],
      first: 2,
      total: guideSteps,
    );
  }

  @override
  void dispose() {
    if (_notifications.activeListId == _listId) _notifications.activeListId = null;
    _disposeChat();
    super.dispose();
  }

  // ── Chat ────────────────────────────────────────────────────────

  /// Crea la chat quando nella lista ci sono almeno due persone e la toglie se si resta da soli.
  void _syncChat(ListDetailController detail) {
    final wanted = detail.list != null && detail.hasOthers;
    if (wanted && _chat == null) {
      final chat = ChatController(
        api: context.read<ApiClient>(),
        realtime: context.read<RealtimeClient>(),
        listId: detail.listId,
        userId: detail.userId,
      )..start();
      _chat = chat;
      // Con la lista aperta i messaggi si vedono sopra la barra: niente notifica sul telefono.
      _notifications.activeChatListId = _listId;
      _incomingSub = chat.incoming.listen(_onIncoming);
      if (_openChatPending) {
        _openChatPending = false;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _openChat(detail);
        });
      }
    } else if (!wanted && _chat != null && detail.list != null) {
      _disposeChat();
    }
  }

  void _disposeChat() {
    _incomingSub?.cancel();
    _chat?.dispose();
    _chat = null;
    _incoming = null;
    if (_notifications.activeChatListId == _listId) _notifications.activeChatListId = null;
  }

  void _onIncoming(ChatMessage message) {
    if (_chatOpen || !mounted) return;
    setState(() => _incoming = message);
  }

  /// Chat aperta sotto la lista, come prima: da quel momento i messaggi degli altri risultano letti. Con [highlight]
  /// la chat scorre fino a quel messaggio e lo evidenzia.
  void _openChat(ListDetailController detail, {ChatMessage? highlight}) {
    final chat = _chat;
    if (chat == null || detail.list == null || _chatOpen) return;
    setState(() {
      _chatOpen = true;
      _incoming = null;
      _highlightId = highlight?.id;
    });
    chat.visible = true;
  }

  void _closeChat() {
    _chat?.visible = false;
    setState(() {
      _chatOpen = false;
      _highlightId = null;
    });
  }

  /// Prodotti presi da un messaggio della chat, aggiunti uno dopo l'altro.
  Future<void> _addNames(ListDetailController detail, List<String> names) async {
    for (final name in names) {
      await detail.addItem(name);
    }
  }

  /// Da soli nella lista: invito a condividerla per poter usare la chat (solo il proprietario può condividere).
  Widget _chatInvite(ListDetailController detail, ShoppingList list) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          side: BorderSide(color: scheme.outlineVariant),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          foregroundColor: scheme.onSurfaceVariant,
        ),
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ListShareScreen(listId: list.id, listName: list.name),
          ),
        ).then((_) => detail.load(silent: true)),
        icon: const Icon(Icons.forum_outlined),
        label: Text(context.l10n.chatInvite, textAlign: TextAlign.center),
      ),
    );
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

  /// Copia della lista con nuova data (e il resto a scelta): al termine si apre la copia al posto di questa.
  Future<void> _copy(ListDetailController detail) async {
    final lists = context.read<ListsController>();
    final navigator = Navigator.of(context);
    final created = await navigator.push<ShoppingList>(
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider.value(
          value: lists,
          child: ListFormScreen(copyOf: detail.list),
        ),
      ),
    );
    if (created == null || !mounted) return;
    final auth = context.read<AuthController>();
    await navigator.pushReplacement(
      MaterialPageRoute(
        builder: (_) => MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: lists),
            ChangeNotifierProvider(
              create: (context) => ListDetailController(
                api: context.read<ApiClient>(),
                realtime: context.read<RealtimeClient>(),
                listId: created.id,
                userId: auth.user!.id,
              )..start(),
            ),
          ],
          child: const ListDetailScreen(),
        ),
      ),
    );
  }

  Future<void> _onMenu(String value, ListDetailController detail) async {
    final lists = context.read<ListsController>();
    final l = context.l10n;
    switch (value) {
      case 'copy':
        await _copy(detail);
      case 'person':
        final owner = detail.list!.owner!;
        await showPersonActions(context, userId: owner.id, name: owner.name, listId: detail.listId);
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
  /// Scheda "Info" del prodotto (da Open Food Facts).
  void _openInfo(ListDetailController detail, ListItem item) =>
      showProductInfo(context, item: item, info: detail.productInfo(item));

  /// Il mio prezzo per il prodotto: si salva nella sezione "I miei prezzi", compare sotto l'articolo e lo vede solo
  /// l'utente. Se ne ha già uno per questo prodotto, lo modifica.
  Future<void> _addMyPrice(ListDetailController detail, ListItem item) async {
    final existing = detail.myPriceFor(item);
    final price = await showMyPriceDialog(
      context,
      editing: existing != null,
      initial:
          existing ??
          UserPrice(
            id: 0,
            productName: item.name,
            price: 0,
            barcode: item.barcode,
            brand: item.brand,
            supermarket: detail.list?.supermarket,
          ),
    );
    if (price == null || !mounted) return;
    await _run(() async {
      await detail.saveMyPrice(price);
      if (mounted) showMessage(context, context.l10n.myPriceSaved);
    });
  }

  Future<void> _itemActions(ListDetailController detail, ListItem item) async {
    final error = Theme.of(context).colorScheme.error;
    final l = context.l10n;
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      // Sette voci non stanno nella metà di schermo che un foglio ha di solito: alto quanto serve, e scorre
      // sui telefoni piccoli invece di andare in overflow.
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text('${item.icon}  ${item.name}', style: Theme.of(context).textTheme.titleMedium),
              ),
              // Presi e non trovati li segna solo chi fa la spesa (se è stato scelto qualcuno).
              if (detail.canMark) ...[
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
              ],
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
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: Text(l.info),
                onTap: () => Navigator.pop(context, 'info'),
              ),
              ListTile(
                leading: const Icon(Icons.euro),
                title: Text(l.myPrice),
                onTap: () => Navigator.pop(context, 'myPrice'),
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
      ),
    );
    if (!mounted) return;
    switch (action) {
      case 'taken':
        await _markTaken(detail, item);
      case 'missing':
        await _run(() => detail.setStatus(item, ItemStatus.missing));
      case 'edit':
        await _editItem(detail, item);
      case 'photo':
        await _itemPhotoMenu(detail, item);
      case 'info':
        _openInfo(detail, item);
      case 'myPrice':
        await _addMyPrice(detail, item);
      case 'delete':
        await _deleteItem(detail, item);
    }
  }

  // ── Chi fa la spesa e "Spesa finita" ────────────────────────────

  /// "Spesa finita" che l'utente ha chiuso con «Va bene così» (per lista e istante), finché l'app resta aperta.
  static final _dismissedFinishes = <String>{};

  /// Tocco sul cerchio: preso / di nuovo da prendere. Chi non fa la spesa riceve la spiegazione; preso l'ultimo
  /// prodotto, si propone di avvisare gli altri.
  Future<void> _markTaken(ListDetailController detail, ListItem item) async {
    final shopper = detail.list?.shopper;
    if (!detail.canMark) {
      if (shopper != null) showMessage(context, context.l10n.onlyShopperCanMark(shopper.name));
      return;
    }
    await _run(() => detail.setStatus(item, ItemStatus.taken));
    final list = detail.list;
    if (!mounted || list == null || list.finishedAt != null || !detail.hasOthers) return;
    if (item.checked || detail.notTakenCount > 0) return;
    final l = context.l10n;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(l.allTaken),
          duration: const Duration(seconds: 8),
          action: SnackBarAction(label: l.finishShoppingComplete, onPressed: () => _finish(detail)),
        ),
      );
  }

  Future<void> _finish(ListDetailController detail) async {
    final message = await showModalBottomSheet<_FinishResult>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => _FinishSheet(items: detail.items, hasOthers: detail.hasOthers),
    );
    if (message == null || !mounted) return;
    await _run(() async {
      await detail.finishShopping(message: message.text);
      if (mounted) showMessage(context, detail.hasOthers ? context.l10n.finishedNotified : context.l10n.finishShopping);
    });
  }

  Future<void> _takeOver(ListDetailController detail) => _run(() async {
    await detail.takeOverShopping();
    if (mounted) showMessage(context, context.l10n.tookOver);
  });

  /// Sotto la barra di avanzamento: chi fa la spesa, l'avviso "Spesa finita" per gli altri e il pulsante per chi
  /// fa la spesa (compare quando ha già segnato almeno un prodotto).
  List<Widget> _shoppingRun(ListDetailController detail) {
    final list = detail.list!;
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final items = detail.items;
    final notTaken = detail.notTakenCount;
    final finishedBy = list.finishedBy;
    final finishedKey = '${list.id}-${list.finishedAt?.toIso8601String()}';
    return [
      if (list.shopper != null)
        ListTile(
          dense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20),
          leading: Icon(Icons.shopping_cart_outlined, color: scheme.onSurfaceVariant),
          title: Text(list.shopper!.id == detail.userId ? l.shopperIsMe : l.shopperIs(list.shopper!.name)),
        ),
      if (list.finishedAt != null && finishedBy != null && finishedBy.id != detail.userId)
        if (!_dismissedFinishes.contains(finishedKey))
          _FinishedBanner(
            name: finishedBy.name,
            at: list.finishedAt!,
            missing: notTaken,
            message: list.finishMessage,
            onTakeOver: detail.canEdit && notTaken > 0 ? () => _takeOver(detail) : null,
            onDismiss: () => setState(() => _dismissedFinishes.add(finishedKey)),
          ),
      if (detail.canMark && list.finishedAt == null && items.any((i) => i.status != ItemStatus.todo))
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: FilledButton(
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            ),
            onPressed: () => _finish(detail),
            child: Row(
              children: [
                const Icon(Icons.shopping_cart_checkout),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(notTaken == 0 ? l.finishShoppingComplete : l.finishShopping),
                      Text(
                        !detail.hasOthers
                            ? l.finishAloneInfo(notTaken)
                            : notTaken == 0
                            ? l.finishCompleteInfo
                            : l.finishMissingInfo(notTaken),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onPrimary),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right),
              ],
            ),
          ),
        ),
    ];
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
    if (!_guideChecked && detail.list != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _maybeContinueGuide(detail);
      });
    }
    final list = detail.list;
    if (detail.gone) _closeBecauseGone();
    _syncChat(detail);
    final chat = _chat;
    final l = context.l10n;

    final round = roundButtonStyle(context);

    return Scaffold(
      appBar: AppBar(
        // Il nome della lista è il titolo grande nella pagina; qui logo e nome dell'app tra la freccia e i
        // pulsanti tondi, rimpiccioliti quanto serve per starci (AppName).
        titleSpacing: 4,
        title: const AppName(),
        leading: Center(
          child: IconButton(
            style: round,
            tooltip: MaterialLocalizations.of(context).backButtonTooltip,
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.maybePop(context),
          ),
        ),
        actions: [
          // La chat c'è solo con almeno due persone nella lista; il pallino conta i messaggi da leggere.
          if (chat != null)
            ListenableBuilder(
              listenable: chat,
              builder: (context, _) => IconButton(
                style: round,
                tooltip: l.chat,
                icon: Badge(
                  isLabelVisible: chat.unreadCount > 0,
                  label: Text('${chat.unreadCount}'),
                  child: const Icon(Icons.chat_bubble_outline),
                ),
                isSelected: _chatOpen,
                selectedIcon: const Icon(Icons.chat_bubble),
                onPressed: () => _chatOpen ? _closeChat() : _openChat(detail),
              ),
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
              key: _shareKey,
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
                PopupMenuItem(value: 'copy', child: Text(l.duplicateList)),
                if (list.isOwner) PopupMenuItem(value: 'delete', child: Text(l.deleteList)),
                if (detail.canLeave) PopupMenuItem(value: 'leave', child: Text(l.leaveList)),
                if (!list.isOwner && list.owner != null)
                  PopupMenuItem(value: 'person', child: Text(l.reportOrBlock(list.owner!.name))),
              ],
            ),
          const SizedBox(width: 8),
        ],
      ),
      // Con la chat aperta: lista in alto (si spunta e si aggiunge), chat in basso.
      body: Wallpaper(
        child: _chatOpen && chat != null && list != null
            ? Column(
                children: [
                  Expanded(flex: 5, child: _body(detail)),
                  if (detail.canEdit) _addBar(detail, compact: true),
                  Expanded(
                    flex: 4,
                    child: _ChatSheet(
                      onClose: _closeChat,
                      child: ChangeNotifierProvider.value(
                        value: chat,
                        child: ChatPanel(
                          isOwner: list.isOwner,
                          highlightId: _highlightId,
                          onAddToList: detail.canEdit ? (names) => _addNames(detail, names) : null,
                        ),
                      ),
                    ),
                  ),
                ],
              )
            : Stack(
                children: [
                  Positioned.fill(child: _body(detail)),
                  // Sopra la barra, sui prodotti: l'ultimo messaggio arrivato (tocca per aprirlo in chat).
                  if (_incoming != null && chat != null)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: detail.canEdit ? 0 : MediaQuery.paddingOf(context).bottom,
                      child: ListenableBuilder(
                        listenable: chat,
                        builder: (_, _) => _IncomingStrip(
                          key: ValueKey(_incoming!.id),
                          message: _incoming!,
                          unread: chat.unreadCount,
                          onOpen: () => _openChat(detail, highlight: _incoming),
                          onDone: () {
                            if (mounted) setState(() => _incoming = null);
                          },
                        ),
                      ),
                    ),
                ],
              ),
      ),
      // In basso: la barra per aggiungere prodotti.
      bottomNavigationBar: _chatOpen && chat != null ? null : (detail.canEdit ? _addBar(detail) : null),
    );
  }

  Widget _addBar(ListDetailController detail, {bool compact = false}) => _AddItemBar(
    fieldKey: compact ? null : _addFieldKey,
    addKey: compact ? null : _addButtonKey,
    units: _units,
    compact: compact,
    suggestions: detail.suggestions,
    existing: [for (final item in detail.items) item.name],
    search: detail.searchProducts,
    measureOf: detail.api.productMeasure,
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
    final todo = items.where((i) => i.status == ItemStatus.todo).length;
    final taken = detail.checkedCount;
    // Se il filtro scelto resta senza prodotti (es. preso l'ultimo da prendere) si torna al totale.
    final filter = switch (_filter) {
      ItemStatus.todo when todo > 0 => ItemStatus.todo,
      ItemStatus.taken when taken > 0 => ItemStatus.taken,
      _ => null,
    };
    final shown = filter == null
        ? items
        : [
            for (final item in items)
              if (item.status == filter) item,
          ];
    final api = context.read<ApiClient>();
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return RefreshIndicator(
      onRefresh: () => detail.load(silent: true),
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          // Con la foto della lista: la foto fa da sfondo, con nome e data sopra; senza, il titolo grande.
          if (list.imageVersion != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: _PhotoHeading(
                image: NetworkImage(api.listImageUrl(list.id, list.imageVersion!), headers: api.authHeaders),
                title: list.name,
                subtitle: _ListMeta(detail: detail, onPhoto: true),
                compact: _chatOpen,
                onTap: detail.canEdit ? () => _photoMenu(detail) : null,
              ),
            )
          else
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
          if (!_chatOpen) ..._shoppingRun(detail),
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
          // I filtri compaiono quando almeno un prodotto ha cambiato stato: prima "Totale" e "Da prendere" coincidono.
          if (todo < items.length) _filterBar(total: items.length, todo: todo, taken: taken, selected: filter),
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Text(l.emptyList, textAlign: TextAlign.center),
            ),
          for (final group in groupByCategory(shown, _categories.map((c) => c.slug).toList())) ...[
            _CategoryHeader(
              category: _categories.firstWhere(
                (c) => c.slug == group.category,
                orElse: () => ProductCategory(slug: 'altro', label: l.other, icon: '🛒'),
              ),
            ),
            for (final item in group.items) _itemTile(detail, item),
          ],
          if (list.isOwner && list.people.isNotEmpty && !detail.hasOthers) _chatInvite(detail, list),
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

  /// Pulsanti sopra i prodotti, ognuno col suo conteggio: totale (predefinito), poi "Da prendere" e "Presi" solo
  /// se ci sono prodotti in quello stato. Si mostrano solo quando almeno un prodotto non è più da prendere.
  Widget _filterBar({required int total, required int todo, required int taken, required ItemStatus? selected}) {
    final l = context.l10n;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
      child: SegmentedButton<ItemStatus?>(
        showSelectedIcon: false,
        segments: [
          ButtonSegment(value: null, label: Text('${l.filterAll} · $total')),
          if (todo > 0) ButtonSegment(value: ItemStatus.todo, label: Text('${l.filterToBuy} · $todo')),
          if (taken > 0) ButtonSegment(value: ItemStatus.taken, label: Text('${l.filterTaken} · $taken')),
        ],
        selected: {selected},
        onSelectionChanged: (s) => setState(() => _filter = s.first),
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
    final myPrice = detail.myPriceFor(item);
    final details = [
      ?item.measureLabel,
      if (myPrice != null)
        myPrice.per == 'pz'
            ? formatPrice(context, myPrice.price)
            : '${formatPrice(context, myPrice.price)} ${perLabel(myPrice.per, l)}',
      if (item.checked && item.checkedBy != null) l.takenBy(item.checkedBy!),
      if (item.missing) item.checkedBy == null ? l.notFoundLower : l.notFoundBy(item.checkedBy!),
    ].join(' · ');
    final taken = detail.canEdit ? () => _markTaken(detail, item) : null;

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
/// Anteprima dell'ultimo messaggio arrivato, su sfondo trasparente sopra la barra: compare in dissolvenza, resta 15
/// secondi e svanisce. Toccandola si apre la chat sul messaggio; la x la chiude subito.
class _IncomingStrip extends StatefulWidget {
  const _IncomingStrip({
    super.key,
    required this.message,
    required this.unread,
    required this.onOpen,
    required this.onDone,
  });

  final ChatMessage message;

  /// Messaggi degli altri ancora da leggere.
  final int unread;
  final VoidCallback onOpen;

  /// Anteprima svanita (tempo scaduto o x).
  final VoidCallback onDone;

  static const visibleFor = Duration(seconds: 15);

  @override
  State<_IncomingStrip> createState() => _IncomingStripState();
}

class _IncomingStripState extends State<_IncomingStrip> with SingleTickerProviderStateMixin {
  late final _fade = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 400),
    reverseDuration: const Duration(milliseconds: 900),
  )..forward();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(_IncomingStrip.visibleFor, _hide);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _fade.dispose();
    super.dispose();
  }

  Future<void> _hide() async {
    _timer?.cancel();
    await _fade.reverse();
    if (mounted) widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    final message = widget.message;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final l = context.l10n;
    final body = message.body.isNotEmpty ? message.body : (message.hasImage ? '📷 ${l.chatPhoto}' : '');
    final name = message.userName ?? l.deletedUser;
    return FadeTransition(
      opacity: CurvedAnimation(parent: _fade, curve: Curves.easeOut),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
        child: Material(
          color: scheme.surface.withValues(alpha: 0.6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.6)),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () {
              _timer?.cancel();
              widget.onOpen();
            },
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 6, 8),
              child: Row(
                children: [
                  UserAvatar(initials: name.isEmpty ? '?' : name[0].toUpperCase()),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, style: text.labelMedium?.copyWith(color: scheme.tertiary)),
                        Text(body, maxLines: 2, overflow: TextOverflow.ellipsis, style: text.bodyMedium),
                      ],
                    ),
                  ),
                  if (widget.unread > 0) Badge.count(count: widget.unread),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                    onPressed: _hide,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

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
      // Galleria: la foto dell'articolo e poi quelle del prodotto su Open Food Facts (ingredienti, valori…).
      onTap: () => showPhotoGallery(
        context,
        [image],
        caption: '${item.icon}  ${item.name}',
        more: context
            .read<ListDetailController>()
            .productInfo(item)
            .then(
              (info) => [
                for (final url in info?.images ?? const <String>[])
                  if (url != item.imageUrl) NetworkImage(url),
              ],
            ),
      ),
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

/// Riga sotto il nome della lista: giorno e ora, chi la sta guardando (canale presence) e, finché scrive
/// nella chat, chi sta scrivendo.
class _ListMeta extends StatelessWidget {
  const _ListMeta({required this.detail, this.onPhoto = false});

  final ListDetailController detail;

  /// Sopra la foto della lista: chi sta scrivendo in bianco, non nel verde del tema.
  final bool onPhoto;

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
              style: TextStyle(color: onPhoto ? Colors.white : primary, fontWeight: FontWeight.w600),
            ),
        ],
      ),
    );
  }
}

/// Testata della lista con la sua foto come sfondo: nome e data in basso, in bianco su una sfumatura scura che li
/// rende leggibili su qualsiasi foto. Il nome è di misura media (non il titolo grande della pagina senza foto).
class _PhotoHeading extends StatelessWidget {
  const _PhotoHeading({
    required this.image,
    required this.title,
    required this.subtitle,
    this.compact = false,
    this.onTap,
  });

  final ImageProvider image;
  final String title;
  final Widget subtitle;

  /// Più bassa con la chat aperta.
  final bool compact;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    const shadow = [Shadow(color: Colors.black54, blurRadius: 6)];
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: SizedBox(
        height: compact ? 120 : 210,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image(
              image: image,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => ColoredBox(color: Theme.of(context).colorScheme.primary),
            ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [0.35, 1],
                  colors: [Colors.transparent, Color(0xB3000000)],
                ),
              ),
            ),
            Positioned(
              left: 18,
              right: 18,
              bottom: 14,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: (compact ? text.titleLarge : text.headlineSmall)?.copyWith(
                      color: Colors.white,
                      shadows: shadow,
                    ),
                  ),
                  const SizedBox(height: 4),
                  DefaultTextStyle.merge(
                    style: text.bodyMedium?.copyWith(color: Colors.white.withValues(alpha: 0.9), shadows: shadow),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    child: subtitle,
                  ),
                ],
              ),
            ),
            if (onTap != null)
              Material(
                type: MaterialType.transparency,
                child: InkWell(onTap: onTap),
              ),
          ],
        ),
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
    this.measureOf,
    this.fieldKey,
    this.addKey,
    this.compact = false,
    this.suggestions = const [],
    this.existing = const [],
  });

  /// Più sottile, con la chat aperta sotto.
  final bool compact;

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

  /// Come si misura un nome scritto a mano (dal server): solo peso, peso e pezzi o confezioni.
  final Future<MeasureMode?> Function(String name)? measureOf;

  /// Campo del nome e "+", illuminati dalla guida passo passo.
  final Key? fieldKey;
  final Key? addKey;

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
    if (_chosen != null && text != _chosen!.name) {
      // Lasciato il prodotto di marca: via anche il peso della sua confezione, non è di questo prodotto.
      final package = _chosen!;
      _chosen = null;
      if (_measure.amount == package.amount && _measure.unit == package.unit) {
        setState(() => _measure = _Measure(quantity: _measure.quantity));
      }
    }
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
  /// Poi il popup (già compilato con la confezione) e "Fatto" lo aggiunge.
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
    _askMeasureAndAdd();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  /// Suggerimento toccato: scrive il nome e apre il popup; "Fatto" lo aggiunge.
  void _useSuggestion(ProductSuggestion suggestion) {
    _name.value = TextEditingValue(
      text: suggestion.name,
      selection: TextSelection.collapsed(offset: suggestion.name.length),
    );
    _askMeasureAndAdd();
  }

  @override
  void dispose() {
    _searchTimer?.cancel();
    _name.dispose();
    _focus.dispose();
    super.dispose();
  }

  /// Come si misura quello che si sta aggiungendo: un prodotto di marca è una confezione; poi il suggerimento
  /// con lo stesso nome; poi il server (che considera confezionato un prodotto non riconosciuto). Null (senza
  /// rete): tutti i campi.
  Future<MeasureMode?> _measureMode() async {
    if (_chosen != null) return MeasureMode.count;
    final name = _name.text.trim();
    if (name.isEmpty) return null;
    final key = name.toLowerCase();
    for (final s in widget.suggestions) {
      if (s.name.toLowerCase() == key) return s.measure;
    }
    try {
      return await widget.measureOf?.call(name);
    } catch (_) {
      return null;
    }
  }

  /// Popup di quantità e peso/volume (solo i campi che servono per il prodotto): "Fatto" lo aggiunge alla lista,
  /// chiuderlo in altro modo no. Si apre dai suggerimenti (con o senza foto), dal "+" e dall'invio della tastiera.
  Future<void> _askMeasureAndAdd() async {
    if (_name.text.trim().isEmpty || _busy) return;
    final mode = await _measureMode();
    if (!mounted) return;
    final result = await showModalBottomSheet<_Measure>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => _MeasureSheet(initial: _measure, units: widget.units, mode: mode),
    );
    if (!mounted) return;
    if (result == null) {
      _focus.requestFocus();
      return;
    }
    setState(() => _measure = result);
    await _submit();
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
                key: widget.fieldKey,
                child: TextField(
                  controller: _name,
                  focusNode: _focus,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _askMeasureAndAdd(),
                  style: TextStyle(color: onBar, fontSize: 16),
                  cursorColor: scheme.secondary,
                  decoration: InputDecoration(
                    isDense: true,
                    // Il campo è già nella barra colorata: niente riquadro bianco.
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    hintText: context.l10n.addProductHint,
                    hintStyle: TextStyle(color: onBar.withValues(alpha: 0.65)),
                  ),
                ),
              ),
              VoiceInputButton(controller: _name, onResult: _onDictated, compact: true),
              const SizedBox(width: 4),
              // "+": prima il popup di quantità e peso/volume, poi "Fatto" aggiunge.
              IconButton.filled(
                key: widget.addKey,
                style: IconButton.styleFrom(backgroundColor: scheme.secondary, foregroundColor: scheme.onSecondary),
                onPressed: _busy ? null : _askMeasureAndAdd,
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
}

/// Scelta di quantità (− / +) e peso o volume con l'unità, in un foglio dal basso che non copre la lista.
/// Solo i campi che servono per [mode]: sfuso a peso → peso; frutta e verdura a pezzi → peso e pezzi;
/// confezione → quante confezioni (il peso è quello della confezione, solo da leggere); null → tutto.
class _MeasureSheet extends StatefulWidget {
  const _MeasureSheet({required this.initial, required this.units, this.mode});

  final _Measure initial;
  final List<String> units;
  final MeasureMode? mode;

  @override
  State<_MeasureSheet> createState() => _MeasureSheetState();
}

class _MeasureSheetState extends State<_MeasureSheet> {
  /// Sfuso: solo unità di peso.
  late final List<String> _units = widget.mode.isLoose
      ? [
          for (final u in widget.units)
            if (weightUnits.contains(u)) u,
        ]
      : widget.units;
  late int _quantity = int.tryParse(widget.initial.quantity ?? '') ?? 0;
  late final _amount = TextEditingController(
    text: widget.initial.amount == null || !_units.contains(widget.initial.unit)
        ? ''
        : formatAmount(widget.initial.amount!),
  );
  late String _unit = _units.contains(widget.initial.unit)
      ? widget.initial.unit
      : (_units.contains('g') || _units.isEmpty ? 'g' : _units.first);
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  void _done() {
    final mode = widget.mode;
    if (!mode.asksWeight) {
      // Confezione: il peso resta quello della confezione.
      Navigator.pop(
        context,
        _Measure(
          quantity: _quantity > 0 ? '$_quantity' : null,
          amount: widget.initial.amount,
          unit: widget.initial.unit,
        ),
      );
      return;
    }
    final amount = _parseAmount(_amount.text);
    if (amount != null && amount.isNaN) {
      setState(() => _error = context.l10n.amountExampleError);
      return;
    }
    Navigator.pop(
      context,
      _Measure(quantity: mode.asksQuantity && _quantity > 0 ? '$_quantity' : null, amount: amount, unit: _unit),
    );
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
            if (widget.mode.asksQuantity) ...[
              Row(
                children: [
                  Expanded(
                    child: Text(widget.mode == MeasureMode.count ? l.packages : l.quantity, style: text.titleSmall),
                  ),
                  IconButton.outlined(
                    icon: const Icon(Icons.remove),
                    tooltip: l.less,
                    onPressed: _quantity > 0 ? () => setState(() => _quantity--) : null,
                  ),
                  SizedBox(
                    width: 44,
                    child: Text(
                      _quantity == 0 ? '–' : '$_quantity',
                      textAlign: TextAlign.center,
                      style: text.titleLarge,
                    ),
                  ),
                  IconButton.outlined(
                    icon: const Icon(Icons.add),
                    tooltip: l.more,
                    onPressed: () => setState(() => _quantity++),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
            if (!widget.mode.asksWeight && widget.initial.amount != null)
              Text(
                l.packageSize('${formatAmount(widget.initial.amount!)} ${widget.initial.unit}'),
                style: text.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            if (widget.mode.asksWeight) ...[
              Text(widget.mode.isLoose ? l.weight : l.weightOrVolume, style: text.titleSmall),
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
                  for (final u in _units)
                    ChoiceChip(
                      label: Text(u),
                      selected: u == _unit,
                      showCheckmark: false,
                      visualDensity: VisualDensity.compact,
                      onSelected: (_) => setState(() => _unit = u),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                // Azzera i campi (il peso di una confezione resta, non si modifica); il popup resta aperto.
                TextButton(
                  onPressed: () => setState(() {
                    _quantity = 0;
                    _amount.clear();
                    _error = null;
                  }),
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

  /// Solo i campi che servono (vedi [MeasureMode]); quelli nascosti restano come sono.
  MeasureMode? get _mode => widget.item.measure;
  late final List<String> _units = _mode.isLoose
      ? [
          for (final u in widget.units)
            if (weightUnits.contains(u)) u,
        ]
      : widget.units;
  late String _unit = _units.contains(widget.item.unit)
      ? widget.item.unit!
      : (_units.contains('g') || _units.isEmpty ? 'g' : _units.first);
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
    final amount = _mode.asksWeight ? _parseAmount(_amount.text) : widget.item.amount;
    if (amount != null && amount.isNaN) {
      setState(() => _amountError = context.l10n.invalidNumber);
      return;
    }
    final unit = _mode.asksWeight ? _unit : widget.item.unit;
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
    final qty = _mode.asksQuantity ? _quantity.text.trim() : (widget.item.quantity ?? '');
    Navigator.pop(
      context,
      _ItemEdit(
        name: name,
        quantity: qty.isEmpty ? null : qty,
        amount: amount,
        unit: amount == null ? null : unit,
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
            if (_mode.asksQuantity)
              TextField(
                controller: _quantity,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: _mode == MeasureMode.count ? l.packagesOptional : l.quantityOptional,
                ),
              ),
            if (!_mode.asksWeight && widget.item.amount != null && widget.item.unit != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  l.packageSize('${formatAmount(widget.item.amount!)} ${widget.item.unit}'),
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
              ),
            if (_mode.asksWeight)
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _amount,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: _mode.isLoose ? l.weightOnlyOptional : l.weightOptional,
                        errorText: _amountError,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  _UnitPicker(units: _units, value: _unit, onChanged: (u) => setState(() => _unit = u)),
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

/// Conferma di "Spesa finita"; [text] è il messaggio facoltativo per gli altri.
class _FinishResult {
  const _FinishResult(this.text);

  final String? text;
}

/// Foglio di conferma: quanti prodotti sono stati presi, quali restano da prendere e un messaggio per gli altri.
class _FinishSheet extends StatefulWidget {
  const _FinishSheet({required this.items, required this.hasOthers});

  final List<ListItem> items;
  final bool hasOthers;

  @override
  State<_FinishSheet> createState() => _FinishSheetState();
}

class _FinishSheetState extends State<_FinishSheet> {
  final _message = TextEditingController();

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final missing = widget.items.where((i) => !i.checked).toList();
    final taken = widget.items.length - missing.length;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l.finishQuestion, style: theme.textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(
                [
                  missing.isEmpty ? l.finishAllTaken : l.finishTakenOf(taken, widget.items.length),
                  if (missing.isNotEmpty) l.finishStillToBuy,
                ].join(' '),
              ),
              if (missing.isNotEmpty)
                Card(
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  child: Column(
                    children: [
                      for (final item in missing.take(8))
                        ListTile(
                          dense: true,
                          leading: Text(item.icon, style: const TextStyle(fontSize: 20)),
                          title: Text(item.name),
                          trailing: item.measureLabel == null ? null : Text(item.measureLabel!),
                        ),
                      if (missing.length > 8)
                        ListTile(dense: true, title: Text('+ ${missing.length - 8}', textAlign: TextAlign.center)),
                    ],
                  ),
                ),
              if (widget.hasOthers) ...[
                Text(l.finishNotifyOthers, style: theme.textTheme.bodySmall),
                const SizedBox(height: 16),
                TextField(
                  controller: _message,
                  maxLength: 500,
                  minLines: 1,
                  maxLines: 3,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: l.finishMessageLabel,
                    hintText: l.finishMessageHint,
                    helperText: l.finishMessageInfo,
                    helperMaxLines: 2,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(onPressed: () => Navigator.pop(context), child: Text(l.cancel)),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: () {
                      final text = _message.text.trim();
                      Navigator.pop(context, _FinishResult(text.isEmpty ? null : text));
                    },
                    icon: const Icon(Icons.check),
                    label: Text(missing.isEmpty ? l.finishShoppingComplete : l.finishShopping),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Per chi non faceva la spesa: chi l'ha finita, quando, cosa manca e il suo messaggio, con "Continuo io".
class _FinishedBanner extends StatelessWidget {
  const _FinishedBanner({
    required this.name,
    required this.at,
    required this.missing,
    required this.message,
    required this.onTakeOver,
    required this.onDismiss,
  });

  final String name;
  final DateTime at;
  final int missing;
  final String? message;
  final VoidCallback? onTakeOver;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final material = MaterialLocalizations.of(context);
    final now = DateTime.now();
    final time = material.formatTimeOfDay(TimeOfDay.fromDateTime(at));
    final when = DateUtils.isSameDay(at, now) ? time : '${material.formatShortMonthDay(at)} $time';
    final onBanner = scheme.onSecondaryContainer;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Card(
        color: scheme.secondaryContainer,
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  UserAvatar(initials: name.isEmpty ? '?' : name[0].toUpperCase()),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l.shoppingFinishedBy(name, when),
                          style: theme.textTheme.titleSmall?.copyWith(color: onBanner),
                        ),
                        Text(
                          l.shoppingFinishedMissing(missing),
                          style: theme.textTheme.bodySmall?.copyWith(color: onBanner),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (message != null) ...[
                const SizedBox(height: 8),
                Text(
                  '«$message»',
                  style: theme.textTheme.bodyMedium?.copyWith(color: onBanner, fontStyle: FontStyle.italic),
                ),
              ],
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    style: TextButton.styleFrom(foregroundColor: onBanner),
                    onPressed: onDismiss,
                    child: Text(l.dismissFinished),
                  ),
                  if (onTakeOver != null) ...[
                    const SizedBox(width: 4),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: scheme.secondary,
                        foregroundColor: scheme.onSecondary,
                      ),
                      onPressed: onTakeOver,
                      child: Text(l.takeOver),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
