import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/list_item.dart';
import '../models/product_suggestion.dart';
import '../models/shopping_list.dart';
import '../services/api_client.dart';
import '../services/realtime_client.dart';

/// Stato di una singola lista aperta: articoli sincronizzati in tempo reale
/// e utenti che la stanno guardando (canale presence).
class ListDetailController extends ChangeNotifier {
  ListDetailController({required this.api, required this.realtime, required this.listId, required this.userId})
    : _channel = 'presence-list.$listId',
      _userChannel = 'private-App.Models.User.$userId';

  final ApiClient api;
  final RealtimeClient realtime;
  final int listId;
  final int userId;
  final String _channel;
  final String _userChannel;
  final _subs = <StreamSubscription<dynamic>>[];

  ShoppingList? list;
  final Map<int, ListItem> _items = {};
  List<PresenceMember> viewers = [];

  /// Chi sta scrivendo nella chat in questo momento (id → scadenza: sparisce se non arrivano altri avvisi).
  final Map<int, Timer> _typing = {};

  /// Nomi di chi sta scrivendo nella chat (tra chi sta guardando la lista).
  List<String> get typingNames => [
    for (final v in viewers)
      if (v.id != userId && _typing.containsKey(v.id)) v.name,
  ];

  /// Prodotti da suggerire mentre si scrive (già usati, poi i più comuni).
  List<ProductSuggestion> suggestions = [];
  bool loading = true;
  String? error;

  /// La lista è stata eliminata o non è più accessibile.
  bool gone = false;
  bool _disposed = false;

  /// Tutti gli articoli (l'ordine per reparto lo decide groupByCategory).
  List<ListItem> get items {
    final all = _items.values.toList()
      ..sort((a, b) {
        if (a.checked != b.checked) return a.checked ? 1 : -1;
        final byPosition = a.position.compareTo(b.position);
        return byPosition != 0 ? byPosition : a.id.compareTo(b.id);
      });
    return all;
  }

  int get checkedCount => _items.values.where((i) => i.checked).length;

  int get missingCount => _items.values.where((i) => i.missing).length;

  bool get canEdit => list?.canEdit ?? false;

  /// L'utente può abbandonare la lista se gli è stata condivisa singolarmente.
  bool get canLeave => list != null && !list!.isOwner && list!.sharedWith.any((u) => u.id == userId);

  void start() {
    realtime
      ..subscribe(_channel)
      ..subscribe(_userChannel);
    _subs
      ..add(realtime.on(_channel).listen(_onEvent))
      // Permessi o condivisioni cambiati (anche globali, senza list_id): se l'accesso è revocato, load() imposta gone.
      ..add(
        realtime
            .on(_userChannel)
            .where((e) => e.event == 'lists.changed' && (e.data['list_id'] == null || e.data['list_id'] == listId))
            .listen((_) => load(silent: true)),
      )
      ..add(realtime.reconnected.listen((_) => load(silent: true)));
    load();
    _loadSuggestions();
  }

  Future<void> _loadSuggestions() async {
    try {
      suggestions = await api.productSuggestions();
      _notify();
    } catch (e) {
      // Senza suggerimenti si scrive comunque.
      debugPrint('Suggerimenti non disponibili: $e');
    }
  }

  Future<void> load({bool silent = false}) async {
    if (!silent) {
      loading = true;
      _notify();
    }
    try {
      final fresh = await api.list(listId);
      list = fresh;
      _items
        ..clear()
        ..addEntries(fresh.items.map((i) => MapEntry(i.id, i)));
      error = null;
    } on ApiException catch (e) {
      if (e.isNotFoundOrForbidden) {
        gone = true;
      } else {
        error = e.message;
      }
    } finally {
      loading = false;
      _notify();
    }
  }

  void _onEvent(RealtimeEvent e) {
    switch (e.event) {
      case 'item.saved':
        final item = ListItem.fromJson(e.data['item'] as Map<String, dynamic>);
        _items[item.id] = item;
      case 'item.deleted':
        for (final id in (e.data['ids'] as List<dynamic>? ?? [])) {
          _items.remove(id);
        }
      case 'list.updated':
        list = list?.withMeta(e.data['list'] as Map<String, dynamic>);
      case 'list.deleted':
        gone = true;
      case RealtimeClient.presenceChanged:
        viewers = realtime.members(_channel);
      case 'client-typing':
        final user = e.data['user_id'];
        if (user is! int || user == userId) return;
        _typing.remove(user)?.cancel();
        if (e.data['typing'] == true) {
          // Senza nuovi avvisi entro 6 secondi (app chiusa, connessione persa) il nome sparisce.
          _typing[user] = Timer(const Duration(seconds: 6), () {
            _typing.remove(user);
            _notify();
          });
        }
      case 'message.created':
        // Messaggio inviato: chi l'ha scritto ha finito di scrivere.
        final author = (e.data['message'] as Map<String, dynamic>?)?['user'] as Map<String, dynamic>?;
        final removed = _typing.remove(author?['id']);
        if (removed == null) return;
        removed.cancel();
      default:
        return;
    }
    _notify();
  }

