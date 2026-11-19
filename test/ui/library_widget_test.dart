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
import 'package:lafleurmusic/tags/tag_writer.dart';
import 'package:lafleurmusic/theme/colors.dart';
import 'package:lafleurmusic/theme/lafleur_theme.dart';
import 'package:lafleurmusic/ui/cover_image.dart';
import 'package:lafleurmusic/ui/library_screen.dart';
import 'package:lafleurmusic/ui/now_panel.dart';
import 'package:lafleurmusic/ui/player_bar.dart';
import 'package:lafleurmusic/ui/track_list.dart';

import '../tags/fake_io.dart';
import 'fake_player.dart';
import 'fonts.dart';

Track t(
  String title,
  int no, {
  String artist = 'Johnny',
  bool missing = false,
  int min = 4,
}) => Track(
  path: '/m/Studio Lafleur/$no $title.flac',
  folderId: 1,
  title: title,
  artist: artist,
  album: 'Studio Lafleur',
  trackNo: no,
  durationMs: min * 60000,
  hasCover: true,
  mtime: 1,
  size: 1,
  missing: missing,
);

final other = Track(
  path: '/m/Night/1.flac',
  folderId: 1,
  title: 'Nightcall',
  artist: 'Kavinsky',
  album: 'Night Drive',
  trackNo: 1,
  durationMs: 1,
  hasCover: true,
  mtime: 1,
  size: 1,
);

final demo = [
  t('Ocean Drive', 1),
  t('Lafleur Surf', 2, artist: 'LAFLEURSTUDIO'),
  t('Golden Hour', 3, artist: 'Divers'),
  t('Night Swim', 4, artist: 'Kavinsky'),
  t('Paradise Club', 5, artist: 'Divers'),
  t('Sunset Tape', 6, artist: 'LAFLEURSTUDIO'),
  t('Palm Waves', 7),
  t('Late Bloom', 8, artist: 'Divers'),
  t('Studio 9', 9, artist: 'LAFLEURSTUDIO'),
];

late FakeIO io;

Future<(LibraryDb, FakePlayer)> pump(
  WidgetTester tester,
  List<Track> tracks,
) async {
  desktopSize(tester);
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
  await tester.runAsync(() => db.upsertTracks(tracks));
  final player = FakePlayer();
  final covers = Covers(
    cacheDir: Directory.systemTemp.createTempSync('c'),
    embedded: (_) async => null,
  );
  io = FakeIO();
  for (final t in tracks) {
    io.files[t.path] = TagEdit(
      path: t.path,
      title: t.title,
      artist: t.artist,
      album: t.album,
      trackNo: t.trackNo,
    );
  }
  await tester.pumpWidget(
    AppScope(
      writer: TagWriter(db, io),
      db: db,
      player: player,
      covers: covers,
      strings: Strings.of(const Locale('fr')),
      child: MaterialApp(
        theme: lafleurTheme(LafleurPalette.current),
        home: const LibraryScreen(),
      ),
    ),
  );
  for (var i = 0; i < 5; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
  }
  return (db, player);
}

