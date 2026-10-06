import 'dart:async';
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

import '../l10n/l10n.dart';
import '../models/app_notification.dart';
import '../models/shopping_list.dart';
import '../state/locale_controller.dart';
import 'api_client.dart';
import 'session_storage.dart';

/// Push arrivato con l'app chiusa o in background (Android): Firebase avvia l'app in un isolate separato
/// e chiama questa funzione, che mostra la notifica e conferma la ricezione dei messaggi della chat.
@pragma('vm:entry-point')
Future<void> firebaseBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  final language = await LocaleController.loadSaved();
  final notification = NotificationService.fromPush(message);
  final service = NotificationService();
  await service.init(background: true);
  await service.showInApp(notification);
  try {
    final storage = SessionStorage();
    final token = await storage.readToken();
    if (token == null) return;
    final api = ApiClient(baseUrl: defaultServerUrl)
      ..token = token
      ..language = language;
    await NotificationService.confirmDelivery(api, notification);
  } catch (e) {
    debugPrint('Conferma di ricezione non inviata: $e');
  }
}

/// Cosa aprire quando l'utente tocca una notifica.
class NotificationTarget {
  const NotificationTarget(this.listId, {this.chat = false});

  final int listId;
  final bool chat;

  String toPayload() => '${chat ? 'chat' : 'list'}:$listId';

  static NotificationTarget? parse(String? payload) {
    final parts = (payload ?? '').split(':');
    final listId = parts.length == 2 ? int.tryParse(parts[1]) : null;
    return listId == null ? null : NotificationTarget(listId, chat: parts[0] == 'chat');
  }

  static NotificationTarget? fromPushData(Map<String, dynamic> data) {
    final listId = int.tryParse('${data['list_id'] ?? ''}');
    return listId == null ? null : NotificationTarget(listId, chat: data['kind'] == 'chat_message');
  }
}

/// Riga della conversazione di una lista sul telefono: "Anna: Sono al banco frigo", "Mario: ha preso 🥛 Latte".
class ConversationLine {
  const ConversationLine({required this.sender, required this.text, required this.at, required this.chat});

  factory ConversationLine.fromJson(Map<String, dynamic> json) => ConversationLine(
    sender: json['sender'] as String? ?? '',
    text: json['text'] as String? ?? '',
    at: DateTime.tryParse(json['at'] as String? ?? '') ?? DateTime.now(),
    chat: json['chat'] as bool? ?? false,
  );

  Map<String, dynamic> toJson() => {'sender': sender, 'text': text, 'at': at.toIso8601String(), 'chat': chat};

  final String sender;
  final String text;
  final DateTime at;

  /// Messaggio della chat (suona sempre) oppure modifica alla lista (suona solo la prima volta).
  final bool chat;

  /// Da una notifica di chat o di modifica: il nome di chi scrive diventa il mittente.
  factory ConversationLine.from(AppNotification n) {
    final sender = n.sender ?? '';
    final text = n.kind == 'list_activity' && sender.isNotEmpty && n.body.startsWith('$sender ')
        ? n.body.substring(sender.length + 1)
        : n.body;
    return ConversationLine(sender: sender, text: text, at: n.createdAt, chat: n.kind == 'chat_message');
  }
}

/// Notifiche che vanno nella conversazione della lista (come le chat di WhatsApp) invece che da sole.
bool isConversationKind(String kind) => kind == 'chat_message' || kind == 'list_activity';

/// Righe delle conversazioni salvate sul telefono: le condividono l'app aperta e il gestore dei push
/// in background (isolate diversi), per questo non si usa la cache di SharedPreferences.
class _ConversationStore {
  // Creato al primo uso: il servizio notifiche si costruisce anche dove il plugin non è ancora pronto.
  late final _prefs = SharedPreferencesAsync();

  static String _key(int listId) => 'conversation.$listId';

  Future<List<ConversationLine>> read(int listId) async {
    final raw = await _prefs.getString(_key(listId));
    if (raw == null) return [];
    try {
      return [for (final e in jsonDecode(raw) as List<dynamic>) ConversationLine.fromJson(e as Map<String, dynamic>)];
    } on FormatException {
      return [];
    }
  }

  Future<void> write(int listId, List<ConversationLine> lines) =>
      _prefs.setString(_key(listId), jsonEncode([for (final l in lines) l.toJson()]));

