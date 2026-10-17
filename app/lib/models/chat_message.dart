/// Messaggio citato in una risposta (solo l'inizio del testo).
class QuotedMessage {
  const QuotedMessage({required this.id, required this.body, this.hasImage = false, this.userName});

  final int id;
  final String body;
  final bool hasImage;
  final String? userName;

  factory QuotedMessage.fromJson(Map<String, dynamic> json) => QuotedMessage(
    id: json['id'] as int,
    body: json['body'] as String? ?? '',
    hasImage: json['has_image'] as bool? ?? false,
    userName: (json['user'] as Map<String, dynamic>?)?['name'] as String?,
  );
}

/// Messaggio della chat di una lista: testo, foto o entrambi. Con [event] è invece un evento della lista
/// (spesa finita, "Continuo io", chi fa la spesa), mostrato in grigio tra i messaggi.
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.listId,
    required this.body,
    required this.createdAt,
    this.hasImage = false,
    this.userId,
    this.userName,
    this.userAvatarVersion,
    this.replyTo,
    this.event,
    this.eventParams = const {},
  });

  final int id;
  final int listId;

  /// Vuoto per una foto senza testo.
  final String body;
  final DateTime createdAt;

  /// Foto allegata: vedi ApiClient.messageImageUrl.
  final bool hasImage;

  /// null se l'autore ha eliminato il proprio account.
  final int? userId;
  final String? userName;

  /// Foto profilo di chi ha scritto (null = nessuna).
  final String? userAvatarVersion;

  /// Messaggio a cui risponde (null se non è una risposta o se quello è stato eliminato).
  final QuotedMessage? replyTo;

  /// finished, took_over, shopper_changed (null per i messaggi normali); i dati in [eventParams].
  final String? event;
  final Map<String, dynamic> eventParams;

  bool get isEvent => event != null;

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>?;
    return ChatMessage(
      id: json['id'] as int,
      listId: json['shopping_list_id'] as int,
      body: json['body'] as String? ?? '',
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
      hasImage: json['has_image'] as bool? ?? false,
      userId: user?['id'] as int?,
      userName: user?['name'] as String?,
      userAvatarVersion: user?['avatar_version'] as String?,
      replyTo: json['reply_to'] is Map<String, dynamic>
          ? QuotedMessage.fromJson(json['reply_to'] as Map<String, dynamic>)
          : null,
      event: json['event'] as String?,
      eventParams: json['event_params'] is Map<String, dynamic>
          ? json['event_params'] as Map<String, dynamic>
          : const {},
    );
  }
}
