import 'dart:io';
import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/l10n.dart';
import '../models/list_item.dart';
import '../models/shopping_list.dart';
import '../widgets/ui.dart';
import 'api_client.dart';

/// Esportazione di una lista: testo per WhatsApp / Telegram / altre app, oppure PDF.
class ListExport {
  ListExport({required this.list, required this.items, required this.categories});

  final ShoppingList list;
  final List<ListItem> items;

  /// Reparti nell'ordine del giro al supermercato.
  final List<ProductCategory> categories;

  List<ItemGroup> get _groups => groupByCategory(items, categories.map((c) => c.slug).toList());

  ProductCategory _category(String slug) => categories.firstWhere(
    (c) => c.slug == slug,
    orElse: () => ProductCategory(slug: slug, label: slug, icon: '🛒'),
  );

  /// Testi nella lingua dell'app.
  AppLocalizations get _l => appL10n;

  /// Data per esteso (un file esportato non deve dire "domani"): es. "sabato 26/09/2026 · 10:30".
  String get _when {
    final d = list.scheduledAt;
    final language = _l.localeName;
    return '${DateFormat.EEEE(language).format(d)} ${DateFormat(_l.numericDatePattern, language).format(d)} · '
        '${timeLabel(d)}';
  }

  static String _mark(ListItem item) => switch (item.status) {
    ItemStatus.todo => '⬜',
    ItemStatus.taken => '✅',
    ItemStatus.missing => '❌',
  };

  /// Testo della lista. Con [bold] il titolo è in grassetto alla WhatsApp (*titolo*).
  String asText({bool bold = false}) {
    final b = StringBuffer()
      ..writeln(bold ? '🛒 *${list.name}*' : '🛒 ${list.name}')
      ..writeln('📅 $_when');
    if (list.notes != null && list.notes!.isNotEmpty) b.writeln('📝 ${list.notes}');
    for (final group in _groups) {
      final category = _category(group.category);
      b
        ..writeln()
        ..writeln('${category.icon} ${category.label}');
      for (final item in group.items) {
        final measure = item.measureLabel;
        b.writeln(
          '${_mark(item)} ${item.icon} ${item.name}'
          '${measure == null ? '' : ' ($measure)'}'
          '${item.missing ? ' — ${_l.exportNotFound}' : ''}',
        );
      }
    }
    final taken = items.where((i) => i.checked).length;
    b
      ..writeln()
      ..write('${_l.exportTaken(taken, items.length)} · Lista Spesa Facile');
    return b.toString();
  }

  /// Apre WhatsApp con il testo pronto (sceglie l'utente la chat a cui mandarlo).
  Future<bool> toWhatsApp() => _openFirst([
    Uri.parse('whatsapp://send?text=${Uri.encodeComponent(asText(bold: true))}'),
    Uri.parse('https://wa.me/?text=${Uri.encodeComponent(asText(bold: true))}'),
  ]);

  Future<bool> toTelegram() {
    final text = Uri.encodeComponent(asText());
    return _openFirst([
      Uri.parse('tg://msg?text=$text'),
      Uri.parse('https://t.me/share/url?url=${Uri.encodeComponent(list.name)}&text=$text'),
    ]);
  }

  /// Scelta dell'app dal menu di condivisione di Android.
  Future<void> toOtherApps() => SharePlus.instance.share(ShareParams(text: asText(), subject: list.name));

