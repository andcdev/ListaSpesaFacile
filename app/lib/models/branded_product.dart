/// Prodotto di marca trovato su Open Food Facts mentre si scrive ("latte parm" → Latte intero Parmalat, 1 L).
class BrandedProduct {
  const BrandedProduct({
    required this.barcode,
    required this.name,
    this.brand,
    this.quantity,
    this.amount,
    this.unit,
    this.imageUrl,
  });

  final String barcode;

  /// Nome con la marca, es. "Latte intero Parmalat".
  final String name;
  final String? brand;

  /// Contenuto come scritto sulla confezione, es. "1 L", "6 x 125 g".
  final String? quantity;

  /// Contenuto in un'unità dell'app (500 g, 1 l), se si è potuto leggere.
  final double? amount;
  final String? unit;
  final String? imageUrl;

  factory BrandedProduct.fromJson(Map<String, dynamic> json) => BrandedProduct(
    barcode: json['barcode'] as String,
    name: json['name'] as String,
    brand: json['brand'] as String?,
    quantity: json['quantity'] as String?,
    amount: (json['amount'] as num?)?.toDouble(),
    unit: json['unit'] as String?,
    imageUrl: json['image_url'] as String?,
  );
}
