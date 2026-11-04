import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lafleurmusic/library/models.dart';
import 'package:lafleurmusic/player/player.dart';
import 'package:lafleurmusic/ui/winamp/main_window.dart';
import 'package:lafleurmusic/ui/winamp/sprite.dart';

import '../fake_player.dart';
import 'helpers.dart';

final aberdeen = Track(
  path: '/m/1.flac',
  folderId: 1,
  title: 'Aberdeen',
  artist: 'Cage The Elephant',
  album: 'A',
  durationMs: 192000,
  hasCover: false,
  mtime: 1,
  size: 1,
);

class Calls {
  final list = <String>[];
}

Future<(FakePlayer, Calls)> pump(
  WidgetTester tester, {
  bool playing = true,
}) async {
  final skin = await testSkin(tester);
  final p = FakePlayer();
  await p.playTracks([aberdeen], 0);
  p.calls.clear();
  p.show(
    PlayerState(
      track: aberdeen,
      position: const Duration(seconds: 93),
      duration: const Duration(seconds: 192),
      playing: playing,
    ),
  );
  final c = Calls();
  await tester.pumpWidget(
    inSkin(
      skin,
      Align(
        alignment: Alignment.topLeft,
        child: MainWindow(
          player: p,
          eqOpen: true,
          plOpen: true,
          visMode: 0,
          onClose: () => c.list.add('close'),
          onToggleEq: () => c.list.add('eq'),
          onTogglePl: () => c.list.add('pl'),
          onVisMode: () => c.list.add('vis'),
        ),
      ),
    ),
  );
  await tester.pump();
  return (p, c);
}

List<String> names(WidgetTester tester) => [
  for (final s in tester.widgetList<Sprite>(find.byType(Sprite))) s.name,
];

