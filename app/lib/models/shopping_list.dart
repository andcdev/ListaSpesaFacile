import 'app_user.dart';
import 'list_item.dart';
import 'supermarket.dart';

/// Chi riceve il promemoria di una lista.
/// Il testo da mostrare è ReminderTarget.label (l10n.dart).
enum ReminderTarget {
  owner('owner'),
  members('members'),
  all('all');

  const ReminderTarget(this.value);

  final String value;

  static ReminderTarget parse(String? value) =>
      ReminderTarget.values.firstWhere((t) => t.value == value, orElse: () => ReminderTarget.all);
}

class ShoppingList {
  const ShoppingList({
    required this.id,
    required this.name,
    required this.scheduledAt,
    required this.permission,
    this.notes,
    this.supermarket,
    this.supermarketChain,
    this.imageVersion,
    this.reminderMinutes,
    this.reminderTarget = ReminderTarget.all,
    this.membersCanRename = false,
    this.owner,
    this.itemsCount = 0,
    this.checkedCount = 0,
    this.items = const [],
    this.sharedWith = const [],
  });

  final int id;
  final String name;
  final String? notes;

  /// Supermercato dove si fa la spesa, come scritto dall'utente.
  final String? supermarket;

  /// Catena riconosciuta dal server (solo nel dettaglio): se è null la lista non mostra prezzi.
  final Supermarket? supermarketChain;

  /// Versione della foto della lista (null se non c'è): vedi ApiClient.listImageUrl.
  final String? imageVersion;

  /// Data e ora della spesa, nel fuso orario del dispositivo.
  final DateTime scheduledAt;

  /// Minuti di anticipo del promemoria, null se non c'è.
  final int? reminderMinutes;
  final ReminderTarget reminderTarget;

  /// Il proprietario consente a chi può modificare la lista di cambiarne anche il nome.
  final bool membersCanRename;

  /// owner, edit oppure view.
  final String permission;
  final AppUser? owner;
  final int itemsCount;
  final int checkedCount;
  final List<ListItem> items;
  final List<AppUser> sharedWith;

  bool get isOwner => permission == 'owner';
  bool get canEdit => permission == 'owner' || permission == 'edit';
  bool get canRename => isOwner || (permission == 'edit' && membersCanRename);

  /// Il promemoria è destinato all'utente corrente.
  bool get remindsMe =>
      reminderMinutes != null &&
      switch (reminderTarget) {
        ReminderTarget.owner => isOwner,
        ReminderTarget.members => !isOwner,
        ReminderTarget.all => true,
      };

  factory ShoppingList.fromJson(Map<String, dynamic> json) {
    final items = (json['items'] as List<dynamic>? ?? [])
        .map((e) => ListItem.fromJson(e as Map<String, dynamic>))
        .toList();
    return ShoppingList(
      id: json['id'] as int,
      name: json['name'] as String,
      notes: json['notes'] as String?,
      supermarket: json['supermarket'] as String?,
      supermarketChain: json['supermarket_chain'] == null
          ? null
          : Supermarket.fromJson(json['supermarket_chain'] as Map<String, dynamic>),
      imageVersion: json['image_version'] as String?,
      scheduledAt: DateTime.parse(json['scheduled_at'] as String).toLocal(),
      reminderMinutes: json['reminder_minutes'] as int?,
      reminderTarget: ReminderTarget.parse(json['reminder_target'] as String?),
      membersCanRename: json['members_can_rename'] as bool? ?? false,
      permission: json['permission'] as String? ?? 'view',
      owner: json['owner'] == null ? null : AppUser.fromJson(json['owner'] as Map<String, dynamic>),
      itemsCount: json['items_count'] as int? ?? items.length,
      checkedCount: json['checked_count'] as int? ?? items.where((i) => i.checked).length,
      items: items,
      sharedWith: (json['shared_with'] as List<dynamic>? ?? [])
          .map((e) => AppUser.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  /// Applica i dati ricevuti con l'evento "list.updated".
  ShoppingList withMeta(Map<String, dynamic> json) => ShoppingList(
    id: id,
    name: json['name'] as String? ?? name,
    notes: json['notes'] as String?,
    // Un supermercato diverso cambia i prezzi: il controller ricarica la lista e la catena arriva con il dettaglio.
    supermarket: json.containsKey('supermarket') ? json['supermarket'] as String? : supermarket,
    supermarketChain: !json.containsKey('supermarket') || json['supermarket'] == supermarket ? supermarketChain : null,
    imageVersion: json.containsKey('image_version') ? json['image_version'] as String? : imageVersion,
    scheduledAt: json['scheduled_at'] == null ? scheduledAt : DateTime.parse(json['scheduled_at'] as String).toLocal(),
    reminderMinutes: json.containsKey('reminder_minutes') ? json['reminder_minutes'] as int? : reminderMinutes,
    reminderTarget: json.containsKey('reminder_target')
        ? ReminderTarget.parse(json['reminder_target'] as String?)
        : reminderTarget,
    membersCanRename: json['members_can_rename'] as bool? ?? membersCanRename,
    permission: permission,
    owner: owner,
    itemsCount: itemsCount,
    checkedCount: checkedCount,
    items: items,
    sharedWith: sharedWith,
  );
}
