import 'dart:io';

import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lafleurmusic/app_scope.dart';
import 'package:lafleurmusic/l10n/strings.dart';
import 'package:lafleurmusic/library/covers.dart';
import 'package:lafleurmusic/library/db.dart';
import 'package:lafleurmusic/player/player.dart';
import 'package:lafleurmusic/theme/lafleur_theme.dart';
import 'package:lafleurmusic/ui/player_bar.dart';

import 'fake_player.dart';
import 'fonts.dart';

void main() {
  late FakePlayer player;

  Future<Rect> pump(WidgetTester tester) async {
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
    player = FakePlayer();
    player.current = const PlayerState(
      position: Duration.zero,
      duration: Duration(seconds: 200),
      playing: true,
    );
    await tester.pumpWidget(
      AppScope(
        db: db,
        player: player,
        covers: Covers(
          cacheDir: Directory.systemTemp.createTempSync('pb'),
          embedded: (_) async => null,
        ),
        strings: Strings.of(const Locale('fr')),
        child: MaterialApp(
          theme: lafleurTheme(),
          home: const Scaffold(
            body: Align(alignment: Alignment.bottomCenter, child: PlayerBar()),
          ),
        ),
      ),
    );
    await tester.pump();
    return tester.getRect(find.byKey(const Key('progress')));
  }

  testWidgets('clic un peu au-dessus de la ligne : on y va quand même', (
    tester,
  ) async {
    final r = await pump(tester);
    // 9 px au-dessus du milieu de la ligne : hors de la ligne (5 px) et du rond (13 px)
    await tester.tapAt(Offset(r.left + r.width / 2, r.center.dy - 9));
    expect(player.lastSeek?.inSeconds, closeTo(100, 2));
  });

  testWidgets('clic un peu en dessous de la ligne : on y va aussi', (
    tester,
  ) async {
    final r = await pump(tester);
    await tester.tapAt(Offset(r.left + r.width / 4, r.center.dy + 9));
    expect(player.lastSeek?.inSeconds, closeTo(50, 2));
  });

  testWidgets('on peut glisser le rond : la lecture va là où on lâche', (
    tester,
  ) async {
    final r = await pump(tester);
    final g = await tester.startGesture(Offset(r.left + 2, r.center.dy));
    await g.moveTo(Offset(r.left + r.width * 0.4, r.center.dy));
    await g.moveTo(Offset(r.left + r.width * 0.75, r.center.dy - 6));
    await g.up();
    await tester.pump();
    expect(player.lastSeek?.inSeconds, closeTo(150, 2));
  });
}
