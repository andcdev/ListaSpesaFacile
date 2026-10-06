import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import '../l10n/l10n.dart';
import '../models/app_notification.dart';
import '../state/locale_controller.dart';
import 'api_client.dart';
import 'notification_service.dart';
import 'realtime_client.dart';
import 'session_storage.dart';

/// Notifiche con l'app chiusa o in background quando le notifiche push (Firebase) non sono configurate.
///
/// Un servizio Android in primo piano (con la sua piccola notifica fissa, come richiesto da Android) tiene aperta
/// la connessione in tempo reale con il server anche ad app chiusa e mostra sul telefono le notifiche del canale
/// personale: liste create o condivise, messaggi della chat, modifiche, promemoria, liste eliminate.
/// Mentre l'app è aperta sullo schermo le notifiche le mostra l'app stessa (NotificationsController), che sa quale
/// lista o chat stai guardando; il servizio in quel momento resta in silenzio.
abstract final class BackgroundNotifications {
  static const _foregroundKey = 'app_in_foreground';
  static const _batteryAskedKey = 'battery_optimization_asked';

  /// Da chiamare una volta all'avvio (prima di runApp).
  static void init() {
    FlutterForegroundTask.initCommunicationPort();
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'collegamento',
        channelName: appL10n.serviceChannelName,
        channelDescription: appL10n.serviceChannelDescription,
        channelImportance: NotificationChannelImportance.MIN,
        priority: NotificationPriority.MIN,
        onlyAlertOnce: true,
        showWhen: false,
      ),
      iosNotificationOptions: const IOSNotificationOptions(showNotification: false, playSound: false),
      foregroundTaskOptions: ForegroundTaskOptions(
        // Ogni minuto controlla che la connessione sia viva (e la riapre se il server non era raggiungibile).
        eventAction: ForegroundTaskEventAction.repeat(60000),
        autoRunOnBoot: true,
        autoRunOnMyPackageReplaced: true,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
  }

  /// Avvia il servizio (dopo l'accesso, con l'app aperta: Android non permette di avviarlo dal background).
  /// true se il servizio è attivo.
  static Future<bool> start() async {
    try {
      await setAppInForeground(true);
      if (await FlutterForegroundTask.isRunningService) {
        return await FlutterForegroundTask.restartService() is ServiceRequestSuccess;
      }
      // Una volta sola: senza l'esenzione dal risparmio batteria Android può chiudere il servizio di notte.
      final asked = await FlutterForegroundTask.getData<bool>(key: _batteryAskedKey) ?? false;
      if (!asked && !await FlutterForegroundTask.isIgnoringBatteryOptimizations) {
        await FlutterForegroundTask.saveData(key: _batteryAskedKey, value: true);
        await FlutterForegroundTask.requestIgnoreBatteryOptimization();
      }
      final result = await FlutterForegroundTask.startService(
        serviceId: 700,
        serviceTypes: [ForegroundServiceTypes.remoteMessaging],
        // Android vuole una notifica fissa per il servizio: solo il nome dell'app, senza altre scritte.
        notificationTitle: 'Lista Spesa Facile',
        notificationText: '',
        // Carrello bianco (vedi meta-data nel manifest): l'icona dell'app nella barra di stato sarebbe un quadrato.
        notificationIcon: const NotificationIcon(metaDataName: 'it.listaspesafacile.NOTIFICATION_ICON'),
        callback: backgroundNotificationsCallback,
      );
      if (result is ServiceRequestFailure) debugPrint('Servizio notifiche non avviato: ${result.error}');
      return result is ServiceRequestSuccess;
    } catch (e) {
      debugPrint('Servizio notifiche non disponibile: $e');
      return false;
    }
  }

  /// Al logout, o quando le notifiche push di Firebase sono attive.
  static Future<void> stop() async {
    try {
      if (await FlutterForegroundTask.isRunningService) await FlutterForegroundTask.stopService();
    } catch (e) {
      debugPrint('Servizio notifiche non fermato: $e');
    }
  }

  /// L'app è aperta sullo schermo (le notifiche le mostra lei) oppure no (le mostra il servizio).
  static Future<void> setAppInForeground(bool value) async {
    try {
      await FlutterForegroundTask.saveData(key: _foregroundKey, value: value);
    } catch (_) {
      // Piattaforma senza servizio (es. test): nessun effetto.
    }
  }

  static Future<bool> _appInForeground() async =>
      await FlutterForegroundTask.getData<bool>(key: _foregroundKey) ?? false;
}

/// Punto di ingresso del servizio (isolate separato dall'app).
@pragma('vm:entry-point')
void backgroundNotificationsCallback() => FlutterForegroundTask.setTaskHandler(_NotificationsTask());

class _NotificationsTask extends TaskHandler {
  ApiClient? _api;
  RealtimeClient? _realtime;
  StreamSubscription<RealtimeEvent>? _subscription;
  final _service = NotificationService();
  bool _connecting = false;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    // Riavviato da Android (riavvio del telefono, aggiornamento): l'app non è sullo schermo.
    if (starter == TaskStarter.system) await BackgroundNotifications.setAppInForeground(false);
    await LocaleController.loadSaved();
    await _service.init(background: true);
    await _connect();
  }

  /// Collega il servizio al canale personale dell'utente; se il server non risponde riprova al prossimo giro.
  Future<void> _connect() async {
    if (_connecting || _realtime != null) return;
    _connecting = true;
    try {
      final storage = SessionStorage();
      final token = await storage.readToken();
      if (token == null) {
        // Nessun utente collegato: il servizio non serve.
        await FlutterForegroundTask.stopService();
        return;
      }
      final api = ApiClient(baseUrl: defaultServerUrl)
        ..token = token
        ..language = currentLanguage;
      final user = await api.me();
      final config = await api.serverConfig();
      final realtime = RealtimeClient(api);
      await realtime.connect(config.realtime);
      final channel = 'private-App.Models.User.${user.id}';
      realtime.subscribe(channel);
      _subscription = realtime.on(channel).where((e) => e.event == 'notification.created').listen(_onNotification);
      _api = api;
      _realtime = realtime;
    } catch (e) {
      debugPrint('Servizio notifiche non collegato: $e');
    } finally {
      _connecting = false;
    }
  }

  Future<void> _onNotification(RealtimeEvent event) async {
    try {
      // App aperta sullo schermo: la notifica la mostra l'app (sa quale lista o chat stai guardando).
      if (await BackgroundNotifications._appInForeground()) return;
      final notification = AppNotification.fromJson(event.data['notification'] as Map<String, dynamic>);
      await _service.showInApp(notification);
      final api = _api;
      // Messaggio arrivato su questo telefono: spunte blu per chi l'ha scritto.
      if (api != null) await NotificationService.confirmDelivery(api, notification);
    } catch (e) {
      debugPrint('Notifica in background non mostrata: $e');
    }
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    final realtime = _realtime;
    if (realtime == null) {
      _connect();
    } else {
      realtime.resume();
    }
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    await _subscription?.cancel();
    _realtime?.disconnect();
  }
}