void main() {
  setUpAll(loadFonts);

  testWidgets('un seul clic : joue la playlist à partir de ce morceau', (
    tester,
  ) async {
    final (_, player) = await pump(tester, demo);
    await tester.tap(find.text('Golden Hour'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(player.lastIndex, 2);
    expect(player.lastTracks!.length, 9);
    expect(player.lastTracks![player.lastIndex!].title, 'Golden Hour');
  });

  testWidgets('Aléatoire : lance en aléatoire en une fois', (tester) async {
    final (_, player) = await pump(tester, demo);
    await tester.tap(find.text('Aléatoire'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(player.calls, ['play']);
    expect(player.lastShuffle, isTrue);
  });

  testWidgets(
    'après une recherche, un clic sur un morceau rend l’espace au lecteur',
    (tester) async {
      final (_, player) = await pump(tester, demo);
      await tester.tap(find.byKey(const Key('search')));
      await tester.enterText(find.byKey(const Key('search')), 'surf');
      for (var i = 0; i < 3; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump();
      }
      await tester.tap(find.text('Lafleur Surf').last);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      expect(player.calls, ['play', 'toggle']);
    },
  );

  testWidgets(
    'espace : lecture / pause ; flèches : morceau suivant / précédent',
    (tester) async {
      final (_, player) = await pump(tester, demo);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      expect(player.calls, ['toggle', 'next', 'previous']);
    },
  );

  testWidgets('Cmd+F : recherche, puis la saisie ne pilote plus le lecteur', (
    tester,
  ) async {
    final (_, player) = await pump(tester, demo);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    expect(player.calls, isEmpty);
  });

  testWidgets('morceau absent (NAS débranché) : grisé et non jouable', (
    tester,
  ) async {
    final (_, player) = await pump(tester, [
      t('Ocean Drive', 1, missing: true),
      t('Palm Waves', 2),
    ]);
    await tester.tap(find.text('Ocean Drive'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(player.calls, isEmpty);
    expect(find.textContaining('NAS introuvable'), findsOneWidget);
  });

  testWidgets('vue en colonnes comme la maquette 2', (tester) async {
    final (_, player) = await pump(tester, demo);
    player.queue = null;
    await player.playTracks(demo, 1);
    player.show(
      PlayerState(
        track: demo[1],
        position: const Duration(seconds: 93),
        duration: const Duration(seconds: 245),
        playing: true,
      ),
    );
    await tester.pump();
    await precacheAssets(tester, [
      'assets/fleur-tile.png',
      'assets/logo-texte-grand.png',
    ]);
    await expectLater(
      find.byType(LibraryScreen),
      matchesGoldenFile('goldens/2-colonnes.png'),
    );
  });

  testWidgets('mode jour : vue en colonnes comme la maquette du Mac en jour', (
    tester,
  ) async {
    LafleurPalette.current = LafleurPalette.day;
    addTearDown(() => LafleurPalette.current = LafleurPalette.night);
    final (_, player) = await pump(tester, demo);
    player.queue = null;
    await player.playTracks(demo, 1);
    player.show(
      PlayerState(
        track: demo[1],
        position: const Duration(seconds: 93),
        duration: const Duration(seconds: 245),
        playing: true,
      ),
    );
    await tester.pump();
    await precacheAssets(tester, [
      'assets/fleur.png',
      'assets/logo-texte-grand.png',
    ]);
    await expectLater(
      find.byType(LibraryScreen),
      matchesGoldenFile('goldens/2-colonnes-jour.png'),
    );
  });

  testWidgets('Artistes : liste des noms, puis leurs morceaux', (tester) async {
    await pump(tester, demo);
    await tester.tap(find.text('Artistes'));
    for (var i = 0; i < 3; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }
    expect(find.text('Kavinsky'), findsOneWidget);
    await tester.tap(find.text('Kavinsky'));
    for (var i = 0; i < 3; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }
    expect(find.text('Night Swim'), findsOneWidget);
    expect(find.text('Ocean Drive'), findsNothing);
  });

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 4; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }
  }

  testWidgets(
    'double-clic sur un titre : on le modifie, Entrée l’écrit dans le fichier',
    (tester) async {
      await pump(tester, demo);
      await tester.tap(find.text('Palm Waves'));
      await tester.pump(const Duration(milliseconds: 80));
      await tester.tap(find.text('Palm Waves'));
      await tester.pump();
      await tester.enterText(
        find.byKey(const Key('edit-field')),
        'Palm Waves (Remix)',
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await settle(tester);
      expect(io.files[demo[6].path]!.title, 'Palm Waves (Remix)');
      expect(find.text('Palm Waves (Remix)'), findsOneWidget);
    },
  );

  testWidgets('Échap annule la modification', (tester) async {
    await pump(tester, demo);
    await tester.tap(find.text('Kavinsky'));
    await tester.pump(const Duration(milliseconds: 80));
    await tester.tap(find.text('Kavinsky'));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('edit-field')), 'X');
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await settle(tester);
    expect(io.files[demo[3].path]!.artist, 'Kavinsky');
    expect(find.byKey(const Key('edit-field')), findsNothing);
  });

  testWidgets('un simple clic joue toujours, sans attendre', (tester) async {
    final (_, player) = await pump(tester, demo);
    await tester.tap(find.text('Night Swim'));
    await tester.pump();
    expect(player.calls, ['play']);
  });

  testWidgets(
    'double-clic sur le nom de la playlist : renomme l’album de tous ses morceaux',
    (tester) async {
      await pump(tester, demo);
      final title = find.text('Studio Lafleur').last;
      await tester.tap(title);
      await tester.pump(const Duration(milliseconds: 80));
      await tester.tap(title);
      await tester.pump();
      await tester.enterText(
        find.byKey(const Key('edit-album')),
        'Studio Lafleur 2',
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await settle(tester);
      expect(
        io.files.values.every((e) => e.album == 'Studio Lafleur 2'),
        isTrue,
      );
      // la vue suit la playlist renommée, puis l'annulation
      expect(find.text('Night Swim'), findsOneWidget);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
      await settle(tester);
      expect(find.text('Night Swim'), findsOneWidget);
    },
  );

  bool typing() =>
      FocusManager.instance.primaryFocus?.context
          ?.findAncestorWidgetOfExactType<EditableText>() !=
      null;

  testWidgets(
    'double-clic sur un titre de morceau : le champ prend le clavier',
    (tester) async {
      final (_, player) = await pump(tester, demo);
      await tester.tap(find.text('Palm Waves'));
      await tester.pump(const Duration(milliseconds: 80));
      await tester.tap(find.text('Palm Waves'));
      await tester.pump();
      await tester.pump();
      expect(typing(), isTrue);
      player.calls.clear();
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      expect(player.calls, isEmpty);
    },
  );

  testWidgets('Nouvel album : le champ du nom prend le clavier', (
    tester,
  ) async {
    await pump(tester, demo);
    await tester.tap(find.text('Nouvel album'));
    await tester.pump();
    await tester.pump();
    expect(typing(), isTrue);
  });

  testWidgets(
    'espace dans un champ de modification : tape un espace, ne met pas en pause',
    (tester) async {
      final (_, player) = await pump(tester, demo);
      final title = find.text('Studio Lafleur').last;
      await tester.tap(title);
      await tester.pump(const Duration(milliseconds: 80));
      await tester.tap(title);
      await tester.pump();
      await tester.pump(); // autofocus du champ
      expect(find.byKey(const Key('edit-album')), findsOneWidget);
      player.calls.clear();
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();
      expect(player.calls, isEmpty);
    },
  );

  Future<void> dragTo(WidgetTester tester, Finder from, Finder to) async {
    final g = await tester.startGesture(tester.getCenter(from));
    await tester.pump(const Duration(milliseconds: 50));
    await g.moveBy(const Offset(0, 20));
    await tester.pump();
    await g.moveTo(tester.getCenter(to));
    await tester.pump();
    await g.up();
    await settle(tester);
  }

  testWidgets(
    'glisser le 5e morceau sur le 1er : numéros réécrits dans les fichiers',
    (tester) async {
      await pump(tester, demo);
      await dragTo(
        tester,
        find.text('Paradise Club'),
        find.text('Ocean Drive'),
      );
      expect(io.files[demo[4].path]!.trackNo, 1);
      expect(io.files[demo[0].path]!.trackNo, 2);
      expect(io.files[demo[5].path]!.trackNo, 6);
    },
  );

  testWidgets(
    'glisser un morceau sur une autre playlist : son album change ; Cmd+Z annule',
    (tester) async {
      await pump(tester, [...demo, other]);
      await tester.tap(find.text('Studio Lafleur').first);
      await settle(tester);
      await dragTo(
        tester,
        find.text('Palm Waves'),
        find.text('Night Drive').first,
      );
      expect(io.files[demo[6].path]!.album, 'Night Drive');
      await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
      await settle(tester);
      expect(io.files[demo[6].path]!.album, 'Studio Lafleur');
    },
  );

  testWidgets('Nouvel album : nommée, puis on y glisse un morceau', (
    tester,
  ) async {
    await pump(tester, demo);
    await tester.tap(find.text('Nouvel album'));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('new-playlist')), 'Roadtrip');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    await dragTo(tester, find.text('Golden Hour'), find.text('Roadtrip'));
    expect(io.files[demo[2].path]!.album, 'Roadtrip');
  });

  Finder inList(String text) =>
      find.descendant(of: find.byType(TrackList), matching: find.text(text));

  testWidgets('Morceaux : étiquette BIBLIOTHÈQUE, pas ALBUM', (tester) async {
    await pump(tester, [...demo, other]);
    await tester.tap(find.text('Morceaux').first);
    await settle(tester);
    expect(inList('BIBLIOTHÈQUE'), findsOneWidget);
    expect(inList('ALBUM'), findsNothing);
  });

  testWidgets('un album : étiquette ALBUM', (tester) async {
    await pump(tester, demo);
    expect(inList('ALBUM'), findsOneWidget);
  });

  Future<void> playing(WidgetTester tester, FakePlayer player) async {
    player.queue = null;
    await player.playTracks(demo, 1);
    player.show(
      PlayerState(
        track: demo[1],
        position: const Duration(seconds: 93),
        duration: const Duration(seconds: 245),
        playing: true,
      ),
    );
    await tester.pump();
  }

  Future<void> resize(WidgetTester tester, Size s) async {
    tester.view.physicalSize = s;
    await tester.pump();
  }

  testWidgets(
    'taille moyenne : sans « En cours », titre au-dessus de la barre de temps',
    (tester) async {
      final (_, player) = await pump(tester, demo);
      await playing(tester, player);
      await resize(tester, const Size(860, 690));
      expect(find.byType(NowPanel), findsNothing);
      final bar = find.byType(PlayerBar);
      final title = find.descendant(
        of: bar,
        matching: find.text('Lafleur Surf'),
      );
      expect(title, findsOneWidget);
      expect(
        tester.getCenter(title).dy,
        lessThan(tester.getCenter(find.byKey(const Key('progress'))).dy),
      );
      expect(
        find.descendant(of: bar, matching: find.byType(CoverImage)),
        findsNothing,
      );
      expect(find.text('EQ'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('grande taille (920) : « En cours » toujours là', (tester) async {
    final (_, player) = await pump(tester, demo);
    await playing(tester, player);
    await resize(tester, const Size(920, 690));
    expect(find.byType(NowPanel), findsOneWidget);
  });

  testWidgets('taille moyenne la plus étroite (560) : rien ne déborde', (
    tester,
  ) async {
    final (_, player) = await pump(tester, demo);
    await playing(tester, player);
    await resize(tester, const Size(560, 690));
    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('playpause')), findsOneWidget);
    expect(find.text('EQ'), findsOneWidget);
  });

  for (final day in [false, true]) {
    testWidgets('image : taille moyenne ${day ? 'jour' : 'nuit'}', (
      tester,
    ) async {
      if (day) {
        LafleurPalette.current = LafleurPalette.day;
        addTearDown(() => LafleurPalette.current = LafleurPalette.night);
      }
      final (_, player) = await pump(tester, demo);
      await playing(tester, player);
      await resize(tester, const Size(860, 690));
      await precacheAssets(tester, [
        'assets/fleur-tile.png',
        'assets/fleur.png',
        'assets/logo-texte-grand.png',
      ]);
      await expectLater(
        find.byType(LibraryScreen),
        matchesGoldenFile('goldens/2c-moyenne${day ? '-jour' : ''}.png'),
      );
    });
  }
}
