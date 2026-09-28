import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'api_client.dart';

class RealtimeEvent {
  const RealtimeEvent(this.channel, this.event, this.data);

  final String channel;
  final String event;
  final Map<String, dynamic> data;
}

class PresenceMember {
  const PresenceMember({required this.id, required this.name});

  final int id;
  final String name;
}

/// Client WebSocket per Laravel Reverb, che parla il protocollo Pusher (v7):
/// canali privati/presence autorizzati via API, ping/pong, riconnessione automatica.
class RealtimeClient {
  RealtimeClient(this._api);

  /// Evento sintetico emesso quando cambia l'elenco dei membri di un canale presence.
  static const presenceChanged = 'presence:changed';

  /// Evento sintetico emesso quando il server rifiuta la sottoscrizione.
  static const subscriptionError = 'subscription:error';

  final ApiClient _api;
  final _events = StreamController<RealtimeEvent>.broadcast();
  final _reconnected = StreamController<void>.broadcast();

  /// Canali sottoscritti con il numero di utilizzatori (più controller possono condividere un canale).
  final _channels = <String, int>{};
  final _members = <String, Map<int, PresenceMember>>{};

  /// true quando il WebSocket è connesso e pronto.
  final connected = ValueNotifier<bool>(false);

  RealtimeConfig? _config;
  WebSocketChannel? _socket;
  StreamSubscription<dynamic>? _socketSub;
  String? _socketId;
  Timer? _pingTimer;
  Timer? _reconnectTimer;
  DateTime _lastMessage = DateTime.now();
  int _attempt = 0;
  bool _everConnected = false;

  Stream<RealtimeEvent> get events => _events.stream;

  @visibleForTesting
  Set<String> get subscribedChannels => _channels.keys.toSet();

  /// Emesso dopo una riconnessione: gli eventi persi vanno recuperati ricaricando i dati.
  Stream<void> get reconnected => _reconnected.stream;

  Stream<RealtimeEvent> on(String channel) => events.where((e) => e.channel == channel);

  List<PresenceMember> members(String channel) => List.unmodifiable(_members[channel]?.values ?? const []);

  /// Apre (o riapre) la connessione. Le iscrizioni fatte prima restano: le schermate si iscrivono ai loro canali
  /// appena compaiono, spesso prima che la configurazione del server sia arrivata.
  Future<void> connect(RealtimeConfig config) async {
    _closeSocket();
    _members.clear();
    _config = config;
    _everConnected = false;
    _open();
  }

  /// Chiude la connessione e dimentica tutte le sottoscrizioni (es. al logout).
  void disconnect() {
    _config = null;
    _channels.clear();
    _members.clear();
    _closeSocket();
  }

  /// L'app torna in primo piano (o il servizio in background fa il suo controllo periodico). Dopo una pausa
  /// Android può aver chiuso la connessione senza avvisare: se non arriva nulla da un po' la si riapre subito,
  /// invece di aspettare il controllo del ping. In ogni caso i dati vengono ricaricati ([reconnected]),
  /// perché gli eventi arrivati mentre l'app era sospesa potrebbero essere andati persi.
  void resume() {
    if (_config == null) return;
    final stale = DateTime.now().difference(_lastMessage) > const Duration(seconds: 30);
    if (!connected.value || stale) {
      // Alla nuova connessione connection_established emette reconnected.
      _everConnected = true;
      _closeSocket();
      _attempt = 0;
      _open();
    } else {
      _reconnected.add(null);
    }
  }

  void subscribe(String channel) {
    final users = _channels[channel] ?? 0;
    _channels[channel] = users + 1;
    if (users == 0 && _socketId != null) _subscribe(channel);
  }

  /// Evento "client-…" inviato direttamente agli altri membri di un canale privato/presence, senza passare
  /// dal server dell'API (es. "sta scrivendo"). Reverb li accetta solo dai membri del canale; chi lo invia
  /// non lo riceve. Ignorato se non si è connessi o non si è nel canale.
  void whisper(String channel, String event, Map<String, dynamic> data) {
    if (_socketId == null || !_channels.containsKey(channel)) return;
    _socket?.sink.add(jsonEncode({'event': 'client-$event', 'channel': channel, 'data': data}));
  }

  void unsubscribe(String channel) {
    final users = _channels[channel];
    if (users == null) return;
    if (users > 1) {
      _channels[channel] = users - 1;
      return;
    }
    _channels.remove(channel);
    _members.remove(channel);
    _send('pusher:unsubscribe', {'channel': channel});
  }

  // ── Connessione ─────────────────────────────────────────────────

