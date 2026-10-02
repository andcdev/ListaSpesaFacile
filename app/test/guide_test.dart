import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_spesa_facile/l10n/app_localizations.dart';
import 'package:lista_spesa_facile/widgets/guide.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final first = GlobalKey();
  final second = GlobalKey();
  bool? result;

  Future<void> pump(WidgetTester tester) async {
    result = null;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('it'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Builder(
          builder: (context) => Scaffold(
            body: Column(
              children: [
                ElevatedButton(key: first, onPressed: () {}, child: const Text('uno')),
                ElevatedButton(key: second, onPressed: () {}, child: const Text('due')),
                TextButton(
                  onPressed: () async => result = await showGuide(context, [
                    GuideStep(target: first, title: 'Primo', text: 'Spiegazione uno'),
                    GuideStep(target: second, title: 'Secondo', text: 'Spiegazione due'),
                  ]),
                  child: const Text('guida'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('guida'));
    await tester.pumpAndSettle();
  }

  testWidgets('guida: un passo alla volta con Avanti, in fondo "Ho capito"', (tester) async {
    await pump(tester);
    expect(find.text('Passo 1 di 2'), findsOneWidget);
    expect(find.text('Spiegazione uno'), findsOneWidget);
    await tester.tap(find.text('Avanti'));
    await tester.pumpAndSettle();
    expect(find.text('Passo 2 di 2'), findsOneWidget);
    await tester.tap(find.text('Ho capito'));
    await tester.pumpAndSettle();
    expect(find.text('Passo 2 di 2'), findsNothing);
    expect(result, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('guida: "Salta guida" la chiude subito', (tester) async {
    await pump(tester);
    await tester.tap(find.text('Salta guida'));
    await tester.pumpAndSettle();
    expect(find.text('Spiegazione uno'), findsNothing);
    expect(find.text('Spiegazione due'), findsNothing);
    expect(result, isFalse);
  });

  test('a che punto è la guida, per utente', () async {
    SharedPreferences.setMockInitialValues({});
    expect(await GuideProgress.stage(7), isNull);
    await GuideProgress.set(7, GuideStage.detail);
    expect(await GuideProgress.stage(7), GuideStage.detail);
    expect(await GuideProgress.stage(8), isNull);
  });
}
