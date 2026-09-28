import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:lista_spesa_facile/models/list_item.dart';
import 'package:lista_spesa_facile/models/shopping_list.dart';
import 'package:lista_spesa_facile/services/api_client.dart';
import 'package:lista_spesa_facile/services/list_export.dart';

void main() {
  setUpAll(() => initializeDateFormatting());

  final list = ShoppingList(
    id: 1,
    name: 'Spesa sabato',
    notes: 'Ricordati i sacchetti',
    scheduledAt: DateTime(2026, 9, 26, 10, 30),
    permission: 'owner',
  );
  final items = [
    const ListItem(id: 1, listId: 1, name: 'Mele', category: 'frutta', icon: '🍎', quantity: '6'),
    const ListItem(
      id: 2,
      listId: 1,
      name: 'Latte',
      category: 'latticini',
      icon: '🥛',
      amount: 1,
      unit: 'l',
      status: ItemStatus.taken,
    ),
    const ListItem(id: 3, listId: 1, name: 'Burrata', category: 'latticini', icon: '🧀', status: ItemStatus.missing),
  ];
  const categories = [
    ProductCategory(slug: 'frutta', label: 'Frutta', icon: '🍎'),
    ProductCategory(slug: 'latticini', label: 'Latte, formaggi e uova', icon: '🧀'),
  ];

  test('stato dell\'articolo: da prendere, preso, non preso', () {
    ListItem parse(Map<String, dynamic> extra) =>
        ListItem.fromJson({'id': 1, 'shopping_list_id': 1, 'name': 'X', ...extra});
    expect(parse({'status': 'missing'}).missing, isTrue);
    expect(parse({'status': 'taken'}).checked, isTrue);
    // Server senza "status": si usa "checked".
    expect(parse({'checked': true}).status, ItemStatus.taken);
    expect(parse({}).status, ItemStatus.todo);
    final custom = parse({'icon': '⭐', 'custom_icon': '⭐', 'image_url': 'https://example.com/a.jpg'});
    expect(custom.customIcon, '⭐');
    expect(custom.imageUrl, 'https://example.com/a.jpg');
  });

  test('testo per WhatsApp e Telegram con spunte e reparti', () {
    final text = ListExport(list: list, items: items, categories: categories).asText(bold: true);
    expect(text, startsWith('🛒 *Spesa sabato*'));
    expect(text, contains('📅 sabato 26/09/2026 · 10:30\n📝 Ricordati i sacchetti'));
    expect(text, contains('🍎 Frutta\n⬜ 🍎 Mele (6)'));
    // Nel reparto: prima i presi, poi i non trovati.
    expect(text, contains('✅ 🥛 Latte (1 l)\n❌ 🧀 Burrata — non trovato'));
    expect(text, endsWith('1 di 3 presi · Lista Spesa Facile'));
  });

  test('PDF generato', () async {
    final bytes = await ListExport(list: list, items: items, categories: categories).buildPdf();
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    expect(bytes.length, greaterThan(1000));
  });
}
