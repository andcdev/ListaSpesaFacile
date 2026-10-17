import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/chat_message.dart';
import '../services/api_client.dart';
import '../services/realtime_client.dart';

/// Spunte dei propri messaggi: una verde = inviato al server, due blu = ricevuto da tutti gli altri della lista.
enum MessageTicks { sent, received }

/// Chat di una lista: messaggi in tempo reale sul canale presence della lista.
class ChatController extends ChangeNotifier {
  ChatController({required this.api, required this.realtime, required this.listId, required this.userId})
    : _channel = 'presence-list.$listId';

  final ApiClient api;
  final RealtimeClient realtime;
  final int listId;
  final int userId;
  final String _channel;
  final _subs = <StreamSubscription<dynamic>>[];
  final Map<int, ChatMessage> _messages = {};

  /// Per ogni utente della lista, fino a quale messaggio il suo telefono ha ricevuto.
  final Map<int, int> _delivered = {};

  /// Ultimo messaggio letto (chat aperta), salvato sul telefono: quelli degli altri dopo questo sono da leggere.
  int _readUpTo = 0;
  String get _readKey => 'chat-read-$listId';

  /// Messaggi nuovi degli altri arrivati in tempo reale (la schermata della lista li mostra sopra la barra).
  final _incoming = StreamController<ChatMessage>.broadcast();
  Stream<ChatMessage> get incoming => _incoming.stream;

  /// Messaggi degli altri non ancora letti (gli eventi della lista non contano).
  int get unreadCount => _messages.values.where((m) => m.id > _readUpTo && m.userId != userId && !m.isEvent).length;

  /// La chat è aperta: tutto quello che c'è è letto.
  Future<void> markRead() async {
    final latest = _messages.keys.fold(0, (max, id) => id > max ? id : max);
    if (latest <= _readUpTo) return;
    _readUpTo = latest;
    _notify();
    try {
      (await SharedPreferences.getInstance()).setInt(_readKey, latest);
    } catch (_) {
      // Senza memoria sul telefono il contatore ricomincia alla prossima apertura.
    }
  }

  bool loading = true;
  bool loadingOlder = false;
  bool hasMore = false;
  String? error;
  bool _disposed = false;

  /// Fino a quale messaggio hanno ricevuto tutti gli altri utenti (null se la lista non è condivisa).
  int? get othersDeliveredUpTo {
    final others = _delivered.entries.where((e) => e.key != userId).map((e) => e.value);
    return others.isEmpty ? null : others.reduce((a, b) => a < b ? a : b);
  }

  MessageTicks ticks(ChatMessage message) {
    final upTo = othersDeliveredUpTo;
    return upTo != null && message.id <= upTo ? MessageTicks.received : MessageTicks.sent;
  }

  /// Dal più vecchio al più recente.
  List<ChatMessage> get messages => _messages.values.toList()..sort((a, b) => a.id.compareTo(b.id));

  void start() {
    realtime.subscribe(_channel);
    _subs
      ..add(realtime.on(_channel).listen(_onEvent))
      ..add(realtime.reconnected.listen((_) => load()));
    _loadRead().then((_) => load());
  }

  /// Mai aperta su questo telefono: i messaggi che ci sono già non contano come nuovi.
  bool _readUnknown = false;

  Future<void> _loadRead() async {
    try {
      final saved = (await SharedPreferences.getInstance()).getInt(_readKey);
      _readUpTo = saved ?? 0;
      _readUnknown = saved == null;
    } catch (_) {}
  }

  /// Carica gli ultimi messaggi (anche dopo una riconnessione, per recuperare quelli persi).
  Future<void> load() async {
    try {
      final page = await api.messages(listId);
      _messages
        ..clear()
        ..addEntries(page.messages.map((m) => MapEntry(m.id, m)));
      _delivered
        ..clear()
        ..addAll(page.delivered);
      hasMore = page.hasMore;
      error = null;
      _acknowledge();
      if (_readUnknown) {
        _readUnknown = false;
        await markRead();
      }
    } on ApiException catch (e) {
      error = e.message;
    } finally {
      loading = false;
      _notify();
    }
  }

  Future<void> loadOlder() async {
    if (!hasMore || loadingOlder || _messages.isEmpty) return;
    loadingOlder = true;
    _notify();
    try {
      final oldest = _messages.keys.reduce((a, b) => a < b ? a : b);
      final page = await api.messages(listId, before: oldest);
      _messages.addEntries(page.messages.map((m) => MapEntry(m.id, m)));
      hasMore = page.hasMore;
    } finally {
      loadingOlder = false;
      _notify();
    }
  }

  /// Testo, foto ([imagePath]) o entrambi; [replyTo] è il messaggio a cui si risponde.
  Future<void> send(String body, {String? imagePath, ChatMessage? replyTo}) async {
    final message = await api.sendMessage(listId, body, imagePath: imagePath, replyToId: replyTo?.id);
    _messages[message.id] = message;
    _delivered[userId] = message.id;
    _notify();
  }

  Future<void> delete(ChatMessage message) async {
    _messages.remove(message.id);
    _notify();
    try {
      await api.deleteMessage(listId, message.id);
    } catch (_) {
      _messages[message.id] = message;
      _notify();
      rethrow;
    }
  }

  void _onEvent(RealtimeEvent e) {
    switch (e.event) {
      case 'message.created':
        final message = ChatMessage.fromJson(e.data['message'] as Map<String, dynamic>);
        final isNew = !_messages.containsKey(message.id);
        _messages[message.id] = message;
        _acknowledge();
        if (isNew && message.userId != userId && !message.isEvent) _incoming.add(message);
      case 'message.deleted':
        _messages.remove(e.data['id']);
      case 'messages.delivered':
        final user = e.data['user_id'] as int;
        final upTo = e.data['up_to'] as int;
        if (upTo <= (_delivered[user] ?? 0)) return;
        _delivered[user] = upTo;
      default:
        return;
    }
    _notify();
  }

  /// Conferma al server di aver ricevuto i messaggi degli altri (le loro spunte diventano blu).
  void _acknowledge() {
    final latest = _messages.values.where((m) => m.userId != userId).fold(0, (max, m) => m.id > max ? m.id : max);
    if (latest <= (_delivered[userId] ?? 0)) return;
    _delivered[userId] = latest;
    api.markMessagesDelivered(listId, latest).catchError((Object e) => debugPrint('Conferma di ricezione: $e'));
  }

  /// Mentre si scrive, avvisa gli altri (al massimo ogni 3 secondi); chi riceve lo mostra per qualche secondo.
  void typing(bool active) {
    final now = DateTime.now();
    if (active && _lastTyping != null && now.difference(_lastTyping!) < const Duration(seconds: 3)) return;
    if (!active && _lastTyping == null) return;
    _lastTyping = active ? now : null;
    realtime.whisper(_channel, 'typing', {'user_id': userId, 'typing': active});
  }

  DateTime? _lastTyping;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    typing(false);
    _disposed = true;
    _incoming.close();
    for (final s in _subs) {
      s.cancel();
    }
    realtime.unsubscribe(_channel);
    super.dispose();
  }
}
