import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../l10n/l10n.dart';
import '../models/app_notification.dart';
import '../models/app_user.dart';
import '../models/branded_product.dart';
import '../models/chat_message.dart';
import '../models/list_item.dart';
import '../models/product_info.dart';
import '../models/product_suggestion.dart';
import '../models/shopping_list.dart';
import '../models/supermarket.dart';
import '../models/user_price.dart';

class ApiException implements Exception {
  ApiException(this.message, {this.statusCode, this.errors = const {}});

  final String message;
  final int? statusCode;

  /// Errori di validazione per campo (risposte 422 di Laravel).
  final Map<String, List<String>> errors;

  bool get isNotFoundOrForbidden => statusCode == 403 || statusCode == 404;

  @override
  String toString() => message;
}

/// Parametri del server WebSocket restituiti da GET /api/config.
class RealtimeConfig {
  const RealtimeConfig({required this.key, required this.host, required this.port, required this.scheme});

  final String key;
  final String host;
  final int port;
  final String scheme;
}

/// Configurazione pubblica del server (GET /api/config).
/// Reparto degli articoli (GET /api/config → product_categories).
class ProductCategory {
  const ProductCategory({required this.slug, required this.label, required this.icon});

  final String slug;
  final String label;
  final String icon;

  factory ProductCategory.fromJson(Map<String, dynamic> json) =>
      ProductCategory(slug: json['slug'] as String, label: json['label'] as String, icon: json['icon'] as String);
}

class ServerConfig {
  const ServerConfig({
    required this.realtime,
    required this.socialProviders,
    this.push = false,
    this.productCategories = const [],
    this.units = const ['g', 'hg', 'kg', 'ml', 'cl', 'l'],
  });

  final RealtimeConfig realtime;

  /// Provider di login social attivi sul server: google, amazon.
  final List<String> socialProviders;

  /// Il server invia notifiche push (Firebase configurato).
  final bool push;

  /// Reparti per la scelta manuale del tipo di prodotto.
  final List<ProductCategory> productCategories;

  /// Unità di misura per peso e volume.
  final List<String> units;
}

/// Utente con cui condividere una lista appena creata.
class ShareRequest {
  const ShareRequest(this.email, {this.canEdit = true});

  final String email;
  final bool canEdit;

  Map<String, dynamic> toJson() => {'email': email, 'can_edit': canEdit};
}

/// Pagina di messaggi della chat, dal più recente.
class MessagePage {
  const MessagePage(this.messages, {required this.hasMore, this.delivered = const {}});

  final List<ChatMessage> messages;
  final bool hasMore;

  /// Per ogni utente della lista, fino a quale messaggio il suo telefono ha ricevuto (spunte).
  final Map<int, int> delivered;
}

class NotificationPage {
  const NotificationPage(this.notifications, {required this.unreadCount});

  final List<AppNotification> notifications;
  final int unreadCount;
}

class GlobalShares {
  const GlobalShares({required this.sharedWith, required this.sharedBy});

  final List<AppUser> sharedWith;
  final List<AppUser> sharedBy;
}

/// Chiave dell'app, mandata in X-App-Key con ogni richiesta e con il WebSocket: senza, il server risponde 404.
/// Si passa alla build: `--dart-define=CLIENT_KEY=…`. Vuota = header non inviato (server locale senza controllo).
const clientKey = String.fromEnvironment('CLIENT_KEY');

/// Client REST per il backend Laravel (autenticazione con token Sanctum).
class ApiClient {
  ApiClient({required this.baseUrl, http.Client? httpClient}) : _http = httpClient ?? http.Client();

  final http.Client _http;
  String baseUrl;
  String? token;

  /// Lingua dell'app (it, en, fr, de, es): il server risponde e scrive le notifiche in questa lingua.
  String language = 'it';

  /// Invocata quando il server risponde 401 (token scaduto o revocato).
  void Function()? onUnauthorized;

  static const _timeout = Duration(seconds: 15);

  // ── Autenticazione ──────────────────────────────────────────────

