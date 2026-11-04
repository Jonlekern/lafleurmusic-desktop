import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lafleurmusic/l10n/strings.dart';
import 'package:lafleurmusic/player/equalizer.dart';
import 'package:lafleurmusic/ui/winamp/eq_window.dart';

import 'helpers.dart';

Future<ValueNotifier<Equalizer>> pump(
  WidgetTester tester, {
  List<String>? log,
}) async {
  final skin = await testSkin(tester);
  final eq = ValueNotifier(Equalizer.named('flat'));
  await tester.pumpWidget(
    inSkin(
      skin,
      Align(
        alignment: Alignment.topLeft,
        child: EqWindow(
          equalizer: eq,
          strings: Strings.of(const Locale('fr')),
          onClose: () => log?.add('close'),
        ),
      ),
    ),
  );
  return eq;
}

void main() {
  testWidgets('taille 275 × 116', (tester) async {
    await pump(tester);
    expect(tester.getSize(find.byType(EqWindow)), const Size(275, 116));
  });

  testWidgets(
    'glisser la 4e bande vers le haut : l’égaliseur de l’appli change',
    (tester) async {
      final eq = await pump(tester);
      await tester.drag(
        find.byKey(const Key('wa-band-3')),
        const Offset(0, -30),
      );
      await tester.pump();
      expect(eq.value.gains[3], greaterThan(3));
      expect(eq.value.gains[2], 0);
    },
  );

  testWidgets('préampli monté : toutes les bandes montent', (tester) async {
    final eq = await pump(tester);
    await tester.drag(find.byKey(const Key('wa-preamp')), const Offset(0, -30));
    await tester.pump();
    expect(eq.value.gains.every((g) => g > 3), isTrue);
  });

  testWidgets('ON : allume puis éteint', (tester) async {
    final eq = await pump(tester);
    await tester.tap(find.byKey(const Key('wa-eq-on')));
    expect(eq.value.enabled, isTrue);
    await tester.tap(find.byKey(const Key('wa-eq-on')));
    expect(eq.value.enabled, isFalse);
  });

  testWidgets('PRESETS : menu des préréglages, Rock appliqué', (tester) async {
    final eq = await pump(tester);
    await tester.tap(find.byKey(const Key('wa-eq-presets')));
    await tester.pumpAndSettle();
    for (final n in ['Plat', 'Basses', 'Voix', 'Rock', 'Électro']) {
      expect(find.text(n), findsOneWidget);
    }
    await tester.tap(find.text('Rock'));
    await tester.pumpAndSettle();
    expect(eq.value.gains, Equalizer.presets['rock']);
  });

  testWidgets('réglage changé ailleurs (LAFLEUR) : les curseurs suivent', (
    tester,
  ) async {
    final eq = await pump(tester);
    final before = tester.getTopLeft(find.byKey(const Key('wa-band-0-thumb')));
    eq.value = Equalizer.named('bass');
    await tester.pump();
    expect(
      tester.getTopLeft(find.byKey(const Key('wa-band-0-thumb'))).dy,
      lessThan(before.dy),
    );
  });

  testWidgets('X : ferme la fenêtre égaliseur', (tester) async {
    final log = <String>[];
    await pump(tester, log: log);
    await tester.tap(find.byKey(const Key('wa-eq-close')));
    expect(log, ['close']);
  });
}
