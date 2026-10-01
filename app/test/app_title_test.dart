import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_spesa_facile/theme/app_theme.dart';
import 'package:lista_spesa_facile/widgets/ui.dart';

void main() {
  Future<void> pumpPage(WidgetTester tester, {required Widget title, required Widget body, int actions = 4}) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          appBar: AppBar(title: title, actions: [for (var i = 0; i < actions; i++) const Icon(Icons.star)]),
          body: body,
        ),
      ),
    );
  }

  testWidgets('prima pagina: nome dell\'app piccolo in alto e "Le mie liste" grande, senza overflow', (tester) async {
    // Nella pagina, sopra il titolo: la barra in alto è piena di pulsanti e la coprirebbe.
    await pumpPage(
      tester,
      title: const SizedBox(),
      body: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [AppName(), PageHeading('Le mie liste')],
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.text(AppName.appName), findsOneWidget);
    // Scritta intera, non tagliata né sfumata.
    final text = tester.renderObject<RenderParagraph>(find.text(AppName.appName));
    expect(text.didExceedMaxLines, isFalse);
    expect(find.text('Le mie liste'), findsOneWidget);
  });

  testWidgets('lista aperta: nome lungo e data sotto, senza overflow', (tester) async {
    await pumpPage(
      tester,
      title: const SizedBox(),
      body: const PageHeading('Spesa settimanale per la festa di compleanno', subtitle: Text('Domani · 18:00')),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('Domani · 18:00'), findsOneWidget);
  });
}