  Future<(String, AppUser)> login(String email, String password) async {
    final json = await _send('POST', '/login', {'email': email, 'password': password, 'device_name': _deviceName});
    return (json['token'] as String, AppUser.fromJson(json['user'] as Map<String, dynamic>));
  }

  /// [privacy]: informativa privacy accettata (obbligatoria); [newsletter]: consenso facoltativo.
  Future<(String, AppUser)> register(
    String name,
    String email,
    String password, {
    required bool privacy,
    bool newsletter = false,
  }) async {
    final json = await _send('POST', '/register', {
      'name': name,
      'email': email,
      'password': password,
      'password_confirmation': password,
      'device_name': _deviceName,
      'privacy': privacy,
      'newsletter': newsletter,
    });
    return (json['token'] as String, AppUser.fromJson(json['user'] as Map<String, dynamic>));
  }

  /// Invia all'email un codice di 6 cifre per scegliere una nuova password. Restituisce il messaggio del server.
  Future<String> forgotPassword(String email) async {
    final json = await _send('POST', '/forgot-password', {'email': email});
    return (json as Map<String, dynamic>)['message'] as String? ?? appL10n.checkYourEmail;
  }

  /// Codice ricevuto via email + nuova password → accesso (le altre sessioni vengono chiuse).
  Future<(String, AppUser)> resetPassword(String email, String code, String password) async {
    final json = await _send('POST', '/reset-password', {
      'email': email,
      'code': code,
      'password': password,
      'password_confirmation': password,
      'device_name': _deviceName,
    });
    return (json['token'] as String, AppUser.fromJson(json['user'] as Map<String, dynamic>));
  }

  /// Foto profilo di un utente (richiede [authHeaders]).
  String avatarUrl(int userId, String version) => '$_root/api/users/$userId/avatar?v=$version';

  Future<AppUser> uploadAvatar(String filePath) async {
    final request = http.MultipartRequest('POST', Uri.parse('$_root/api/me/avatar'))
      ..headers.addAll(_headers)
      ..files.add(await http.MultipartFile.fromPath('image', filePath));
    return _data(await _dispatch(request, timeout: const Duration(seconds: 60)), AppUser.fromJson);
  }

  Future<AppUser> deleteAvatar() async => _data(await _send('DELETE', '/me/avatar'), AppUser.fromJson);

  Future<AppUser> me() async => AppUser.fromJson((await _send('GET', '/me'))['data'] as Map<String, dynamic>);

  /// Consenso alla newsletter, dal menu del profilo.
  Future<AppUser> setNewsletter(bool enabled) async =>
      _data(await _send('PATCH', '/me', {'newsletter': enabled}), AppUser.fromJson);

  Future<void> logout() => _send('POST', '/logout');

  /// Elimina definitivamente l'account e tutti i suoi dati (liste, foto, chat).
  Future<void> deleteAccount() => _send('DELETE', '/me');

  Future<ServerConfig> serverConfig() async {
    final json = await _send('GET', '/config') as Map<String, dynamic>;
    final realtime = json['realtime'] as Map<String, dynamic>;
    var host = realtime['host'] as String? ?? '';
    // "localhost" nel server indica la stessa macchina dell'API (es. emulatore Android → 10.0.2.2).
    if (host.isEmpty || host == 'localhost' || host == '127.0.0.1') {
      host = Uri.parse(baseUrl).host;
    }
    return ServerConfig(
      realtime: RealtimeConfig(
        key: realtime['key'] as String? ?? '',
        host: host,
        port: realtime['port'] as int? ?? 80,
        scheme: realtime['scheme'] as String? ?? 'http',
      ),
      socialProviders: (json['social_providers'] as List<dynamic>? ?? []).cast<String>(),
      push: json['push'] as bool? ?? false,
      productCategories: (json['product_categories'] as List<dynamic>? ?? [])
          .map((e) => ProductCategory.fromJson(e as Map<String, dynamic>))
          .toList(),
      units: (json['units'] as List<dynamic>?)?.cast<String>() ?? const ['g', 'hg', 'kg', 'ml', 'cl', 'l'],
    );
  }

  Future<RealtimeConfig> realtimeConfig() async => (await serverConfig()).realtime;

