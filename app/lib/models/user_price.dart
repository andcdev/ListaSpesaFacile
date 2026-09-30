/// Prezzo che l'utente si è annotato per un prodotto: lo vede solo lui (sezione "I miei prezzi").
class UserPrice {
  const UserPrice({
    required this.id,
    required this.productName,
    required this.price,
    this.per = 'pz',
    this.barcode,
    this.brand,
    this.supermarket,
    this.note,
    this.updatedAt,
  });

  final int id;
  final String productName;
  final double price;

  /// pz (a confezione), kg o l.
  final String per;
  final String? barcode;
  final String? brand;
  final String? supermarket;
  final String? note;
  final DateTime? updatedAt;

  factory UserPrice.fromJson(Map<String, dynamic> json) => UserPrice(
    id: json['id'] as int,
    productName: json['product_name'] as String,
    price: (json['price'] as num).toDouble(),
    per: json['per'] as String? ?? 'pz',
    barcode: json['barcode'] as String?,
    brand: json['brand'] as String?,
    supermarket: json['supermarket'] as String?,
    note: json['note'] as String?,
    updatedAt: json['updated_at'] == null ? null : DateTime.parse(json['updated_at'] as String).toLocal(),
  );

  Map<String, dynamic> toJson() => {
    'product_name': productName,
    'price': price,
    'per': per,
    'barcode': barcode,
    'brand': brand,
    'supermarket': supermarket,
    'note': note,
  };
}