void main() {
  testWidgets('taille 275 × 116', (tester) async {
    await pump(tester);
    expect(tester.getSize(find.byType(MainWindow)), const Size(275, 116));
  });

  testWidgets('boutons : précédent, suivant, aléatoire, répétition', (
    tester,
  ) async {
    final (p, _) = await pump(tester);
    for (final k in ['wa-prev', 'wa-next', 'wa-shuffle', 'wa-repeat']) {
      await tester.tap(find.byKey(Key(k)));
      await tester.pump();
    }
    expect(p.calls, ['previous', 'next', 'shuffle', 'repeat']);
  });

  testWidgets(
    'lecture pendant la lecture : reprend au début ; en pause : reprend',
    (tester) async {
      var (p, _) = await pump(tester);
      await tester.tap(find.byKey(const Key('wa-play')));
      expect(p.calls, ['seek']);
      (p, _) = await pump(tester, playing: false);
      await tester.tap(find.byKey(const Key('wa-play')));
      expect(p.calls, ['toggle']);
    },
  );

  testWidgets('pause : bascule ; stop : pause et retour au début', (
    tester,
  ) async {
    final (p, _) = await pump(tester);
    await tester.tap(find.byKey(const Key('wa-pause')));
    expect(p.calls, ['toggle']);
    p.calls.clear();
    await tester.tap(find.byKey(const Key('wa-stop')));
    expect(p.calls, ['toggle', 'seek']);
  });

  testWidgets('bouton enfoncé : image « active » du skin', (tester) async {
    await pump(tester);
    final g = await tester.startGesture(
      tester.getCenter(find.byKey(const Key('wa-next'))),
    );
    await tester.pump();
    expect(names(tester), contains('MAIN_NEXT_BUTTON_ACTIVE'));
    await g.up();
    await tester.pump();
    expect(names(tester), isNot(contains('MAIN_NEXT_BUTTON_ACTIVE')));
  });

  testWidgets('X et éjecter : retour à LAFLEUR ; EQ / PL : leurs fenêtres', (
    tester,
  ) async {
    final (_, c) = await pump(tester);
    for (final k in [
      'wa-close',
      'wa-eject',
      'wa-eqbutton',
      'wa-plbutton',
      'wa-vis',
    ]) {
      await tester.tap(find.byKey(Key(k)));
      await tester.pump();
    }
    expect(c.list, ['close', 'close', 'eq', 'pl', 'vis']);
  });

  testWidgets(
    'position glissée → seek ; volume → setVolume ; balance → setBalance',
    (tester) async {
      final (p, _) = await pump(tester);
      await tester.drag(
        find.byKey(const Key('wa-position')),
        const Offset(60, 0),
      );
      await tester.drag(
        find.byKey(const Key('wa-volume')),
        const Offset(-20, 0),
      );
      await tester.drag(
        find.byKey(const Key('wa-balance')),
        const Offset(30, 0),
      );
      await tester.pump();
      expect(p.calls, containsAllInOrder(['seek', 'volume', 'balance']));
      expect(p.volume, lessThan(75));
      expect(p.balance, greaterThan(0));
    },
  );

  testWidgets('temps 01:33 ; clic sur le temps → temps restant (−01:39)', (
    tester,
  ) async {
    await pump(tester);
    expect(names(tester).where((n) => n.startsWith('DIGIT_')).toList(), [
      'DIGIT_0',
      'DIGIT_1',
      'DIGIT_3',
      'DIGIT_3',
    ]);
    await tester.tap(find.byKey(const Key('wa-time')));
    await tester.pump();
    expect(names(tester), contains('MINUS_SIGN'));
    expect(names(tester).where((n) => n.startsWith('DIGIT_')).toList(), [
      'DIGIT_0',
      'DIGIT_1',
      'DIGIT_3',
      'DIGIT_9',
    ]);
  });

  testWidgets('titre : « 1. Artiste - Titre (3:12) » en lettres du skin', (
    tester,
  ) async {
    await pump(tester);
    expect(
      find.byKey(
        const ValueKey('marquee:1. Cage The Elephant - Aberdeen (3:12)'),
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    'visualiseur : abonné une seule fois, même si le lecteur rend un nouveau flux à chaque appel',
    (tester) async {
      final skin = await testSkin(tester);
      final p = FreshStreamsPlayer();
      await p.playTracks([aberdeen], 0);
      await tester.pumpWidget(
        inSkin(
          skin,
          Align(
            alignment: Alignment.topLeft,
            child: MainWindow(
              player: p,
              eqOpen: true,
              plOpen: true,
              visMode: 0,
              onClose: () {},
              onToggleEq: () {},
              onTogglePl: () {},
              onVisMode: () {},
            ),
          ),
        ),
      );
      for (var i = 1; i <= 5; i++) {
        p.show(
          PlayerState(
            track: aberdeen,
            position: Duration(seconds: i),
            duration: const Duration(seconds: 192),
            playing: true,
          ),
        );
        await tester.pump();
      }
      expect(p.spectrumListens, 1);
      expect(p.infoListens, 1);
    },
  );

  testWidgets('Stop puis Suivant : Pause marche de nouveau', (tester) async {
    final (p, _) = await pump(tester);
    await tester.tap(find.byKey(const Key('wa-stop')));
    await tester.pump();
    p.show(
      PlayerState(
        track: aberdeen,
        position: Duration.zero,
        duration: const Duration(seconds: 192),
        playing: true,
      ),
    );
    await tester.pump();
    p.calls.clear();
    await tester.tap(find.byKey(const Key('wa-pause')));
    expect(p.calls, ['toggle']);
  });
}

/// Comme le vrai lecteur avant correction : un nouveau flux à chaque appel du getter.
class FreshStreamsPlayer extends FakePlayer {
  int spectrumListens = 0, infoListens = 0;
  @override
  Stream<List<double>> get spectrum =>
      Stream<List<double>>.multi((c) => spectrumListens++);
  @override
  Stream<AudioInfo> get infoStream =>
      Stream<AudioInfo>.multi((c) => infoListens++);
}