  /// Pagina del server che avvia il login con [provider] (da aprire nel browser di sistema).
  Uri socialLoginUrl(String provider, {required String codeChallenge}) =>
      Uri.parse('$_root/auth/$provider/redirect').replace(queryParameters: {'code_challenge': codeChallenge});

  /// Scambia il codice monouso del login social (più il code_verifier PKCE) con un token.
  Future<(String, AppUser)> exchangeSocialCode(String code, String codeVerifier) async {
    final json = await _send('POST', '/auth/social/exchange', {
      'code': code,
      'code_verifier': codeVerifier,
      'device_name': _deviceName,
    });
    return (json['token'] as String, AppUser.fromJson(json['user'] as Map<String, dynamic>));
  }

  /// Autorizza la sottoscrizione a un canale privato/presence (protocollo Pusher).
  Future<Map<String, dynamic>> authorizeChannel(String socketId, String channel) async =>
      await _send('POST', '/broadcasting/auth', {'socket_id': socketId, 'channel_name': channel})
          as Map<String, dynamic>;

  // ── Liste ───────────────────────────────────────────────────────

  Future<List<ShoppingList>> lists() async => _list(await _send('GET', '/lists'), ShoppingList.fromJson);

  Future<ShoppingList> list(int id) async => _data(await _send('GET', '/lists/$id'), ShoppingList.fromJson);

  /// Crea una lista; [shares] la condivide subito (tutte le email devono essere di utenti registrati).
  Future<ShoppingList> createList({
    required String name,
    required DateTime scheduledAt,
    String? notes,
    String? supermarket,
    int? reminderMinutes,
    ReminderTarget reminderTarget = ReminderTarget.all,
    bool membersCanRename = false,
    List<ShareRequest> shares = const [],
  }) async => _data(
    await _send('POST', '/lists', {
      'name': name,
      'scheduled_at': scheduledAt.toUtc().toIso8601String(),
      'notes': notes,
      'supermarket': supermarket,
      'reminder_minutes': reminderMinutes,
      'reminder_target': reminderTarget.value,
      'members_can_rename': membersCanRename,
      if (shares.isNotEmpty) 'shares': shares.map((s) => s.toJson()).toList(),
    }),
    ShoppingList.fromJson,
  );

  /// [membersCanRename] solo dal proprietario (null = invariato).
  Future<ShoppingList> updateList(
    int id, {
    required String name,
    required DateTime scheduledAt,
    String? notes,
    String? supermarket,
    int? reminderMinutes,
    ReminderTarget reminderTarget = ReminderTarget.all,
    bool? membersCanRename,
  }) async => _data(
    await _send('PATCH', '/lists/$id', {
      'name': name,
      'scheduled_at': scheduledAt.toUtc().toIso8601String(),
      'notes': notes,
      'supermarket': supermarket,
      'reminder_minutes': reminderMinutes,
      'reminder_target': reminderTarget.value,
      'members_can_rename': ?membersCanRename,
    }),
    ShoppingList.fromJson,
  );

  Future<void> deleteList(int id) => _send('DELETE', '/lists/$id');

  // ── Foto della lista ────────────────────────────────────────────

  /// Indirizzo della foto (richiede [authHeaders]); la versione nell'URL aggiorna la cache quando cambia.
  String listImageUrl(int listId, String version) => '$_root/api/lists/$listId/image?v=$version';

  Future<ShoppingList> uploadListImage(int listId, String filePath) async {
    final request = http.MultipartRequest('POST', Uri.parse('$_root/api/lists/$listId/image'))
      ..headers.addAll(_headers)
      ..files.add(await http.MultipartFile.fromPath('image', filePath));
    return _data(await _dispatch(request, timeout: const Duration(seconds: 60)), ShoppingList.fromJson);
  }

  Future<ShoppingList> deleteListImage(int listId) async =>
      _data(await _send('DELETE', '/lists/$listId/image'), ShoppingList.fromJson);

  /// Byte della foto (per il PDF); null se non disponibile.
  Future<List<int>?> listImageBytes(int listId, String version) async {
    try {
      final response = await _http
          .get(Uri.parse(listImageUrl(listId, version)), headers: authHeaders)
          .timeout(_timeout);
      return response.statusCode == 200 ? response.bodyBytes : null;
    } catch (_) {
      return null;
    }
  }

