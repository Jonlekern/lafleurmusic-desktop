import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lafleurmusic/library/models.dart';
import 'package:lafleurmusic/player/player.dart';
import 'package:lafleurmusic/ui/winamp/playlist_window.dart';

import '../fake_player.dart';
import 'helpers.dart';

Track tr(int i) => Track(
  path: '/m/$i.flac',
  folderId: 1,
  title: 'Titre $i',
  artist: 'Artiste',
  album: 'A',
  durationMs: 60000 * i,
  hasCover: false,
  mtime: 1,
  size: 1,
);

Future<FakePlayer> pump(WidgetTester tester) async {
  final skin = await testSkin(tester);
  final p = FakePlayer();
  final list = [for (var i = 1; i <= 6; i++) tr(i)];
  await p.playTracks(list, 0);
  p.calls.clear();
  p.show(PlayerState(track: list[0], playing: true));
  await tester.pumpWidget(
    inSkin(
      skin,
      Align(
        alignment: Alignment.topLeft,
        child: PlaylistWindow(player: p, onClose: () {}),
      ),
    ),
  );
  await tester.pump();
  return p;
}

void main() {
  testWidgets('taille 275 × 116 ; 6 morceaux → 4 lignes visibles', (
    tester,
  ) async {
    await pump(tester);
    expect(tester.getSize(find.byType(PlaylistWindow)), const Size(275, 116));
    expect(find.textContaining('Titre'), findsNWidgets(4));
    expect(find.text('1. Artiste - Titre 1'), findsOneWidget);
  });

  testWidgets('molette : la liste défile', (tester) async {
    await pump(tester);
    final c = tester.getCenter(find.byType(PlaylistWindow));
    tester.binding.handlePointerEvent(
      PointerScrollEvent(position: c, scrollDelta: const Offset(0, 40)),
    );
    await tester.pump();
    expect(find.text('1. Artiste - Titre 1'), findsNothing);
    expect(find.text('5. Artiste - Titre 5'), findsOneWidget);
  });

  testWidgets('double-clic : joue ce morceau, sans refaire la file', (
    tester,
  ) async {
    final p = await pump(tester);
    await tester.tap(find.text('3. Artiste - Titre 3'));
    await tester.pump(const Duration(milliseconds: 80));
    await tester.tap(find.text('3. Artiste - Titre 3'));
    await tester.pump();
    // on saute au morceau dans la file telle qu'elle est (l'aléatoire n'est pas refait)
    expect(p.calls, ['jump']);
    expect(p.queue!.position, 2);
  });

  testWidgets('clic puis Suppr : retiré de la file', (tester) async {
    final p = await pump(tester);
    await tester.tap(find.text('2. Artiste - Titre 2'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.sendKeyEvent(LogicalKeyboardKey.delete);
    await tester.pump();
    expect(p.calls, ['remove']);
    expect(p.queue!.order.length, 5);
  });

  testWidgets(
    'morceau en cours en couleur « Current » du skin, les autres en « Normal »',
    (tester) async {
      final skin = await testSkin(tester);
      await pump(tester);
      expect(
        tester.widget<Text>(find.text('1. Artiste - Titre 1')).style!.color,
        skin.playlistColor('current'),
      );
      expect(
        tester.widget<Text>(find.text('2. Artiste - Titre 2')).style!.color,
        skin.playlistColor('normal'),
      );
    },
  );
}