  Future<void> clear(int listId) => _prefs.remove(_key(listId));
}

/// Notifiche sul telefono.
///
/// - **Push** (Firebase Cloud Messaging): attive se l'app contiene google-services.json e il server
///   ha le credenziali Firebase. Arrivano anche ad app chiusa o in background: su Android il server manda
///   solo dati e la notifica la disegna l'app ([firebaseBackgroundHandler]), così chat e modifiche restano
///   raggruppate per lista come in WhatsApp. Il server invia anche i promemoria.
/// - **Senza push**: le notifiche arrivano in tempo reale solo ad app aperta e i promemoria
///   vengono programmati sul telefono come notifiche locali.
class NotificationService {
  static const _channelId = 'lista_spesa';

  /// Nome e descrizione nella lingua dell'app (Android li aggiorna se la lingua cambia).
  static AndroidNotificationChannel get _channel => AndroidNotificationChannel(
    _channelId,
    appL10n.channelName,
    description: appL10n.channelDescription,
    importance: Importance.high,
  );
  static NotificationDetails get _details => NotificationDetails(
    android: AndroidNotificationDetails(_channelId, appL10n.channelName, importance: Importance.high),
  );

  /// Gli id dei promemoria locali sono gli id delle liste; quelli delle notifiche mostrate partono da qui.
  static const _shownIdBase = 1000000000;

  /// Una notifica per lista con chat e modifiche (id = base + id della lista).
  static const _conversationIdBase = 1100000000;

  /// Righe mostrate al massimo in una conversazione.
  static const _conversationLines = 8;

  final _plugin = FlutterLocalNotificationsPlugin();

  /// Notifica toccata, letta da MainActivity: funziona anche per quelle mostrate dal servizio in background.
  static const _tapChannel = MethodChannel('listaspesafacile/notification_tap');
  final _conversations = _ConversationStore();
  bool _initialized = false;
  bool _firebaseReady = false;
  ApiClient? _api;
  String? _token;
  StreamSubscription<String>? _tokenRefresh;

  /// Notifica toccata dall'utente, in attesa che la schermata delle liste la apra (poi torna null).
  final openRequest = ValueNotifier<NotificationTarget?>(null);

  /// Lista di cui è aperta la chat: i suoi messaggi non generano notifiche.
  int? activeChatListId;

  /// Lista aperta sullo schermo: le sue modifiche si vedono già, niente notifiche.
  int? _activeListId;

  int? get activeListId => _activeListId;

  /// Lista aperta (null quando si chiude): la sua conversazione sul telefono sparisce, come aprendo una chat.
  set activeListId(int? listId) {
    _activeListId = listId;
    if (listId != null) clearConversation(listId);
  }

  /// Le notifiche push sono attive per la sessione corrente.
  bool pushActive = false;

  /// Il servizio in background (senza Firebase) è attivo: con l'app non sullo schermo le notifiche le mostra lui.
  bool backgroundServiceActive = false;

  /// L'app non è sullo schermo e c'è chi mostra le notifiche al suo posto (push o servizio in background).
  bool get handledElsewhere =>
      pushActive || (backgroundServiceActive && WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed);

  /// [background]: nel gestore dei push ad app chiusa serve solo poter mostrare le notifiche.
  Future<void> init({bool background = false}) async {
    try {
      await _plugin.initialize(
        settings: const InitializationSettings(android: AndroidInitializationSettings('@drawable/ic_notification')),
        // App aperta sullo schermo: il tocco arriva qui (e MainActivity lo scarta, per non aprirlo due volte).
        onDidReceiveNotificationResponse: background
            ? null
            : (r) {
                _tapChannel.invokeMethod<String>('take').catchError((Object _) => null);
                _open(NotificationTarget.parse(r.payload));
              },
      );
      await _plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(_channel);
      _initialized = true;
      if (!background) await openTapped();
    } catch (e) {
      debugPrint('Notifiche locali non disponibili: $e');
    }
    if (background) return;

    try {
      await Firebase.initializeApp();
      FirebaseMessaging.onBackgroundMessage(firebaseBackgroundHandler);
      FirebaseMessaging.onMessage.listen(_onForegroundPush);
      FirebaseMessaging.onMessageOpenedApp.listen((m) => _open(NotificationTarget.fromPushData(m.data)));
      final initial = await FirebaseMessaging.instance.getInitialMessage();
      if (initial != null) _open(NotificationTarget.fromPushData(initial.data));
      _firebaseReady = true;
    } catch (e) {
      debugPrint('Firebase non configurato, notifiche push disattivate: $e');
    }
  }