  // ── Articoli ────────────────────────────────────────────────────

  /// Il server riconosce reparto e icona dal nome. [amount] e [unit] (g, kg, l…) vanno insieme.
  /// [product]: prodotto di marca scelto tra i suggerimenti (codice a barre, marca e foto).
  Future<ListItem> addItem(
    int listId,
    String name, {
    String? quantity,
    double? amount,
    String? unit,
    BrandedProduct? product,
  }) async => _data(
    await _send('POST', '/lists/$listId/items', {
      'name': name,
      'quantity': quantity,
      'amount': ?amount,
      if (amount != null) 'unit': unit,
      if (product != null) ...{'barcode': product.barcode, 'brand': product.brand, 'image_url': ?product.imageUrl},
    }),
    ListItem.fromJson,
  );

  /// Prodotti di marca che corrispondono a quanto scritto (Open Food Facts, nel paese della lingua dell'app).
  Future<List<BrandedProduct>> searchProducts(String text) async =>
      _list(await _send('GET', '/products/search?q=${Uri.encodeQueryComponent(text)}'), BrandedProduct.fromJson);

  /// Scheda del prodotto di un articolo (foto, valori nutrizionali, ingredienti, allergeni…); null se non si trova.
  Future<ProductInfo?> productInfo(int listId, int itemId) async {
    final data = (await _send('GET', '/lists/$listId/items/$itemId/info') as Map<String, dynamic>)['data'];
    return data == null ? null : ProductInfo.fromJson(data as Map<String, dynamic>);
  }

  // ── I miei prezzi (li vede solo l'utente) ───────────────────────

  Future<List<UserPrice>> myPrices({String? query}) async => _list(
    await _send('GET', '/me/prices${query == null || query.isEmpty ? '' : '?q=${Uri.encodeQueryComponent(query)}'}'),
    UserPrice.fromJson,
  );

  Future<UserPrice> addMyPrice(UserPrice price) async =>
      _data(await _send('POST', '/me/prices', price.toJson()), UserPrice.fromJson);

  Future<UserPrice> updateMyPrice(int id, UserPrice price) async =>
      _data(await _send('PATCH', '/me/prices/$id', price.toJson()), UserPrice.fromJson);

  Future<void> deleteMyPrice(int id) => _send('DELETE', '/me/prices/$id');

  Future<ListItem> updateItem(int listId, int itemId, Map<String, dynamic> changes) async =>
      _data(await _send('PATCH', '/lists/$listId/items/$itemId', changes), ListItem.fromJson);

  Future<void> deleteItem(int listId, int itemId) => _send('DELETE', '/lists/$listId/items/$itemId');

  Future<void> clearChecked(int listId) => _send('DELETE', '/lists/$listId/items/checked');

  /// Foto del prodotto caricata dal telefono (richiede [authHeaders]).
  String itemImageUrl(int listId, int itemId, String version) =>
      '$_root/api/lists/$listId/items/$itemId/image?v=$version';

  Future<ListItem> uploadItemImage(int listId, int itemId, String filePath) async {
    final request = http.MultipartRequest('POST', Uri.parse('$_root/api/lists/$listId/items/$itemId/image'))
      ..headers.addAll(_headers)
      ..files.add(await http.MultipartFile.fromPath('image', filePath));
    return _data(await _dispatch(request, timeout: const Duration(seconds: 60)), ListItem.fromJson);
  }

  Future<ListItem> deleteItemImage(int listId, int itemId) async =>
      _data(await _send('DELETE', '/lists/$listId/items/$itemId/image'), ListItem.fromJson);

  // ── Condivisione ────────────────────────────────────────────────

  Future<List<AppUser>> shares(int listId) async =>
      _list(await _send('GET', '/lists/$listId/shares'), AppUser.fromJson);

  Future<List<AppUser>> addShare(int listId, String email, {bool canEdit = true}) async =>
      _list(await _send('POST', '/lists/$listId/shares', {'email': email, 'can_edit': canEdit}), AppUser.fromJson);