  void _open() {
    final config = _config;
    if (config == null) return;

    final scheme = config.scheme == 'https' ? 'wss' : 'ws';
    final uri = Uri.parse(
      '$scheme://${config.host}:${config.port}/app/${config.key}?protocol=7&client=dart&version=1.0&flash=false',
    );

    try {
      final socket = WebSocketChannel.connect(uri);
      _socket = socket;
      _lastMessage = DateTime.now();
      _socketSub = socket.stream.listen(
        _onMessage,
        onError: (_) => _onClosed(),
        onDone: _onClosed,
        cancelOnError: true,
      );
      // Errori di connessione iniziale (host irraggiungibile) arrivano anche da ready.
      socket.ready.catchError((_) {});
    } catch (_) {
      _onClosed();
      return;
    }

    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(seconds: 25), (_) {
      if (DateTime.now().difference(_lastMessage) > const Duration(seconds: 60)) {
        // Nessuna risposta al ping: connessione morta.
        _onClosed();
      } else {
        _send('pusher:ping', {});
      }
    });
  }

  void _onClosed() {
    final wasConnected = connected.value;
    _closeSocket();
    if (_config == null) return;
    if (wasConnected) _attempt = 0;

    final delay = Duration(seconds: min(30, pow(2, _attempt).toInt()));
    _attempt++;
    _reconnectTimer = Timer(delay, _open);
  }

  void _closeSocket() {
    _pingTimer?.cancel();
    _reconnectTimer?.cancel();
    _socketSub?.cancel();
    _socket?.sink.close();
    _socket = null;
    _socketSub = null;
    _socketId = null;
    connected.value = false;
  }

  void _onMessage(dynamic raw) {
    _lastMessage = DateTime.now();
    final Map<String, dynamic> message;
    try {
      message = jsonDecode(raw as String) as Map<String, dynamic>;
    } catch (_) {
      return;
    }

    final event = message['event'] as String? ?? '';
    final channel = message['channel'] as String?;
    final data = _decodeData(message['data']);

    switch (event) {
      case 'pusher:connection_established':
        _socketId = data['socket_id'] as String?;
        _attempt = 0;
        connected.value = true;
        for (final c in _channels.keys) {
          _subscribe(c);
        }
        if (_everConnected) _reconnected.add(null);
        _everConnected = true;
      case 'pusher:ping':
        _send('pusher:pong', {});
      case 'pusher:pong':
        break;
      case 'pusher:error':
        debugPrint('Reverb error: $data');
      case 'pusher_internal:subscription_succeeded' when channel != null:
        final presence = data['presence'] as Map<String, dynamic>?;
        if (presence != null) {
          final hash = presence['hash'] as Map<String, dynamic>? ?? {};
          _members[channel] = {for (final e in hash.entries) int.parse(e.key): _member(e.key, e.value)};
          _events.add(RealtimeEvent(channel, presenceChanged, const {}));
        }
      case 'pusher_internal:member_added' when channel != null:
        final id = '${data['user_id']}';
        (_members[channel] ??= {})[int.parse(id)] = _member(id, data['user_info']);
        _events.add(RealtimeEvent(channel, presenceChanged, const {}));
      case 'pusher_internal:member_removed' when channel != null:
        _members[channel]?.remove(int.tryParse('${data['user_id']}'));
        _events.add(RealtimeEvent(channel, presenceChanged, const {}));
      default:
        if (channel != null && !event.startsWith('pusher')) {
          _events.add(RealtimeEvent(channel, event, data));
        }
    }
  }

  Future<void> _subscribe(String channel) async {
    final socketId = _socketId;
    if (socketId == null) return;

    final payload = <String, dynamic>{'channel': channel};
    if (channel.startsWith('private-') || channel.startsWith('presence-')) {
      try {
        final auth = await _api.authorizeChannel(socketId, channel);
        payload['auth'] = auth['auth'];
        if (auth['channel_data'] != null) payload['channel_data'] = auth['channel_data'];
      } catch (e) {
        _events.add(RealtimeEvent(channel, subscriptionError, {'message': '$e'}));
        return;
      }
    }
    // Nel frattempo la connessione potrebbe essere cambiata o il canale abbandonato.
    if (_socketId != socketId || !_channels.containsKey(channel)) return;
    _send('pusher:subscribe', payload);
  }

  void _send(String event, Map<String, dynamic> data) {
    if (_socketId == null && event != 'pusher:ping') return;
    _socket?.sink.add(jsonEncode({'event': event, 'data': data}));
  }

  static Map<String, dynamic> _decodeData(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is String && data.isNotEmpty) {
      try {
        final decoded = jsonDecode(data);
        if (decoded is Map<String, dynamic>) return decoded;
      } catch (_) {}
    }
    return const {};
  }

  static PresenceMember _member(String id, dynamic info) {
    final map = info is Map<String, dynamic> ? info : const <String, dynamic>{};
    return PresenceMember(id: int.parse(id), name: map['name'] as String? ?? 'Utente');
  }
}
