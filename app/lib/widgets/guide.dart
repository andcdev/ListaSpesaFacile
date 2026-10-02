import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/l10n.dart';

/// Un passo della guida: il comando da illuminare ([target]) e cosa spiegare.
class GuideStep {
  const GuideStep({required this.target, required this.title, required this.text});

  final GlobalKey target;
  final String title;
  final String text;
}

/// Passi della guida in tutto: "Nuova lista", poi scrivere un prodotto, il +, la condivisione.
const guideSteps = 4;

/// A che punto è la guida passo passo di un utente su questo telefono: all'inizio (elenco delle liste: "Nuova
/// lista"), poi dentro la prima lista (aggiungere prodotti), poi finita.
enum GuideStage { lists, detail, done }

class GuideProgress {
  static String _key(int userId) => 'guida.$userId';

  /// null = mai vista.
  static Future<GuideStage?> stage(int userId) async {
    try {
      final value = (await SharedPreferences.getInstance()).getString(_key(userId));
      return GuideStage.values.where((s) => s.name == value).firstOrNull;
    } catch (_) {
      return GuideStage.done;
    }
  }

  static Future<void> set(int userId, GuideStage stage) async {
    try {
      await (await SharedPreferences.getInstance()).setString(_key(userId), stage.name);
    } catch (_) {
      // Senza memoria la guida si rivedrebbe: niente di grave.
    }
  }
}

/// Mostra i passi uno dopo l'altro: schermo scurito, il comando illuminato e un fumetto con la spiegazione,
/// "Avanti" e "Salta guida". Restituisce true se la guida è arrivata in fondo, false se è stata saltata.
/// La guida si divide tra più schermate: [first] è il numero del primo passo qui, [total] i passi in tutto.
Future<bool> showGuide(BuildContext context, List<GuideStep> steps, {int first = 1, int? total}) async {
  final visible = [
    for (final step in steps)
      if (step.target.currentContext != null) step,
  ];
  final count = total ?? first - 1 + visible.length;
  for (var i = 0; i < visible.length; i++) {
    if (!context.mounted) return false;
    final next = await Navigator.of(context).push<bool>(
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: false,
        transitionDuration: const Duration(milliseconds: 180),
        pageBuilder: (_, _, _) => _GuideOverlay(step: visible[i], index: first - 1 + i, count: count),
        transitionsBuilder: (_, animation, _, child) => FadeTransition(opacity: animation, child: child),
      ),
    );
    if (next != true) return false;
  }
  return true;
}

class _GuideOverlay extends StatelessWidget {
  const _GuideOverlay({required this.step, required this.index, required this.count});

  final GuideStep step;
  final int index;
  final int count;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final size = MediaQuery.sizeOf(context);
    final box = step.target.currentContext?.findRenderObject() as RenderBox?;
    final hole = box == null || !box.hasSize
        ? Rect.fromCenter(center: size.center(Offset.zero), width: 0, height: 0)
        : (box.localToGlobal(Offset.zero) & box.size).inflate(6);
    // Il fumetto va dalla parte dove c'è più spazio.
    final below = hole.center.dy < size.height / 2;
    final last = index == count - 1;

    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          // Toccando fuori dal fumetto si va avanti.
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.pop(context, true),
              child: CustomPaint(painter: _HolePainter(hole, theme.colorScheme.secondary)),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            top: below ? (hole.bottom + 16).clamp(0, size.height - 200) : null,
            bottom: below ? null : (size.height - hole.top + 16).clamp(0, size.height - 200),
            child: SafeArea(
              child: Card(
                elevation: 8,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 16, 10, 8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l.guideStep(index + 1, count), style: theme.textTheme.labelMedium),
                      const SizedBox(height: 4),
                      Text(step.title, style: theme.textTheme.titleMedium),
                      const SizedBox(height: 6),
                      Text(step.text),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l.skipGuide)),
                          const Spacer(),
                          FilledButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: Text(last ? l.guideGotIt : l.guideNext),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Schermo scurito con un buco arrotondato (e un bordo colorato) sul comando da guardare.
class _HolePainter extends CustomPainter {
  _HolePainter(this.hole, this.color);

  final Rect hole;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final rounded = RRect.fromRectAndRadius(hole, const Radius.circular(18));
    final shade = Path.combine(
      PathOperation.difference,
      Path()..addRect(Offset.zero & size),
      Path()..addRRect(rounded),
    );
    canvas.drawPath(shade, Paint()..color = const Color(0xB3000000));
    canvas.drawRRect(
      rounded,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
  }

  @override
  bool shouldRepaint(_HolePainter old) => old.hole != hole || old.color != color;
}
