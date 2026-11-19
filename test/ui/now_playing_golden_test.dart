import 'dart:io';

import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lafleurmusic/app_scope.dart';
import 'package:lafleurmusic/l10n/strings.dart';
import 'package:lafleurmusic/library/covers.dart';
import 'package:lafleurmusic/library/db.dart';
import 'package:lafleurmusic/library/models.dart';
import 'package:lafleurmusic/player/equalizer.dart';
import 'package:lafleurmusic/player/player.dart';
import 'package:lafleurmusic/settings.dart';
import 'package:lafleurmusic/theme/colors.dart';
import 'package:lafleurmusic/theme/lafleur_theme.dart';
import 'package:lafleurmusic/ui/equalizer_panel.dart';
import 'package:lafleurmusic/ui/now_playing_screen.dart';
import 'package:lafleurmusic/ui/playback_card.dart';

import 'fake_player.dart';
import 'fonts.dart';

void main() {
  setUpAll(loadFonts);

  testWidgets('En cours, onglet Égaliseur', (tester) async {
    await _pump(tester, AppSettings()..nowTab = 1);
    await _golden('goldens/4-en-cours-egaliseur.png');
  });

  testWidgets('mode jour : En cours, onglet Égaliseur', (tester) async {
    LafleurPalette.current = LafleurPalette.day;
    addTearDown(() => LafleurPalette.current = LafleurPalette.night);
    await _pump(tester, AppSettings()..nowTab = 1);
    await _golden('goldens/4-en-cours-egaliseur-jour.png');
  });

  testWidgets('En cours, onglet À suivre (maquette file-attente)', (
    tester,
  ) async {
    await _pump(tester, AppSettings());
    await _golden('goldens/4b-en-cours-a-suivre.png');
  });

  testWidgets('onglets : À suivre d\'abord, le choix est retenu', (
    tester,
  ) async {
    final settings = AppSettings();
    var saved = 0;
    await _pump(tester, settings, save: () => saved++);
    // À suivre : la suite de l'album, pas d'égaliseur
    expect(find.text('T3'), findsWidgets);
    expect(find.byType(EqualizerPanel), findsNothing);
    expect(find.byType(PlaybackCard), findsNothing);
    await tester.tap(find.text('Égaliseur'));
    await tester.pump();
    expect(find.byType(EqualizerPanel), findsOneWidget);
    expect(settings.nowTab, 1);
    expect(saved, 1);
    await tester.tap(find.text('Lecture'));
    await tester.pump();
    expect(find.byType(PlaybackCard), findsOneWidget);
    expect(find.byType(EqualizerPanel), findsNothing);
    expect(settings.nowTab, 2);
  });
}

Future<void> _golden(String golden) =>
    expectLater(find.byType(NowPlayingScreen), matchesGoldenFile(golden));

Future<void> _pump(
  WidgetTester tester,
  AppSettings settings, {
  VoidCallback? save,
}) async {
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
  final tracks = [
    for (var i = 1; i <= 9; i++)
      Track(
        path: '/m/$i.flac',
        folderId: 1,
        title: i == 2 ? 'Lafleur Surf' : 'T$i',
        artist: 'LAFLEURSTUDIO',
        album: 'Studio Lafleur',
        trackNo: i,
        durationMs: 245000,
        hasCover: true,
        mtime: 1,
        size: 1,
      ),
  ];
  final player = FakePlayer();
  await player.playTracks(tracks, 1);
  player.current = PlayerState(
    track: tracks[1],
    position: const Duration(seconds: 93),
    duration: const Duration(seconds: 245),
    playing: true,
  );
  final eq = ValueNotifier(Equalizer.named('bass').copyWith(enabled: true));
  await tester.pumpWidget(
    AppScope(
      db: db,
      player: player,
      equalizer: eq,
      covers: Covers(
        cacheDir: Directory.systemTemp.createTempSync('np'),
        embedded: (_) async => null,
      ),
      strings: Strings.of(const Locale('fr')),
      settings: settings,
      saveSettings: save,
      child: MaterialApp(
        theme: lafleurTheme(LafleurPalette.current),
        home: const NowPlayingScreen(),
      ),
    ),
  );
  await tester.pump();
  await precacheAssets(tester, [
    'assets/fleur-tile.png',
    'assets/fleur.png',
    'assets/logo-texte-grand.png',
  ]);
  expect(find.text('2 sur 9 · Studio Lafleur'), findsOneWidget);
  expect(tester.takeException(), isNull);
}