  /// Cambia il permesso di chi ha già la lista (solo il proprietario).
  Future<List<AppUser>> updateShare(int listId, int userId, {required bool canEdit}) async =>
      _list(await _send('PATCH', '/lists/$listId/shares/$userId', {'can_edit': canEdit}), AppUser.fromJson);

  Future<void> removeShare(int listId, int userId) => _send('DELETE', '/lists/$listId/shares/$userId');

  Future<GlobalShares> globalShares() async => _globalShares(await _send('GET', '/global-shares'));

  Future<GlobalShares> addGlobalShare(String email, {bool canEdit = true}) async =>
      _globalShares(await _send('POST', '/global-shares', {'email': email, 'can_edit': canEdit}));

  /// Cambia il permesso su tutte le mie liste per chi le riceve già.
  Future<GlobalShares> updateGlobalShare(int userId, {required bool canEdit}) async =>
      _globalShares(await _send('PATCH', '/global-shares/$userId', {'can_edit': canEdit}));

  Future<void> removeGlobalShare(int userId) => _send('DELETE', '/global-shares/$userId');

  Future<void> leaveGlobalShare(int ownerId) => _send('DELETE', '/global-shares/received/$ownerId');

  // ── Chat ────────────────────────────────────────────────────────

  Future<MessagePage> messages(int listId, {int? before}) async {
    final json = await _send('GET', '/lists/$listId/messages${before == null ? '' : '?before=$before'}');
    final delivered = (json as Map<String, dynamic>)['delivered'];
    return MessagePage(
      _list(json, ChatMessage.fromJson),
      hasMore: json['has_more'] == true,
      delivered: {
        if (delivered is Map<String, dynamic>)
          for (final e in delivered.entries) int.parse(e.key): (e.value as num).toInt(),
      },
    );
  }

  /// Il telefono ha ricevuto i messaggi della lista fino a [upTo]: chi li ha scritti vede le spunte blu.
  Future<void> markMessagesDelivered(int listId, int upTo) =>
      _send('POST', '/lists/$listId/messages/delivered', {'up_to': upTo});

  /// Catene di supermercati note, da suggerire mentre si scrive il supermercato.
  Future<List<Supermarket>> supermarkets() async => _list(await _send('GET', '/supermarkets'), Supermarket.fromJson);

  /// Prodotti da suggerire mentre si scrive (già usati, poi i più comuni).
  Future<List<ProductSuggestion>> productSuggestions() async =>
      _list(await _send('GET', '/products/suggestions'), ProductSuggestion.fromJson);

  /// Testo, foto ([imagePath], dalla galleria o dalla fotocamera) o entrambi.
  Future<ChatMessage> sendMessage(int listId, String body, {String? imagePath}) async {
    if (imagePath == null) {
      return _data(await _send('POST', '/lists/$listId/messages', {'body': body}), ChatMessage.fromJson);
    }
    final request = http.MultipartRequest('POST', Uri.parse('$_root/api/lists/$listId/messages'))
      ..headers.addAll(_headers)
      ..files.add(await http.MultipartFile.fromPath('image', imagePath));
    if (body.isNotEmpty) request.fields['body'] = body;
    return _data(await _dispatch(request, timeout: const Duration(seconds: 60)), ChatMessage.fromJson);
  }

  /// Foto allegata a un messaggio (richiede [authHeaders]).
  String messageImageUrl(int listId, int messageId) => '$_root/api/lists/$listId/messages/$messageId/image';

  Future<void> deleteMessage(int listId, int messageId) => _send('DELETE', '/lists/$listId/messages/$messageId');

  // ── Notifiche ───────────────────────────────────────────────────

  Future<NotificationPage> notifications() async {
    final json = await _send('GET', '/notifications');
    return NotificationPage(
      _list(json, AppNotification.fromJson),
      unreadCount: (json as Map<String, dynamic>)['unread_count'] as int? ?? 0,
    );
  }

