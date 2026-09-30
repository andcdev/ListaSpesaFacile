/// Catena di supermercati, suggerita mentre si scrive il supermercato della lista.
class Supermarket {
  const Supermarket({required this.id, required this.name, this.description});

  final int id;
  final String name;

  /// Es. "Discount, in tutta Italia".
  final String? description;

  factory Supermarket.fromJson(Map<String, dynamic> json) =>
      Supermarket(id: json['id'] as int, name: json['name'] as String, description: json['description'] as String?);
}