  /// Dopo l'accesso: chiede il permesso e registra il dispositivo per le notifiche push.
  Future<void> startSession(ApiClient api, {required bool serverPush}) async {
    _api = api;
    pushActive = false;
    try {
      if (_firebaseReady) {
        await FirebaseMessaging.instance.requestPermission();
        _token = await FirebaseMessaging.instance.getToken();
        if (_token != null) await api.registerDevice(_token!);
        await _tokenRefresh?.cancel();
        _tokenRefresh = FirebaseMessaging.instance.onTokenRefresh.listen((token) {
          _token = token;
          _api?.registerDevice(token).catchError((Object e) => debugPrint('Registrazione push: $e'));
        });
        pushActive = serverPush && _token != null;
      } else if (_initialized) {
        await _plugin
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
            ?.requestNotificationsPermission();
      }
    } catch (e) {
      debugPrint('Notifiche push non attive: $e');
    }
    // Con il push attivo i promemoria li manda il server: via quelli locali di una sessione precedente.
    if (pushActive) await _cancelReminders();
  }

  /// Al logout (prima di revocare il token API): il dispositivo non riceve più notifiche per l'utente.
  Future<void> endSession() async {
    final token = _token;
    _token = null;
    await _tokenRefresh?.cancel();
    _tokenRefresh = null;
    if (token != null) {
      try {
        await _api?.unregisterDevice(token);
      } catch (_) {
        // Il server eliminerà comunque il token quando Firebase lo segnalerà come non valido.
      }
    }
    _api = null;
    pushActive = false;
    await _cancelReminders();
  }

  /// Notifica arrivata in tempo reale con l'app aperta (usato quando il push non è attivo).
  /// Chat e modifiche finiscono nella conversazione della lista; le altre sono notifiche singole.
  Future<void> showInApp(AppNotification n) {
    final target = n.listId == null ? null : NotificationTarget(n.listId!, chat: n.kind == 'chat_message');
    if (target != null && isConversationKind(n.kind)) {
      return _showConversation(target, n.listName ?? n.title, ConversationLine.from(n));
    }
    return _show(n.id, n.title, n.body, target);
  }

  /// Toglie la conversazione della lista (aperta dall'utente).
  Future<void> clearConversation(int listId) async {
    try {
      await _conversations.clear(listId);
      if (_initialized) await _plugin.cancel(id: _conversationIdBase + listId);
    } catch (e) {
      debugPrint('Notifica non rimossa: $e');
    }
  }

  /// Push di Firebase → notifica dell'app (i dati arrivano come stringhe).
  static AppNotification fromPush(RemoteMessage message) {
    final data = message.data;
    String? text(String key) => (data[key] as String?)?.isEmpty ?? true ? null : data[key] as String;
    return AppNotification(
      id: text('id') ?? message.messageId ?? '',
      kind: text('kind') ?? '',
      title: text('title') ?? message.notification?.title ?? '',
      body: text('body') ?? message.notification?.body ?? '',
      createdAt: message.sentTime ?? DateTime.now(),
      listId: int.tryParse(text('list_id') ?? ''),
      stored: !isConversationKind(text('kind') ?? ''),
      sender: text('sender'),
      listName: text('list_name'),
      messageId: int.tryParse(text('message_id') ?? ''),
    );
  }

  /// Messaggio della chat arrivato sul telefono: chi l'ha scritto vede le due spunte blu.
  static Future<void> confirmDelivery(ApiClient api, AppNotification n) async {
    if (n.kind != 'chat_message' || n.listId == null || n.messageId == null) return;
    await api.markMessagesDelivered(n.listId!, n.messageId!);
  }

  /// Chi sta guardando la lista non riceve le sue modifiche; chi ha la chat aperta nemmeno i messaggi.
  bool _muted(NotificationTarget target, {required bool chat}) =>
      chat ? target.listId == activeChatListId : target.listId == _activeListId;

