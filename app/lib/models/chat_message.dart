/// Messaggio della chat di una lista: testo, foto o entrambi.
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
    );
  }
}
