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
        child: MaterialApp(
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
}
