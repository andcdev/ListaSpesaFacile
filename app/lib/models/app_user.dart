class AppUser {
  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    this.canEdit,
    this.avatarVersion,
    this.newsletter = false,
    this.blockedIds = const {},
  });

  final int id;
  final String name;
  final String email;

  /// Presente solo nelle condivisioni: l'utente può modificare le liste condivise.
  final bool? canEdit;

  /// Versione della foto profilo (null = nessuna foto, si mostrano le iniziali): vedi ApiClient.avatarUrl.
  final String? avatarVersion;

  /// Solo per l'utente corrente: ha dato il consenso alla newsletter.
  final bool newsletter;

  /// Solo per l'utente corrente: persone che ha bloccato (i loro messaggi nella chat non compaiono).
  final Set<int> blockedIds;

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
    id: json['id'] as int,
    name: json['name'] as String? ?? '',
    email: json['email'] as String? ?? '',
    canEdit: json['can_edit'] as bool?,
    avatarVersion: json['avatar_version'] as String?,
    newsletter: json['newsletter'] as bool? ?? false,
    blockedIds: {...?(json['blocked_ids'] as List<dynamic>?)?.cast<int>()},
  );
}
