/// Notifica mostrata nell'elenco "Notifiche" (condivisioni, promemoria, liste eliminate…).
class AppNotification {
  const AppNotification({
    required this.id,
    required this.kind,
    required this.title,
    required this.body,
    required this.createdAt,
    this.listId,
    this.read = false,
    this.stored = true,
    this.sender,
    this.listName,
    this.messageId,
  });

  final String id;

  /// list_shared, list_created, global_share, reminder, list_deleted, chat_message, list_activity.
  final String kind;
  final String title;
  final String body;
  final int? listId;
  final bool read;
  final DateTime createdAt;

  /// false per messaggi della chat e modifiche alla lista: si mostrano sul telefono ma non nell'elenco.
  final bool stored;

  /// Chi ha scritto o modificato, e nome della lista (conversazione sul telefono, come in WhatsApp).
  final String? sender;
  final String? listName;

  /// Messaggio della chat (per confermare che il telefono l'ha ricevuto: spunte blu).
  final int? messageId;

  factory AppNotification.fromJson(Map<String, dynamic> json) => AppNotification(
    id: json['id'] as String,
    kind: json['kind'] as String? ?? '',
    title: json['title'] as String? ?? '',
    body: json['body'] as String? ?? '',
    listId: json['list_id'] as int?,
    read: json['read'] as bool? ?? false,
    createdAt: DateTime.tryParse(json['created_at'] as String? ?? '')?.toLocal() ?? DateTime.now(),
    stored: json['stored'] as bool? ?? true,
    sender: json['sender'] as String?,
    listName: json['list_name'] as String?,
    messageId: int.tryParse('${json['message_id'] ?? ''}'),
  );

  AppNotification markedRead() =>
      AppNotification(id: id, kind: kind, title: title, body: body, createdAt: createdAt, listId: listId, read: true);
}
