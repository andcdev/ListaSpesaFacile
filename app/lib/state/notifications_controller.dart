import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/app_notification.dart';
import '../services/api_client.dart';
import '../services/notification_service.dart';
import '../services/realtime_client.dart';

/// Elenco "Notifiche" e contatore delle non lette, aggiornati in tempo reale dal canale personale.
class NotificationsController extends ChangeNotifier {
  NotificationsController({required this.api, required this.realtime, required this.service, required int userId})
    : _userChannel = 'private-App.Models.User.$userId';

  final ApiClient api;
  final RealtimeClient realtime;
  final NotificationService service;
  final String _userChannel;
  final _subs = <StreamSubscription<dynamic>>[];

  List<AppNotification> items = [];
  int unreadCount = 0;
  bool loading = false;
  String? error;
  bool _disposed = false;

  void start() {
    realtime.subscribe(_userChannel);
    _subs
      ..add(realtime.on(_userChannel).where((e) => e.event == 'notification.created').listen(_onCreated))
      ..add(realtime.reconnected.listen((_) => load()));
    load();
  }

  Future<void> load() async {
    loading = true;
    _notify();
    try {
      final page = await api.notifications();
      items = page.notifications;
      unreadCount = page.unreadCount;
      error = null;
    } on ApiException catch (e) {
      error = e.message;
    } finally {
      loading = false;
      _notify();
    }
  }

  Future<void> markAllRead() async {
    if (unreadCount == 0) return;
    items = [for (final n in items) n.markedRead()];
    unreadCount = 0;
    _notify();
    unreadCount = await api.markNotificationsRead();
    _notify();
  }

  Future<void> markRead(AppNotification notification) async {
    if (notification.read) return;
    items = [for (final n in items) n.id == notification.id ? n.markedRead() : n];
    unreadCount = (unreadCount - 1).clamp(0, 1 << 30);
    _notify();
    unreadCount = await api.markNotificationsRead([notification.id]);
    _notify();
  }

  Future<void> clear() async {
    await api.clearNotifications();
    items = [];
    unreadCount = 0;
    _notify();
  }

  void _onCreated(RealtimeEvent e) {
    final notification = AppNotification.fromJson(e.data['notification'] as Map<String, dynamic>);
    // Con il push attivo, o con l'app in background e il servizio attivo, la notifica sul telefono (e la conferma
    // di ricezione) la gestisce qualcun altro: qui si aggiorna solo l'elenco.
    final elsewhere = service.handledElsewhere;
    // Chat e modifiche alla lista: solo sul telefono, nella conversazione della lista.
    if (!notification.stored) {
      if (elsewhere) return;
      service.showInApp(notification);
      // Il messaggio è arrivato su questo telefono: spunte blu per chi l'ha scritto.
      NotificationService.confirmDelivery(api, notification).catchError((Object e) => debugPrint('Conferma: $e'));
      return;
    }
    items = [notification, ...items.where((n) => n.id != notification.id)];
    unreadCount = e.data['unread_count'] as int? ?? unreadCount + 1;
    _notify();
    if (!elsewhere) service.showInApp(notification);
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    for (final s in _subs) {
      s.cancel();
    }
    realtime.unsubscribe(_userChannel);
    super.dispose();
  }
}
