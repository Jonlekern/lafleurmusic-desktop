import 'package:flutter/painting.dart' show Size;
import 'package:flutter_test/flutter_test.dart';
import 'package:lafleurmusic/ui/window_steps.dart';

void main() {
  test('seuils', () {
    expect(stepFor(const Size(920, 690)), WindowStep.large);
    expect(stepFor(const Size(879, 690)), WindowStep.medium);
    expect(stepFor(const Size(1400, 299)), WindowStep.mini);
    expect(stepFor(const Size(500, 300)), WindowStep.medium);
  });

  test('lâchée sous 300 : se cale à 130, retient la taille d\'avant', () {
    final m = MiniSnap();
    expect(m.settled(const Size(920, 690)), isNull);
    expect(m.settled(const Size(900, 250)), const Size(900, 130));
    expect(m.mini, true);
    expect(m.restore, const Size(920, 690));
  });

  test('en mini, lâchée entre 130 et 200 : revient à 130', () {
    final m = MiniSnap()
      ..settled(const Size(920, 690))
      ..settled(const Size(900, 250));
    expect(m.settled(const Size(900, 180)), const Size(900, 130));
  });

  test('en mini, tirée au-delà de 200 : reprend la taille d\'avant', () {
    final m = MiniSnap()
      ..settled(const Size(920, 690))
      ..settled(const Size(900, 250));
    expect(m.settled(const Size(900, 260)), const Size(920, 690));
    expect(m.mini, false);
  });

  test('plein écran : jamais d\'aimant', () {
    expect(MiniSnap().settled(const Size(1920, 250), fullScreen: true), isNull);
  });

  test('rouverte en mini : la taille gardée sert au retour', () {
    final m = MiniSnap(restore: const Size(1000, 700));
    expect(m.settled(const Size(600, 130)), isNull); // déjà calée
    expect(m.mini, true);
    expect(m.settled(const Size(600, 240)), const Size(1000, 700));
  });

  test('pas de taille gardée : retour à 920 × 690', () {
    final m = MiniSnap();
    m.settled(const Size(600, 130));
    expect(m.settled(const Size(600, 240)), const Size(920, 690));
  });

  test('le mini-lecteur peut descendre jusqu\'au rond rose (150 × 130)', () {
    expect(kMinWindow, const Size(150, 130));
  });
}
