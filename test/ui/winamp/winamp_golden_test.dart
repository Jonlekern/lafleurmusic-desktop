import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lafleurmusic/l10n/strings.dart';
import 'package:lafleurmusic/library/models.dart';
import 'package:lafleurmusic/player/equalizer.dart';
import 'package:lafleurmusic/player/player.dart';
import 'package:lafleurmusic/skins/skin.dart';
import 'package:lafleurmusic/ui/winamp/eq_window.dart';
import 'package:lafleurmusic/ui/winamp/main_window.dart';
import 'package:lafleurmusic/ui/winamp/playlist_window.dart';
import 'package:lafleurmusic/ui/winamp/winamp_scope.dart';

import '../fake_player.dart';
import '../fonts.dart';

Track tr(int i, String artist, String title, int s) => Track(
  path: '/m/$i.flac',
  folderId: 1,
  title: title,
  artist: artist,
  album: 'A',
  durationMs: s * 1000,
  hasCover: false,
  mtime: 1,
  size: 1,
);

final queue = [
  tr(1, 'Cage The Elephant', 'Aberdeen', 192),
  tr(2, 'Zerb', 'Addicted', 152),
  tr(3, 'LF SYSTEM', 'Afraid To Feel', 177),
  tr(4, 'BL3SS', 'Afters', 124),
];

Future<void> pumpWinamp(WidgetTester tester, Skin skin) async {
  tester.view.physicalSize = const Size(550, 696);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final p = FakePlayer();
  await p.playTracks(queue, 0);
  p.show(
    PlayerState(
      track: queue[0],
      position: const Duration(seconds: 93),
      duration: const Duration(seconds: 192),
      playing: true,
    ),
  );
  final eq = ValueNotifier(Equalizer.named('rock').copyWith(enabled: true));
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Colors.black,
        body: WinampScope(
          skin: skin,
          scale: 2,
          child: RepaintBoundary(
            key: const Key('winamp'),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                MainWindow(
                  player: p,
                  eqOpen: true,
                  plOpen: true,
                  visMode: 2,
                  onClose: () {},
                  onToggleEq: () {},
                  onTogglePl: () {},
                  onVisMode: () {},
                ),
                EqWindow(
                  equalizer: eq,
                  strings: Strings.of(const Locale('fr')),
                  onClose: () {},
                ),
                PlaylistWindow(player: p, onClose: () {}),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  setUpAll(loadFonts);

  testWidgets('les 3 fenêtres en taille double, skin d’essai', (tester) async {
    final skin = (await tester.runAsync(
      () => Skin.load(File('test/fixtures/skins/lafleur-test.wsz')),
    ))!;
    await pumpWinamp(tester, skin);
    await expectLater(
      find.byKey(const Key('winamp')),
      matchesGoldenFile('../goldens/7-winamp.png'),
    );
  });

  // skins de Johnny (dossier local, non publié) : images à comparer à l'œil avec la maquette 7
  final local = Directory('test/fixtures/skins-local');
  for (final f
      in local.existsSync()
          ? local.listSync().whereType<File>().where(
              (f) => f.path.endsWith('.wsz'),
            )
          : <File>[]) {
    testWidgets('skin de Johnny à l’œil : ${f.uri.pathSegments.last}', (
      tester,
    ) async {
      final skin = (await tester.runAsync(() => Skin.load(f)))!;
      await pumpWinamp(tester, skin);
      final img = await captureImage(
        tester.element(find.byKey(const Key('winamp'))),
      );
      await tester.runAsync(() async {
        final png = await img.toByteData(format: ui.ImageByteFormat.png);
        final out = File('build/winamp-local/${skin.name}.png')
          ..createSync(recursive: true);
        out.writeAsBytesSync(png!.buffer.asUint8List());
      });
    });
  }
}
