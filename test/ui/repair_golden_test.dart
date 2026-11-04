import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image/image.dart' as img;
import 'package:lafleurmusic/app_scope.dart';
import 'package:lafleurmusic/l10n/strings.dart';
import 'package:lafleurmusic/library/covers.dart';
import 'package:lafleurmusic/library/db.dart';
import 'package:lafleurmusic/library/models.dart';
import 'package:lafleurmusic/repair/musicbrainz.dart';
import 'package:lafleurmusic/tags/tag_writer.dart';
import 'package:lafleurmusic/theme/lafleur_theme.dart';
import 'package:lafleurmusic/ui/repair_dialog.dart';

import '../tags/fake_io.dart';
import 'fake_player.dart';
import 'fonts.dart';

String fx(String n) => File('test/repair/fixtures/$n').readAsStringSync();

final tracks = [
  for (final (no, title) in [(3, 'track03'), (5, 'nightcall (1)')])
    Track(
      path: '/m/nd/$no.flac',
      folderId: 1,
      title: title,
      artist: '',
      album: 'night drive',
      trackNo: no,
      durationMs: 1,
      hasCover: false,
      mtime: 1,
      size: 1,
    ),
];

Future<FakeIO> pump(
  WidgetTester tester,
  Future<http.Response> Function(http.Request) handler,
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
  final io = FakeIO();
  for (final t in tracks) {
    io.files[t.path] = TagEdit(
      path: t.path,
      title: t.title,
      artist: '',
      album: t.album,
      trackNo: t.trackNo,
    );
  }
  await tester.pumpWidget(
    AppScope(
      db: db,
      player: FakePlayer(),
      writer: TagWriter(db, io),
      musicbrainz: MusicBrainz(MockClient(handler), sleep: (_) async {}),
      covers: Covers(
        cacheDir: Directory.systemTemp.createTempSync('rp'),
        embedded: (_) async => null,
      ),
      strings: Strings.of(const Locale('fr')),
      child: MaterialApp(
        theme: lafleurTheme(),
        home: Scaffold(
          body: Center(child: RepairDialog(tracks: tracks)),
        ),
      ),
    ),
  );
  for (var i = 0; i < 6; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 30)),
    );
    await tester.pump();
  }
  return io;
}

Future<http.Response> ok(http.Request r) async {
  if (r.url.host == 'coverartarchive.org') {
    return http.Response.bytes(
      Uint8List.fromList(
        img.encodeJpg(
          img.Image(width: 200, height: 200)..clear(img.ColorRgb8(110, 30, 34)),
        ),
      ),
      200,
    );
  }
  return http.Response(
    r.url.path.endsWith('/release/') ? fx('search.json') : fx('release.json'),
    200,
  );
}

void main() {
  setUpAll(loadFonts);

  testWidgets('avant / après comme la maquette 5', (tester) async {
    await pump(tester, ok);
    expect(find.text('Testarossa Autodrive'), findsOneWidget);
    expect(find.text('Kavinsky'), findsOneWidget);
    await expectLater(
      find.byType(RepairDialog),
      matchesGoldenFile('goldens/5-reparer.png'),
    );
  });

  testWidgets('Enregistrer : tags et pochette écrits dans les fichiers', (
    tester,
  ) async {
    final io = await pump(tester, ok);
    await tester.tap(find.text('Enregistrer dans 2 morceaux'));
    for (var i = 0; i < 4; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }
    expect(io.files['/m/nd/3.flac']!.title, 'Testarossa Autodrive');
    expect(io.files['/m/nd/5.flac']!.title, 'Nightcall');
    expect(io.files['/m/nd/5.flac']!.artist, 'Kavinsky');
    expect(io.pictures['/m/nd/5.flac'], isNotEmpty);
  });

  testWidgets('rien trouvé : message, rien de modifié', (tester) async {
    final io = await pump(
      tester,
      (_) async => http.Response(fx('empty.json'), 200),
    );
    expect(find.textContaining('Rien trouvé'), findsOneWidget);
    expect(io.files['/m/nd/3.flac']!.title, 'track03');
  });

  testWidgets('pas de réseau : message', (tester) async {
    await pump(tester, (_) async => throw const SocketException('off'));
    expect(find.textContaining('Pas de connexion'), findsOneWidget);
  });

  testWidgets(
    'pochette injoignable : la proposition des titres reste affichée',
    (tester) async {
      await pump(tester, (r) async {
        if (r.url.host == 'coverartarchive.org') {
          throw const SocketException('off');
        }
        return ok(r);
      });
      expect(find.text('Testarossa Autodrive'), findsOneWidget);
    },
  );

  testWidgets(
    'MusicBrainz occupé (503) : réessaie plus tard, pas « rien trouvé »',
    (tester) async {
      await pump(tester, (_) async => http.Response('busy', 503));
      expect(find.textContaining('réessaie'), findsOneWidget);
      expect(find.textContaining('Rien trouvé'), findsNothing);
    },
  );

  testWidgets(
    'réponse illisible (portail wifi) : un message, plus de recherche sans fin',
    (tester) async {
      await pump(tester, (_) async => http.Response('<html>login</html>', 200));
      expect(find.text('Je cherche…'), findsNothing);
      expect(find.textContaining('Rien trouvé'), findsOneWidget);
    },
  );
}
