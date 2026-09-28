class AppUser {
  const AppUser({required this.id, required this.name, required this.email, this.canEdit, this.avatarVersion});

  final int id;
  final String name;
  final String email;

  /// Presente solo nelle condivisioni: l'utente può modificare le liste condivise.
  final bool? canEdit;

  /// Versione della foto profilo (null = nessuna foto, si mostrano le iniziali): vedi ApiClient.avatarUrl.
  final String? avatarVersion;

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
    id: json['id'] as int,
    name: json['name'] as String? ?? '',
    email: json['email'] as String? ?? '',
    canEdit: json['can_edit'] as bool?,
    avatarVersion: json['avatar_version'] as String?,
  );
}
