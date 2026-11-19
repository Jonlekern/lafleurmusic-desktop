import 'dart:io';

import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lafleurmusic/app_scope.dart';
import 'package:lafleurmusic/l10n/strings.dart';
import 'package:lafleurmusic/library/covers.dart';
import 'package:lafleurmusic/library/db.dart';
import 'package:lafleurmusic/library/models.dart';
import 'package:lafleurmusic/player/player.dart';
import 'package:lafleurmusic/theme/colors.dart';
import 'package:lafleurmusic/theme/lafleur_theme.dart';
import 'package:lafleurmusic/ui/cover_image.dart';
import 'package:lafleurmusic/ui/mini_player.dart';
import 'package:lafleurmusic/ui/player_controls.dart';

import 'fake_player.dart';
import 'fonts.dart';

Track _track(String title) => Track(
  path: '/m/1.flac',
  folderId: 1,
  title: title,
  artist: 'LAFLEURSTUDIO',
  album: 'Studio Lafleur',
  trackNo: 1,
  durationMs: 245000,
  hasCover: false,
  mtime: 1,
  size: 1,
);

void main() {
  setUpAll(loadFonts);
  late FakePlayer player;

  Future<void> pump(
    WidgetTester tester, {
    Size size = const Size(480, 130),
    Track? track,
    Widget? child,
    Widget? app,
    List<Track> library = const [],
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final db = LibraryDb(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(db.close);
    });
    if (library.isNotEmpty) {
      await tester.runAsync(() => db.upsertTracks(library));
    }
    player = FakePlayer();
    player.current = track == null
        ? const PlayerState()
        : PlayerState(
            track: track,
            position: const Duration(seconds: 93),
            duration: const Duration(seconds: 245),
            playing: true,
          );
    await tester.pumpWidget(
      AppScope(
        db: db,
        player: player,
        covers: Covers(
          cacheDir: Directory.systemTemp.createTempSync('mini'),
          embedded: (_) async => null,
        ),
        strings: Strings.of(const Locale('fr')),
        child:
            app ??
            MaterialApp(
              theme: lafleurTheme(LafleurPalette.current),
              home: Scaffold(body: child ?? const MiniPlayer()),
            ),
      ),
    );
    await tester.pump();
  }

  testWidgets(
    'mini-lecteur : titre, boutons, barre de temps, volume, rien d\'autre',
    (tester) async {
      await pump(tester, track: _track('Lafleur Surf'));
      expect(find.text('Lafleur Surf'), findsOneWidget);
      expect(find.byKey(const Key('playpause')), findsOneWidget);
      expect(find.byKey(const Key('progress')), findsOneWidget);
      expect(find.byType(Slider), findsOneWidget);
      expect(find.text('EQ'), findsNothing);
      expect(find.text('Cover Flow'), findsNothing);
      expect(find.text('Skins'), findsNothing);
      expect(find.byType(CoverImage), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'clavier : espace = lecture / pause, flèches = suivant / précédent',
    (tester) async {
      await pump(tester, track: _track('Lafleur Surf'));
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      expect(player.calls, containsAllInOrder(['toggle', 'next', 'previous']));
    },
  );

  testWidgets('aucun morceau : pas d\'erreur, même hauteur', (tester) async {
    await pump(tester);
    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('playpause')), findsOneWidget);
  });

  testWidgets('titre très long à 440 de large : coupé avec « … »', (
    tester,
  ) async {
    await pump(
      tester,
      size: const Size(440, 130),
      track: _track('Lafleur Surf ' * 20),
    );
    expect(tester.takeException(), isNull);
    final t = tester.widget<Text>(find.textContaining('Lafleur Surf'));
    expect(t.overflow, TextOverflow.ellipsis);
    expect(t.maxLines, 1);
  });

  for (final day in [false, true]) {
    testWidgets('image : mini-lecteur ${day ? 'jour' : 'nuit'}', (
      tester,
    ) async {
      if (day) {
        LafleurPalette.current = LafleurPalette.day;
        addTearDown(() => LafleurPalette.current = LafleurPalette.night);
      }
      await pump(tester, track: _track('Lafleur Surf'));
      await expectLater(
        find.byType(MiniPlayer),
        matchesGoldenFile('goldens/10-mini${day ? '-jour' : ''}.png'),
      );
    });
  }

  testWidgets('fenêtre basse : mini-lecteur, la page reste vivante derrière', (
    tester,
  ) async {
    await pump(
      tester,
      size: const Size(900, 130),
      track: _track('Lafleur Surf'),
      child: const WindowSteps(child: Text('page')),
    );
    expect(find.byType(MiniPlayer), findsOneWidget);
    expect(find.text('page'), findsNothing);
    expect(find.text('page', skipOffstage: false), findsOneWidget);
  });

  testWidgets('fenêtre haute : la page, pas de mini-lecteur', (tester) async {
    await pump(
      tester,
      size: const Size(900, 690),
      child: const WindowSteps(child: Text('page')),
    );
    expect(find.text('page'), findsOneWidget);
    expect(find.byType(MiniPlayer), findsNothing);
  });

  // comme dans main.dart : le mini-lecteur est posé par MaterialApp.builder, au-dessus du Navigator
  Widget realApp(Widget page) => MaterialApp(
    theme: lafleurTheme(LafleurPalette.current),
    builder: (context, child) => WindowSteps(child: child!),
    home: Scaffold(body: page),
  );

  testWidgets('dans l\'appli (MaterialApp.builder) : le mini-lecteur marche', (
    tester,
  ) async {
    await pump(
      tester,
      size: const Size(900, 130),
      track: _track('Lafleur Surf'),
      app: realApp(const Text('page')),
    );
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const Key('playpause')));
    expect(player.calls, contains('toggle'));
  });

  testWidgets(
    'recherche active puis fenêtre réduite : espace = lecture / pause',
    (tester) async {
      await pump(
        tester,
        size: const Size(900, 690),
        track: _track('Lafleur Surf'),
        app: realApp(const TextField(autofocus: true)),
      );
      await tester.pump();
      tester.view.physicalSize = const Size(900, 130);
      await tester.pump();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      expect(player.calls, contains('toggle'));
      expect(
        tester
            .widget<EditableText>(
              find.byType(EditableText, skipOffstage: false),
            )
            .controller
            .text,
        isEmpty,
      );
    },
  );

  testWidgets('volume changé dans le mini-lecteur : la barre suit', (
    tester,
  ) async {
    await pump(
      tester,
      track: _track('Lafleur Surf'),
      child: const Column(
        children: [
          VolumeControl(key: Key('a')),
          VolumeControl(key: Key('b')),
        ],
      ),
    );
    await player.setVolume(20);
    await tester.pump();
    final b = tester.widget<Slider>(
      find.descendant(
        of: find.byKey(const Key('b')),
        matching: find.byType(Slider),
      ),
    );
    expect(b.value, 20);
  });

  Track other(int i) => Track(
    path: '/m/$i.flac',
    folderId: 1,
    title: 'T$i',
    artist: 'A',
    album: 'B',
    trackNo: i,
    durationMs: 1000,
    hasCover: false,
    mtime: 1,
    size: 1,
  );

  testWidgets('rien de choisi : Lecture joue toute la bibliothèque au hasard', (
    tester,
  ) async {
    final lib = [for (var i = 1; i <= 5; i++) other(i)];
    await pump(tester, library: lib);
    await tester.tap(find.byKey(const Key('playpause')));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump();
    expect(player.calls, contains('play'));
    expect(player.calls, isNot(contains('toggle')));
    expect(player.lastShuffle, true);
    expect(player.lastTracks?.length, 5);
  });

  testWidgets('rien de choisi : espace aussi', (tester) async {
    await pump(tester, library: [other(1), other(2)]);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    expect(player.calls, contains('play'));
    expect(player.lastShuffle, true);
  });

  testWidgets(
    'un morceau en cours : Lecture fait pause / lecture comme avant',
    (tester) async {
      await pump(tester, track: _track('Lafleur Surf'), library: [other(1)]);
      await tester.tap(find.byKey(const Key('playpause')));
      expect(player.calls, ['toggle']);
    },
  );

  testWidgets('bibliothèque vide : Lecture ne fait rien, sans erreur', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(find.byKey(const Key('playpause')));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    expect(player.calls, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('mini large (700) : la pochette à gauche, et l\'artiste', (
    tester,
  ) async {
    await pump(
      tester,
      size: const Size(700, 130),
      track: _track('Lafleur Surf'),
    );
    expect(find.byType(CoverImage), findsOneWidget);
    expect(
      find.textContaining('LAFLEURSTUDIO', findRichText: true),
      findsOneWidget,
    );
    expect(
      tester.getCenter(find.byType(CoverImage)).dx,
      lessThan(tester.getCenter(find.byKey(const Key('playpause'))).dx),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('mini étroit (600) : la bande, sans pochette', (tester) async {
    await pump(
      tester,
      size: const Size(600, 130),
      track: _track('Lafleur Surf'),
    );
    expect(find.byType(CoverImage), findsNothing);
  });

  for (final day in [false, true]) {
    testWidgets('image : mini avec pochette ${day ? 'jour' : 'nuit'}', (
      tester,
    ) async {
      if (day) {
        LafleurPalette.current = LafleurPalette.day;
        addTearDown(() => LafleurPalette.current = LafleurPalette.night);
      }
      await pump(
        tester,
        size: const Size(700, 130),
        track: _track('Lafleur Surf'),
      );
      await precacheAssets(tester, [
        'assets/fleur-tile.png',
        'assets/fleur.png',
      ]);
      await expectLater(
        find.byType(MiniPlayer),
        matchesGoldenFile('goldens/10-mini-pochette${day ? '-jour' : ''}.png'),
      );
    });
  }

  testWidgets('sous 300 de large : juste le rond rose', (tester) async {
    await pump(
      tester,
      size: const Size(150, 130),
      track: _track('Lafleur Surf'),
    );
    expect(find.byKey(const Key('playpause')), findsOneWidget);
    expect(find.byKey(const Key('progress')), findsNothing);
    expect(find.byType(Slider), findsNothing);
    expect(find.textContaining('Lafleur Surf'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const Key('playpause')));
    expect(player.calls, ['toggle']);
  });

  testWidgets('bande la plus étroite (300) : rien ne déborde', (tester) async {
    await pump(
      tester,
      size: const Size(300, 130),
      track: _track('Lafleur Surf'),
    );
    expect(find.byKey(const Key('progress')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final day in [false, true]) {
    testWidgets('image : rond rose ${day ? 'jour' : 'nuit'}', (tester) async {
      if (day) {
        LafleurPalette.current = LafleurPalette.day;
        addTearDown(() => LafleurPalette.current = LafleurPalette.night);
      }
      await pump(
        tester,
        size: const Size(150, 130),
        track: _track('Lafleur Surf'),
      );
      await expectLater(
        find.byType(MiniPlayer),
        matchesGoldenFile('goldens/10-rond${day ? '-jour' : ''}.png'),
      );
    });
  }

  testWidgets('rond rose en lecture : il bat sur les basses, puis revient', (
    tester,
  ) async {
    await pump(
      tester,
      size: const Size(150, 130),
      track: _track('Lafleur Surf'),
    );
    double scale() => tester
        .widget<Transform>(find.byKey(const Key('beat')))
        .transform
        .getMaxScaleOnAxis();
    for (var i = 0; i < 20; i++) {
      player.spectrumCtrl.add([0.3, 0.3, 0.3, 0.1]);
      await tester.pump(const Duration(milliseconds: 30));
    }
    expect(scale(), closeTo(1, 0.001));
    player.spectrumCtrl.add([0.9, 0.9, 0.9, 0.1]);
    await tester.pump(const Duration(milliseconds: 16));
    expect(scale(), greaterThan(1.1));
    for (var i = 0; i < 12; i++) {
      player.spectrumCtrl.add([0.3, 0.3, 0.3, 0.1]);
      await tester.pump(const Duration(milliseconds: 30));
    }
    expect(scale(), closeTo(1, 0.001));
  });
}