  Future<void> _showConversation(NotificationTarget target, String listName, ConversationLine line) async {
    if (!_initialized || _muted(target, chat: line.chat)) return;
    try {
      final lines = [...await _conversations.read(target.listId), line];
      if (lines.length > _conversationLines) lines.removeRange(0, lines.length - _conversationLines);
      await _conversations.write(target.listId, lines);
      await _plugin.show(
        id: _conversationIdBase + target.listId,
        title: listName,
        body: '${line.sender}: ${line.text}',
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            appL10n.channelName,
            importance: Importance.high,
            category: AndroidNotificationCategory.message,
            // Le modifiche (es. articoli spuntati uno dopo l'altro) aggiornano la notifica senza suonare ogni volta.
            onlyAlertOnce: !line.chat,
            styleInformation: MessagingStyleInformation(
              Person(name: appL10n.you),
              conversationTitle: listName,
              groupConversation: true,
              messages: [for (final l in lines) Message(l.text, l.at, Person(name: l.sender, key: l.sender))],
            ),
          ),
        ),
        payload: target.toPayload(),
      );
    } catch (e) {
      debugPrint('Notifica non mostrata: $e');
    }
  }

  /// Senza push: programma sul telefono i promemoria delle liste destinati all'utente.
  Future<void> syncReminders(List<ShoppingList> lists) async {
    if (!_initialized || pushActive) return;
    try {
      await _cancelReminders();
      final now = DateTime.now();
      for (final list in lists.where((l) => l.remindsMe)) {
        final at = list.scheduledAt.subtract(Duration(minutes: list.reminderMinutes!));
        if (!at.isAfter(now)) continue;
        await _plugin.zonedSchedule(
          id: list.id,
          scheduledDate: tz.TZDateTime.from(at.toUtc(), tz.UTC),
          notificationDetails: _details,
          // Inesatto: non serve il permesso "sveglie e promemoria"; Android può ritardarlo di qualche minuto.
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          title: appL10n.reminderTitle(list.name),
          body: appL10n.reminderBody(durationLabel(list.reminderMinutes!)),
          payload: NotificationTarget(list.id).toPayload(),
        );
      }
    } catch (e) {
      debugPrint('Promemoria locali non programmati: $e');
    }
  }

  void _onForegroundPush(RemoteMessage message) {
    final notification = fromPush(message);
    showInApp(notification);
    final api = _api;
    if (api != null) confirmDelivery(api, notification).catchError((Object e) => debugPrint('Conferma: $e'));
  }

  Future<void> _show(String id, String title, String body, NotificationTarget? target) async {
    if (!_initialized) return;
    if (target != null && target.chat && target.listId == activeChatListId) return;
    try {
      await _plugin.show(
        // Id stabile anche tra app aperta e gestore in background (isolate diversi, nessun contatore condiviso).
        id: _shownIdBase + _stableHash(id.isEmpty ? '$title$body' : id) % 1000000,
        title: title,
        body: body,
        notificationDetails: _details,
        payload: target?.toPayload(),
      );
    } catch (e) {
      debugPrint('Notifica non mostrata: $e');
    }
  }

  Future<void> _cancelReminders() async {
    if (!_initialized) return;
    try {
      for (final pending in await _plugin.pendingNotificationRequests()) {
        if (pending.id < _shownIdBase) await _plugin.cancel(id: pending.id);
      }
    } catch (e) {
      debugPrint('Promemoria locali non annullati: $e');
    }
  }

  /// FNV-1a: uguale in ogni isolate (a differenza di String.hashCode, che non è garantito).
  static int _stableHash(String value) {
    var hash = 0x811c9dc5;
    for (final unit in value.codeUnits) {
      hash = ((hash ^ unit) * 0x01000193) & 0x7fffffff;
    }
    return hash;
  }

  /// App avviata o riportata sullo schermo toccando una notifica: apre la lista o la chat giusta.
  Future<void> openTapped() async {
    try {
      _open(NotificationTarget.parse(await _tapChannel.invokeMethod<String>('take')));
    } catch (e) {
      // Piattaforma senza MainActivity (es. test): nessun effetto.
    }
  }

  void _open(NotificationTarget? target) {
    if (target == null) return;
    clearConversation(target.listId);
    openRequest.value = target;
  }
}
