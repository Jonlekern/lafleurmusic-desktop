import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lafleurmusic/ui/winamp/bitmap_text.dart';
import 'package:lafleurmusic/ui/winamp/sprite.dart';
import 'package:lafleurmusic/ui/winamp/visualizer.dart';

import 'helpers.dart';

List<String> names(WidgetTester tester) => [
  for (final s in tester.widgetList<Sprite>(find.byType(Sprite))) s.name,
];

void main() {
  testWidgets('Sprite : taille × échelle, sans lissage', (tester) async {
    final skin = await testSkin(tester);
    await tester.pumpWidget(
      inSkin(skin, const Center(child: Sprite('MAIN_PLAY_BUTTON')), scale: 2),
    );
    expect(tester.getSize(find.byType(Sprite)), const Size(46, 36));
    expect(
      tester.widget<RawImage>(find.byType(RawImage)).filterQuality,
      FilterQuality.none,
    );
  });

  testWidgets(
    'BitmapText : une lettre du skin par caractère, majuscules et accents ramenés',
    (tester) async {
      final skin = await testSkin(tester);
      await tester.pumpWidget(inSkin(skin, const BitmapText('Aé?~')));
      expect(names(tester), [
        'CHARACTER_97',
        'CHARACTER_101',
        'CHARACTER_63',
        'CHARACTER_32',
      ]);
    },
  );

  testWidgets(
    'Marquee : texte trop long → défile d’une lettre toutes les 220 ms',
    (tester) async {
      final skin = await testSkin(tester);
      await tester.pumpWidget(
        inSkin(
          skin,
          const Marquee('1. Cage The Elephant - Aberdeen (3:12)', width: 154),
        ),
      );
      final first = names(tester).first;
      await tester.pump(const Duration(milliseconds: 230));
      expect(names(tester).first, isNot(first));
    },
  );

  testWidgets('Marquee : texte court → ne bouge pas', (tester) async {
    final skin = await testSkin(tester);
    await tester.pumpWidget(
      inSkin(skin, const Marquee('LAFLEURMUSIC', width: 154)),
    );
    final before = names(tester);
    await tester.pump(const Duration(seconds: 1));
    expect(names(tester), before);
  });

  testWidgets('TimeDigits : 1:33 → 0 1 3 3 ; temps restant → signe moins', (
    tester,
  ) async {
    final skin = await testSkin(tester);
    await tester.pumpWidget(
      inSkin(skin, const TimeDigits(Duration(seconds: 93))),
    );
    expect(names(tester), [
      'NO_MINUS_SIGN',
      'DIGIT_0',
      'DIGIT_1',
      'DIGIT_3',
      'DIGIT_3',
    ]);
    await tester.pumpWidget(
      inSkin(skin, const TimeDigits(Duration(seconds: 93), remaining: true)),
    );
    expect(names(tester).first, 'MINUS_SIGN');
  });

  testWidgets('Visualiseur : mode 2 → rien de dessiné ; mode 0 → barres', (
    tester,
  ) async {
    final skin = await testSkin(tester);
    await tester.pumpWidget(
      inSkin(skin, const Visualizer(mode: 2, values: [0.5])),
    );
    expect(
      find
          .byType(CustomPaint)
          .evaluate()
          .where((e) => (e.widget as CustomPaint).painter is VisPainter),
      isEmpty,
    );
    await tester.pumpWidget(
      inSkin(skin, const Visualizer(mode: 0, values: [0.5, 1])),
    );
    expect(
      find
          .byType(CustomPaint)
          .evaluate()
          .where((e) => (e.widget as CustomPaint).painter is VisPainter)
          .length,
      1,
    );
  });
}