  // ── Azioni (ottimistiche: l'interfaccia si aggiorna subito) ─────

  /// [imagePath]: foto del prodotto scelta prima di aggiungerlo, caricata subito dopo.
  Future<void> addItem(String name, {String? quantity, double? amount, String? unit, String? imagePath}) async {
    final item = await api.addItem(listId, name, quantity: quantity, amount: amount, unit: unit);
    _items[item.id] = item;
    // Il prodotto appena usato diventa un suggerimento (in cima tra quelli con lo stesso inizio).
    final key = normalizeProductName(name);
    final previous = suggestions.where((s) => normalizeProductName(s.name) == key).firstOrNull;
    suggestions = [
      ProductSuggestion(name: item.name, icon: item.icon, category: item.category, times: (previous?.times ?? 0) + 1),
      ...suggestions.where((s) => s != previous),
    ];
    _notify();
    if (imagePath != null) await setItemImage(item, imagePath);
  }

  /// Foto del prodotto dalla galleria o dalla fotocamera.
  Future<void> setItemImage(ListItem item, String filePath) async {
    final saved = await api.uploadItemImage(listId, item.id, filePath);
    _items[saved.id] = saved;
    _notify();
  }

  Future<void> removeItemImage(ListItem item) async {
    final saved = await api.deleteItemImage(listId, item.id);
    _items[saved.id] = saved;
    _notify();
  }

  /// Preso ✓ / non preso ✗: toccando di nuovo lo stesso stato si torna a "da prendere".
  Future<void> setStatus(ListItem item, ItemStatus status) async {
    final next = item.status == status ? ItemStatus.todo : status;
    _items[item.id] = item.copyWith(status: next);
    _notify();
    try {
      final saved = await api.updateItem(listId, item.id, {'status': next.value});
      _items[saved.id] = saved;
    } catch (_) {
      _items[item.id] = item;
      rethrow;
    } finally {
      _notify();
    }
  }

  /// [category] solo se l'utente ha scelto a mano un reparto diverso; altrimenti lo riconosce il server dal nome.
  Future<void> editItem(
    ListItem item, {
    required String name,
    String? quantity,
    double? amount,
    String? unit,
    String? category,
    String? customIcon,
    String? imageUrl,
  }) async {
    final saved = await api.updateItem(listId, item.id, {
      'name': name,
      'quantity': quantity,
      'amount': amount,
      'unit': amount == null ? null : unit,
      'category': ?category,
      'custom_icon': customIcon,
      'image_url': imageUrl,
    });
    _items[saved.id] = saved;
    _notify();
  }

  Future<void> deleteItem(ListItem item) async {
    _items.remove(item.id);
    _notify();
    try {
      await api.deleteItem(listId, item.id);
    } catch (_) {
      _items[item.id] = item;
      _notify();
      rethrow;
    }
  }

  /// Foto della lista (dalla galleria o dalla fotocamera): la versione nuova arriva con la risposta.
  Future<void> setImage(String filePath) async {
    final updated = await api.uploadListImage(listId, filePath);
    list = list?.withMeta({'name': updated.name, 'notes': updated.notes, 'image_version': updated.imageVersion});
    _notify();
  }

  Future<void> removeImage() async {
    await api.deleteListImage(listId);
    list = list?.withMeta({'name': list!.name, 'notes': list!.notes, 'image_version': null});
    _notify();
  }

  Future<void> clearChecked() async {
    await api.clearChecked(listId);
    _items.removeWhere((_, i) => i.checked);
    _notify();
  }

  Future<void> leave() => api.removeShare(listId, userId);

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    for (final t in _typing.values) {
      t.cancel();
    }
    _disposed = true;
    for (final s in _subs) {
      s.cancel();
    }
    realtime
      ..unsubscribe(_channel)
      ..unsubscribe(_userChannel);
    super.dispose();
  }
}
