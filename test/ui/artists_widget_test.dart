import 'dart:io';

import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lafleurmusic/app_scope.dart';
import 'package:lafleurmusic/artists/artist_lookup.dart';
import 'package:lafleurmusic/artists/artist_store.dart';
import 'package:lafleurmusic/l10n/strings.dart';
import 'package:lafleurmusic/library/covers.dart';
import 'package:lafleurmusic/library/db.dart';
import 'package:lafleurmusic/library/models.dart';
import 'package:lafleurmusic/theme/lafleur_theme.dart';
import 'package:lafleurmusic/ui/library_screen.dart';
import 'package:lafleurmusic/ui/track_list.dart';

import 'fake_player.dart';
import 'fonts.dart';

Track tr(String title, String artist, String album, int no) => Track(
  path: '/m/$album/$no.flac',
  folderId: 1,
  title: title,
  artist: artist,
  album: album,
  trackNo: no,
  durationMs: 200000,
  hasCover: false,
  mtime: 1,
  size: 1,
);

final tracks = [
  tr('Aberdeen', 'Cage The Elephant', 'Indie Rock Playlist', 1),
  tr('Trouble', 'Cage The Elephant', 'Summer Mix', 2),
  tr('Nightcall', 'Kavinsky', 'Night Drive', 1),
];

const longText =
    'Un groupe de rock venu du Kentucky. Il joue depuis longtemps et a sorti beaucoup '
    'd’albums. Une phrase de plus pour que le texte dépasse six lignes dans la colonne '
    'de droite, et encore une autre, et encore une autre, et encore une autre, et encore '
    'une autre, et encore une autre, et encore une autre, et encore une autre pour finir.';

Future<ValueNotifier<bool>> pump(WidgetTester tester) async {
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
  final store = ArtistStore(
    dir: Directory.systemTemp.createTempSync('aw'),
    find: (n) async => n == 'Cage The Elephant'
        ? const ArtistInfo(
            name: 'Cage The Elephant',
            kind: 'group',
            place: 'Bowling Green, United States',
            since: '2006',
            summary: longText,
            pageUrl: 'https://fr.wikipedia.org/wiki/Cage_the_Elephant',
          )
        : null,
  );
  final grid = ValueNotifier(true);
  await tester.pumpWidget(
    AppScope(
      db: db,
      player: FakePlayer(),
      covers: Covers(
        cacheDir: Directory.systemTemp.createTempSync('ac'),
        embedded: (_) async => null,
      ),
      artists: store,
      artistGrid: grid,
      strings: Strings.of(const Locale('fr')),
      child: MaterialApp(theme: lafleurTheme(), home: const LibraryScreen()),
    ),
  );
  await settle(tester);
  await tester.tap(find.text('Artistes'));
  await settle(tester);
  return grid;
}

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
  }
}

void main() {
  setUpAll(loadFonts);

  testWidgets('Artistes : grille de photos avec nom et nombre de morceaux', (
    tester,
  ) async {
    await pump(tester);
    expect(find.byKey(const Key('artist-grid')), findsOneWidget);
    expect(find.text('Cage The Elephant'), findsOneWidget);
    expect(find.text('2 morceaux'), findsOneWidget);
  });

  testWidgets('bouton Liste : vue en liste, choix retenu', (tester) async {
    final grid = await pump(tester);
    await tester.tap(find.text('Liste'));
    await settle(tester);
    expect(find.byKey(const Key('artist-list')), findsOneWidget);
    expect(grid.value, isFalse);
  });

  testWidgets('page d’un artiste : ARTISTE, colonne ALBUM, résumé à droite', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(find.text('Cage The Elephant'));
    await settle(tester);
    final inList = find.descendant(
      of: find.byType(TrackList),
      matching: find.text('ARTISTE'),
    );
    expect(inList, findsOneWidget);
    expect(
      find.descendant(of: find.byType(TrackList), matching: find.text('ALBUM')),
      findsOneWidget,
    );
    expect(find.text('Indie Rock Playlist'), findsWidgets);
    expect(find.text('L’ARTISTE'), findsOneWidget);
    expect(
      find.text('Groupe · Bowling Green, United States · depuis 2006'),
      findsOneWidget,
    );
    expect(find.textContaining('Kentucky'), findsOneWidget);
    expect(find.text('Source : Wikipédia (CC BY-SA)'), findsOneWidget);
  });

  testWidgets('Lire la suite : le résumé s’ouvre, puis se referme', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(find.text('Cage The Elephant'));
    await settle(tester);
    await tester.tap(find.text('Lire la suite'));
    await tester.pump();
    expect(find.text('Réduire'), findsOneWidget);
    await tester.tap(find.text('Réduire'));
    await tester.pump();
    expect(find.text('Lire la suite'), findsOneWidget);
  });

  testWidgets('artiste introuvable : pas de résumé, pas de plantage', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(find.text('Kavinsky'));
    await settle(tester);
    expect(find.text('L’ARTISTE'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
