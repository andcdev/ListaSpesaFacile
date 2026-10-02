import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/shopping_list.dart';
import '../services/api_client.dart';
import '../services/notification_service.dart';
import '../services/realtime_client.dart';

/// Elenco delle liste dell'utente, aggiornato in tempo reale dal canale personale.
class ListsController extends ChangeNotifier {
  ListsController({required this.api, required this.realtime, required int userId, this.notifications})
    : _userChannel = 'private-App.Models.User.$userId';

  final ApiClient api;
  final RealtimeClient realtime;

  /// Per programmare i promemoria sul telefono quando le notifiche push non sono attive.
  final NotificationService? notifications;
  final String _userChannel;
  final _subs = <StreamSubscription<dynamic>>[];
  Timer? _debounce;

  List<ShoppingList> lists = [];
  bool loading = false;
  String? error;

  /// L'elenco è arrivato dal server almeno una volta (prima, "nessuna lista" non vuol dire niente).
  bool loaded = false;

  void start() {
    realtime.subscribe(_userChannel);
    _subs
      ..add(realtime.on(_userChannel).where((e) => e.event == 'lists.changed').listen((_) => _scheduleReload()))
      ..add(realtime.reconnected.listen((_) => _scheduleReload()));
    load();
  }

  /// Liste da oggi in poi, dalla più vicina.
  List<ShoppingList> get upcoming {
    final today = _startOfToday();
    return lists.where((l) => !l.scheduledAt.isBefore(today)).toList();
  }

  /// Liste passate, dalla più recente.
  List<ShoppingList> get past {
    final today = _startOfToday();
    return lists.where((l) => l.scheduledAt.isBefore(today)).toList().reversed.toList();
  }

  Future<void> load() async {
    loading = true;
    notifyListeners();
    try {
      lists = await api.lists();
      loaded = true;
      error = null;
      await notifications?.syncReminders(lists);
    } on ApiException catch (e) {
      error = e.message;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<ShoppingList> create({
    required String name,
    required DateTime scheduledAt,
    String? notes,
    String? supermarket,
    int? reminderMinutes,
    ReminderTarget reminderTarget = ReminderTarget.all,
    bool membersCanRename = false,
    List<ShareRequest> shares = const [],
  }) async {
    final list = await api.createList(
      name: name,
      scheduledAt: scheduledAt,
      notes: notes,
      supermarket: supermarket,
      reminderMinutes: reminderMinutes,
      reminderTarget: reminderTarget,
      membersCanRename: membersCanRename,
      shares: shares,
    );
    await load();
    return list;
  }

  Future<void> update(
    int id, {
    required String name,
    required DateTime scheduledAt,
    String? notes,
    String? supermarket,
    int? reminderMinutes,
    ReminderTarget reminderTarget = ReminderTarget.all,
    bool? membersCanRename,
  }) async {
    await api.updateList(
      id,
      name: name,
      scheduledAt: scheduledAt,
      notes: notes,
      supermarket: supermarket,
      reminderMinutes: reminderMinutes,
      reminderTarget: reminderTarget,
      membersCanRename: membersCanRename,
    );
    await load();
  }

  Future<void> delete(int id) async {
    await api.deleteList(id);
    lists = lists.where((l) => l.id != id).toList();
    notifyListeners();
  }

  void _scheduleReload() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), load);
  }

  static DateTime _startOfToday() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    for (final s in _subs) {
      s.cancel();
    }
    realtime.unsubscribe(_userChannel);
    super.dispose();
  }
}
