import 'package:flutter_test/flutter_test.dart';
import 'package:lafleurmusic/player/equalizer.dart';
import 'package:lafleurmusic/ui/winamp/eq_mapping.dart';

void main() {
  test(
    'les 10 curseurs Winamp donnent les 10 bandes de l’appli, dans l’ordre',
    () {
      final eq = withWinamp(
        Equalizer.named('flat'),
        base: List.filled(10, 0),
        preamp: 0,
        bands: [for (var i = 0; i < 10; i++) i - 5.0],
      );
      expect(eq.gains, [-5, -4, -3, -2, -1, 0, 1, 2, 3, 4]);
      expect(eq.preset, 'custom');
    },
  );

  test('préampli ajouté à chaque bande, borné à ±12 dB', () {
    final eq = withWinamp(
      Equalizer.named('flat'),
      base: [8, 0, -10, 0, 0, 0, 0, 0, 0, 0],
      preamp: 6,
      bands: null,
    );
    expect(eq.gains.take(3), [12, 6, -4]);
  });

  test('ON / OFF de l’égaliseur gardé', () {
    final on = Equalizer.named('rock').copyWith(enabled: true);
    expect(
      withWinamp(on, base: on.gains, preamp: 0, bands: null).enabled,
      isTrue,
    );
  });

  test('préampli tiré une 2e fois : seul le nouveau déplacement compte (pas de double)', () {
    // 1er glisser : 0 → +5 ; les bandes ont déjà pris +5
    final base = List<double>.filled(10, 5);
    final g = preampGains(base, from: 5, to: 6);
    expect(g.first, 6);
    expect(preampGains(base, from: 5, to: 5).first, 5);
  });
}