  /// Segna come lette le notifiche indicate, o tutte se [ids] è null. Restituisce le non lette rimaste.
  Future<int> markNotificationsRead([List<String>? ids]) async {
    final json = await _send('POST', '/notifications/read', {'ids': ?ids});
    return (json as Map<String, dynamic>)['unread_count'] as int? ?? 0;
  }

  Future<void> clearNotifications() => _send('DELETE', '/notifications');

  /// Registra il token Firebase del dispositivo per ricevere le notifiche push.
  Future<void> registerDevice(String token) =>
      _send('POST', '/devices', {'token': token, 'platform': Platform.operatingSystem});

  Future<void> unregisterDevice(String token) => _send('DELETE', '/devices', {'token': token});

  // ── Helpers ─────────────────────────────────────────────────────

  String get _root => baseUrl.replaceAll(RegExp(r'/+$'), '');

  String get _deviceName => 'app-${Platform.operatingSystem}';

  T _data<T>(dynamic json, T Function(Map<String, dynamic>) parse) =>
      parse((json as Map<String, dynamic>)['data'] as Map<String, dynamic>);

  List<T> _list<T>(dynamic json, T Function(Map<String, dynamic>) parse) =>
      ((json as Map<String, dynamic>)['data'] as List<dynamic>).map((e) => parse(e as Map<String, dynamic>)).toList();

  GlobalShares _globalShares(dynamic json) {
    List<AppUser> users(String key) => ((json as Map<String, dynamic>)[key] as List<dynamic>)
        .map((e) => AppUser.fromJson(e as Map<String, dynamic>))
        .toList();
    return GlobalShares(sharedWith: users('shared_with'), sharedBy: users('shared_by'));
  }

  /// Header che fanno riconoscere l'app al server (X-App-Key), anche all'apertura del WebSocket.
  static Map<String, String> get clientHeaders => {if (clientKey.isNotEmpty) 'X-App-Key': clientKey};

  /// Header di autenticazione, per caricare le immagini protette (es. Image.network).
  Map<String, String> get authHeaders => {...clientHeaders, if (token != null) 'Authorization': 'Bearer $token'};

  Map<String, String> get _headers => {'Accept': 'application/json', 'Accept-Language': language, ...authHeaders};

  Future<dynamic> _send(String method, String path, [Map<String, dynamic>? body]) async {
    final request = http.Request(method, Uri.parse('$_root/api$path'))
      ..headers.addAll({..._headers, 'Content-Type': 'application/json'});
    if (body != null) request.body = jsonEncode(body);
    return _dispatch(request);
  }

  Future<dynamic> _dispatch(http.BaseRequest request, {Duration timeout = _timeout}) async {
    final http.Response response;
    try {
      response = await http.Response.fromStream(await _http.send(request).timeout(timeout));
    } on TimeoutException {
      throw ApiException(appL10n.errTimeout);
    } on SocketException {
      throw ApiException(appL10n.errNetwork);
    } on http.ClientException {
      throw ApiException(appL10n.errNetwork);
    }

    final decoded = response.body.isEmpty ? null : _tryDecode(response.body);
    if (response.statusCode >= 200 && response.statusCode < 300) return decoded;

    if (response.statusCode == 401 && token != null) onUnauthorized?.call();

    final map = decoded is Map<String, dynamic> ? decoded : const <String, dynamic>{};
    final errors = <String, List<String>>{
      for (final e in (map['errors'] as Map<String, dynamic>? ?? {}).entries)
        e.key: (e.value as List<dynamic>).map((m) => m.toString()).toList(),
    };
    throw ApiException(
      errors.values.expand((m) => m).firstOrNull ?? _messageFor(response.statusCode, map['message'] as String?),
      statusCode: response.statusCode,
      errors: errors,
    );
  }

  static dynamic _tryDecode(String body) {
    try {
      return jsonDecode(body);
    } on FormatException {
      return null;
    }
  }

  static String _messageFor(int status, String? serverMessage) => switch (status) {
    401 => appL10n.errSessionExpired,
    403 => appL10n.errForbidden,
    404 => appL10n.errNotFound,
    429 => appL10n.errTooMany,
    >= 500 => appL10n.errServer,
    _ => serverMessage ?? appL10n.errUnexpected(status),
  };
}
