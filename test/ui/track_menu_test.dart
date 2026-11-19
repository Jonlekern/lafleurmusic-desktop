import 'dart:io';

import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lafleurmusic/app_scope.dart';
import 'package:lafleurmusic/l10n/strings.dart';
import 'package:lafleurmusic/library/covers.dart';
import 'package:lafleurmusic/library/db.dart';
import 'package:lafleurmusic/library/models.dart';
import 'package:lafleurmusic/library/track_ops.dart';
import 'package:lafleurmusic/platform/trash.dart';
import 'package:lafleurmusic/player/player.dart';
import 'package:lafleurmusic/tags/tag_reader.dart';
import 'package:lafleurmusic/tags/tag_writer.dart';
import 'package:lafleurmusic/theme/lafleur_theme.dart';
import 'package:lafleurmusic/ui/track_list.dart';
import 'package:lafleurmusic/ui/track_menu.dart';

import '../platform/fake_trash.dart';
import '../tags/fake_io.dart';
import 'fake_player.dart';
import 'fonts.dart';

Track t(String title, int no) => Track(
  path: '/m/Studio Lafleur/$no $title.flac',
  folderId: 1,
  title: title,
  artist: 'Divers',
  album: 'Studio Lafleur',
  trackNo: no,
  durationMs: 240000,
  hasCover: true,
  mtime: 1,
  size: 1,
);

final album = [
  for (final (i, n) in [
    'Ocean Drive',
    'Lafleur Surf',
    'Golden Hour',
    'Night Swim',
    'Paradise Club',
    'Sunset Tape',
    'Palm Waves',
    'Late Bloom',
    'Studio 9',
  ].indexed)
    t(n, i + 1),
];

/// TrackOps sans fichiers : retient les appels.
class FakeOps implements TrackOps {
  FakeOps(this.db, this.player);
  @override
  final LibraryDb db;
  @override
  final PlayerController player;
  @override
  TagWriter get writer => throw UnimplementedError();
  @override
  Trash get trash => FakeTrash();
  @override
  TagReader get reader => throw UnimplementedError();
  final calls = <String>[];
  TrackFields? lastFields;
  bool fail = false;

  @override
  Future<List<(Track, int)>> renumberPreview(List<Track> removed) async => [
    for (final x in album)
      if (x.trackNo! > removed.single.trackNo!) (x, x.trackNo! - 1),
  ];
  @override
  Future<OpResult> delete(List<Track> tracks) async {
    calls.add('delete ${tracks.single.title}');
    return fail ? OpResult.failed(tracks.single.path) : const OpResult.ok();
  }

  @override
  Future<TrackFields?> readFields(File source, Track old) async =>
      source.path.endsWith('.txt')
      ? null
      : TrackFields(
          title: 'Sunset Tape (Remaster)',
          artist: 'Divers',
          album: old.album,
          trackNo: old.trackNo,
        );
  @override
  Future<OpResult> replace(Track old, File source, TrackFields fields) async {
    calls.add('replace ${old.title} ${source.path}');
    lastFields = fields;
    return const OpResult.ok();
  }

  @override
  Future<OpResult> edit(Track t, TrackFields fields) async {
    calls.add('edit ${t.title}');
    lastFields = fields;
    return const OpResult.ok();
  }
}

late FakePlayer player;
late FakeOps ops;