  /// Crea il PDF e apre il menu di condivisione (WhatsApp, Telegram, email, Drive, stampa…).
  Future<void> sharePdf({Uint8List? image}) async {
    final bytes = await buildPdf(image: image);
    final dir = await getTemporaryDirectory();
    final safeName = list.name.replaceAll(RegExp(r'[^\w\- ]+'), '').trim();
    final file = File('${dir.path}/${safeName.isEmpty ? 'lista' : safeName}.pdf');
    await file.writeAsBytes(bytes);
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'application/pdf')],
        subject: list.name,
        title: list.name,
      ),
    );
  }

  /// PDF A4: foto (se c'è), data, note e articoli per reparto con casella preso / non preso.
  Future<Uint8List> buildPdf({Uint8List? image}) async {
    final green = PdfColor.fromHex('#2E7D32');
    final doc = pw.Document(title: list.name, author: 'Lista Spesa Facile');
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        footer: (context) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'Lista Spesa Facile · ${_latin(_l.pdfPage(context.pageNumber, context.pagesCount))}',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
          ),
        ),
        build: (context) => [
          pw.Text(
            _latin(list.name),
            style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: green),
          ),
          pw.SizedBox(height: 4),
          pw.Text(_latin(_when)),
          if (list.notes != null && list.notes!.isNotEmpty) ...[
            pw.SizedBox(height: 4),
            pw.Text(_latin(list.notes!), style: const pw.TextStyle(color: PdfColors.grey700)),
          ],
          if (image != null) ...[
            pw.SizedBox(height: 12),
            pw.ClipRRect(
              horizontalRadius: 8,
              verticalRadius: 8,
              child: pw.Image(pw.MemoryImage(image), height: 180, fit: pw.BoxFit.cover),
            ),
          ],
          for (final group in _groups) ...[
            pw.SizedBox(height: 16),
            pw.Text(
              _latin(_category(group.category).label).toUpperCase(),
              style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: green),
            ),
            pw.Divider(color: green, thickness: 0.8),
            for (final item in group.items) _pdfRow(item),
          ],
          pw.SizedBox(height: 20),
          pw.Text(
            _latin(
              _l.pdfSummary(
                items.where((i) => i.checked).length,
                items.where((i) => i.missing).length,
                items.where((i) => i.status == ItemStatus.todo).length,
              ),
            ),
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
          ),
        ],
      ),
    );
    return doc.save();
  }

  pw.Widget _pdfRow(ListItem item) {
    final color = switch (item.status) {
      ItemStatus.todo => PdfColors.white,
      ItemStatus.taken => PdfColor.fromHex('#2E7D32'),
      ItemStatus.missing => PdfColor.fromHex('#C62828'),
    };
    final measure = item.measureLabel;
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Row(
        children: [
          // Casella: vuota = da prendere, verde con ✓ = preso, rossa con X = non preso.
          pw.Container(
            width: 11,
            height: 11,
            alignment: pw.Alignment.center,
            decoration: pw.BoxDecoration(
              color: color,
              border: pw.Border.all(color: item.status == ItemStatus.todo ? PdfColors.grey700 : color),
              borderRadius: pw.BorderRadius.circular(2),
            ),
            child: switch (item.status) {
              ItemStatus.todo => null,
              ItemStatus.taken => pw.Text('v', style: const pw.TextStyle(color: PdfColors.white, fontSize: 8)),
              ItemStatus.missing => pw.Text('x', style: const pw.TextStyle(color: PdfColors.white, fontSize: 8)),
            },
          ),
          pw.SizedBox(width: 8),
          pw.Expanded(
            child: pw.Text(
              _latin(item.name),
              style: pw.TextStyle(
                decoration: item.status == ItemStatus.todo ? null : pw.TextDecoration.lineThrough,
                color: item.status == ItemStatus.todo ? PdfColors.black : PdfColors.grey600,
              ),
            ),
          ),
          if (item.missing)
            pw.Text(
              '${_latin(_l.exportNotFound)}  ',
              style: pw.TextStyle(fontSize: 9, color: PdfColor.fromHex('#C62828')),
            ),
          if (measure != null) pw.Text(_latin(measure), style: const pw.TextStyle(color: PdfColors.grey700)),
        ],
      ),
    );
  }

  /// I font standard del PDF coprono solo l'alfabeto latino: le emoji vengono tolte.
  static String _latin(String text) =>
      String.fromCharCodes(text.runes.where((r) => r < 0x250 || (r >= 0x2000 && r <= 0x206F))).trim();

  static Future<bool> _openFirst(List<Uri> uris) async {
    for (final uri in uris) {
      try {
        if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return true;
      } catch (_) {
        // App non installata: si prova il prossimo indirizzo.
      }
    }
    return false;
  }
}
