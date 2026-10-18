import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/chat_message.dart';
import '../services/api_client.dart';
import '../services/realtime_client.dart';

/// Spunte dei propri messaggi: una verde = inviato al server, due blu = letto da tutti gli altri della lista.
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

  /// Per ogni utente della lista, fino a quale messaggio ha letto (chat aperta sul suo telefono).
  final Map<int, int> _delivered = {};

  /// Messaggi nuovi degli altri arrivati in tempo reale (la schermata della lista li mostra sopra la barra).
  final _incoming = StreamController<ChatMessage>.broadcast();
  Stream<ChatMessage> get incoming => _incoming.stream;

  /// Messaggi degli altri non ancora letti, dopo l'ultimo letto con la chat aperta (lo stesso conto del server
  /// per il pallino nell'elenco delle liste; gli eventi della lista non contano).
  int get unreadCount {
    final readUpTo = _delivered[userId] ?? 0;
    return _messages.values.where((m) => m.id > readUpTo && m.userId != userId && !m.isEvent).length;
  }

  /// La chat è aperta sullo schermo: solo allora i messaggi degli altri risultano letti.
  bool _visible = false;

  set visible(bool value) {
    _visible = value;
    if (value) _acknowledge();
    _notify();
  }

  /// La propria reazione al messaggio: toccando la stessa la si toglie, un'altra la sostituisce.
  Future<void> react(ChatMessage message, String emoji) async {
    final mine = message.reactions.where((r) => r.userId == userId).firstOrNull;
    final next = mine?.emoji == emoji ? null : emoji;
    final reactions = await api.reactToMessage(listId, message.id, next);
    final current = _messages[message.id];
    if (current != null) _messages[message.id] = current.withReactions(reactions);
    _notify();
  }

  bool loading = true;
  bool loadingOlder = false;
  bool hasMore = false;
  String? error;
  bool _disposed = false;

  /// Fino a quale messaggio hanno letto tutti gli altri utenti (null se la lista non è condivisa).
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
    load();
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
      case 'message.reacted':
        final current = _messages[e.data['id']];
        if (current == null) return;
        _messages[current.id] = current.withReactions(Reaction.listFromJson(e.data['reactions']));
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

  /// Conferma al server di aver letto i messaggi degli altri (le loro spunte diventano blu): solo a chat aperta.
  void _acknowledge() {
    if (!_visible) return;
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