Future<void> pump(WidgetTester tester, {bool writable = true}) async {
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
  await tester.runAsync(() => db.upsertTracks(album));
  player = FakePlayer();
  ops = FakeOps(db, player);
  await tester.pumpWidget(
    AppScope(
      db: db,
      player: player,
      covers: Covers(
        cacheDir: Directory.systemTemp.createTempSync('c'),
        embedded: (_) async => null,
      ),
      strings: Strings.of(const Locale('fr')),
      writer: writable ? TagWriter(db, FakeIO()) : null,
      ops: writable ? ops : null,
      pickAudio: () async => File('/tmp/sunset-tape-remaster.flac'),
      child: MaterialApp(
        theme: lafleurTheme(),
        home: Scaffold(
          body: TrackList(
            title: 'Studio Lafleur',
            tracks: album,
            renamable: true,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

Future<void> rightClick(WidgetTester tester, String text) async {
  final g = await tester.startGesture(
    tester.getCenter(find.text(text)),
    kind: PointerDeviceKind.mouse,
    buttons: kSecondaryMouseButton,
  );
  await g.up();
  await tester.pumpAndSettle();
}

/// Laisse passer les requêtes de la base (hors horloge simulée), puis redessine.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 3; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 30)),
    );
    await tester.pumpAndSettle();
  }
}

void main() {
  testWidgets('clic droit : les 6 entrées, Lire ensuite → playNext', (
    tester,
  ) async {
    await pump(tester);
    await rightClick(tester, 'Sunset Tape');
    for (final e in [
      'Lire ensuite',
      'Ajouter à la file',
      'Modifier…',
      'Remplacer par…',
      'Supprimer le morceau…',
    ]) {
      expect(find.text(e), findsOneWidget, reason: e);
    }
    await tester.tap(find.text('Lire ensuite'));
    await tester.pumpAndSettle();
    expect(player.calls, ['playNext']);
    expect(player.lastAdded!.single.title, 'Sunset Tape');
  });

  testWidgets('Ajouter à la file → enqueue', (tester) async {
    await pump(tester);
    await rightClick(tester, 'Sunset Tape');
    await tester.tap(find.text('Ajouter à la file'));
    await tester.pumpAndSettle();
    expect(player.calls, ['enqueue']);
  });

  testWidgets(
    'Supprimer : la fenêtre montre la renumérotation, Annuler ne fait rien',
    (tester) async {
      await pump(tester);
      await rightClick(tester, 'Sunset Tape');
      await tester.tap(find.text('Supprimer le morceau…'));
      await settle(tester);
      expect(find.text('Supprimer « Sunset Tape » ?'), findsOneWidget);
      expect(find.textContaining('7 Palm Waves → 6'), findsOneWidget);
      expect(
        find.textContaining("L'album passe à 8 morceaux."),
        findsOneWidget,
      );
      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();
      expect(ops.calls, isEmpty);
      await rightClick(tester, 'Sunset Tape');
      await tester.tap(find.text('Supprimer le morceau…'));
      await settle(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Supprimer'));
      await settle(tester);
      expect(ops.calls, ['delete Sunset Tape']);
    },
  );

  testWidgets('Corbeille refusée → message', (tester) async {
    await pump(tester);
    ops.fail = true;
    await rightClick(tester, 'Sunset Tape');
    await tester.tap(find.text('Supprimer le morceau…'));
    await settle(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Supprimer'));
    await settle(tester);
    expect(
      find.text('Impossible de mettre « 6 Sunset Tape.flac » à la Corbeille'),
      findsOneWidget,
    );
  });

  testWidgets('Remplacer : champs pré-remplis, titre modifié envoyé', (
    tester,
  ) async {
    await pump(tester);
    await rightClick(tester, 'Sunset Tape');
    await tester.tap(find.text('Remplacer par…'));
    await tester.pumpAndSettle();
    expect(find.text('Remplacer « Sunset Tape »'), findsOneWidget);
    expect(find.textContaining('sunset-tape-remaster.flac'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Studio Lafleur'), findsOneWidget);
    expect(find.widgetWithText(TextField, '6'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextField, 'Sunset Tape (Remaster)'),
      'Sunset Tape (Live)',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Remplacer'));
    await tester.pumpAndSettle();
    expect(ops.calls, ['replace Sunset Tape /tmp/sunset-tape-remaster.flac']);
    expect(ops.lastFields!.title, 'Sunset Tape (Live)');
    expect(ops.lastFields!.trackNo, 6);
  });

  testWidgets('Modifier : même fenêtre sans nouveau fichier', (tester) async {
    await pump(tester);
    await rightClick(tester, 'Ocean Drive');
    await tester.tap(find.text('Modifier…'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Nouveau fichier'), findsNothing);
    await tester.enterText(find.widgetWithText(TextField, 'Divers'), 'Johnny');
    await tester.tap(find.widgetWithText(FilledButton, 'Enregistrer'));
    await tester.pumpAndSettle();
    expect(ops.calls, ['edit Ocean Drive']);
    expect(ops.lastFields!.artist, 'Johnny');
  });

  testWidgets('lecture seule : seulement Lire ensuite et Ajouter à la file', (
    tester,
  ) async {
    await pump(tester, writable: false);
    await rightClick(tester, 'Sunset Tape');
    expect(find.text('Lire ensuite'), findsOneWidget);
    expect(find.text('Ajouter à la file'), findsOneWidget);
    expect(find.text('Supprimer le morceau…'), findsNothing);
    expect(find.text('Remplacer par…'), findsNothing);
  });

  testWidgets('clic droit sur un album : tous ses morceaux à la file', (
    tester,
  ) async {
    await pump(tester);
    final ctx = tester.element(find.text('Ocean Drive'));
    final done = showTracksMenu(ctx, const Offset(300, 300), () async => album);
    await tester.pumpAndSettle();
    expect(find.text('Supprimer le morceau…'), findsNothing);
    await tester.tap(find.text('Ajouter à la file'));
    await tester.pumpAndSettle();
    await done;
    expect(player.calls, ['enqueue']);
    expect(player.lastAdded!.length, 9);
  });

  group('deux doigts vers la gauche (trackpad) → Lire ensuite', () {
    Future<void> swipe(WidgetTester tester, String text, Offset pan) async {
      final p = TestPointer(9, PointerDeviceKind.trackpad);
      final at = tester.getCenter(find.text(text));
      await tester.sendEventToBinding(p.panZoomStart(at));
      for (var i = 1; i <= 10; i++) {
        await tester.sendEventToBinding(
          p.panZoomUpdate(at, pan: pan * (i / 10)),
        );
        await tester.pump(const Duration(milliseconds: 16));
      }
      await tester.sendEventToBinding(p.panZoomEnd());
      await tester.pumpAndSettle();
    }

    testWidgets('assez loin : le morceau passe en Lire ensuite', (
      tester,
    ) async {
      await pump(tester);
      final p = TestPointer(9, PointerDeviceKind.trackpad);
      final at = tester.getCenter(find.text('Sunset Tape'));
      await tester.sendEventToBinding(p.panZoomStart(at));
      await tester.sendEventToBinding(
        p.panZoomUpdate(at, pan: const Offset(-120, 0)),
      );
      await tester.pump();
      expect(find.text('← Lire ensuite'), findsOneWidget); // le bandeau rose
      await tester.sendEventToBinding(p.panZoomEnd());
      await tester.pumpAndSettle();
      expect(player.calls, ['playNext']);
      expect(player.lastAdded!.single.title, 'Sunset Tape');
      expect(find.text('← Lire ensuite'), findsNothing); // la ligne revient
    });

    testWidgets('trop court : rien', (tester) async {
      await pump(tester);
      await swipe(tester, 'Sunset Tape', const Offset(-40, 0));
      expect(player.calls, isEmpty);
    });

    testWidgets('défilement vertical ou vers la droite : rien', (tester) async {
      await pump(tester);
      await swipe(tester, 'Sunset Tape', const Offset(-20, -200));
      await swipe(tester, 'Sunset Tape', const Offset(150, 0));
      expect(player.calls, isEmpty);
    });
  });
}
