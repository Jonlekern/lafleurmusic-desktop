import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_taglib/flutter_taglib.dart' show Picture;
import 'package:flutter_test/flutter_test.dart';
import 'package:lafleurmusic/library/db.dart';
import 'package:lafleurmusic/library/models.dart';
import 'package:lafleurmusic/library/track_ops.dart';
import 'package:lafleurmusic/tags/tag_reader.dart';
import 'package:lafleurmusic/tags/tag_writer.dart';

import '../platform/fake_trash.dart';
import '../tags/fake_io.dart';
import '../ui/fake_player.dart';

/// Faux tags : un fichier qui existe sur le disque est connu (tags vides) dès qu'on le lit.
class DiskIO extends FakeIO {
  @override
  Future<TagEdit?> snapshot(TagEdit e) async {
    if (!files.containsKey(e.path) && File(e.path).existsSync()) {
      files[e.path] = TagEdit(
        path: e.path,
        title: '',
        artist: '',
        album: '',
        trackNo: 0,
      );
    }
    return super.snapshot(e);
  }
}

class FakeReader implements TagReader {
  final tags = <String, TrackTags>{};
  @override
  Future<TrackTags?> read(String path) async =>
      File(path).existsSync() ? tags[path] ?? _blank : null;
  static const _blank = TrackTags(
    title: 'Remaster',
    artist: 'Divers',
    album: 'Autre',
    durationMs: 200000,
    hasCover: false,
  );
}

void main() {
  late Directory dir;
  late LibraryDb db;
  late DiskIO io;
  late TagWriter writer;
  late FakeTrash trash;
  late FakePlayer player;
  late FakeReader reader;
  late TrackOps ops;

  Track tr(int no, {String album = 'Studio'}) {
    final path = '${dir.path}/${no.toString().padLeft(2, '0')}.flac';
    File(path).writeAsStringSync('audio $no');
    return Track(
      path: path,
      folderId: 1,
      title: 'T$no',
      artist: 'J',
      album: album,
      trackNo: no,
      durationMs: 1000,
      hasCover: true,
      mtime: 1,
      size: 1,
    );
  }

  setUp(() async {
    dir = Directory.systemTemp.createTempSync('ops');
    db = LibraryDb(NativeDatabase.memory());
    io = DiskIO();
    writer = TagWriter(db, io);
    trash = FakeTrash();
    player = FakePlayer();
    reader = FakeReader();
    ops = TrackOps(db, writer, trash, player, reader: reader);
  });
  tearDown(() async {
    await db.close();
    dir.deleteSync(recursive: true);
  });

  Future<List<Track>> album() => db.watchAlbumTracks('Studio').first;

  Future<List<Track>> nine() async {
    final all = [for (var i = 1; i <= 9; i++) tr(i)];
    await db.upsertTracks(all);
    for (final t in all) {
      io.files[t.path] = TagEdit(
        path: t.path,
        title: t.title,
        artist: 'J',
        album: 'Studio',
        trackNo: t.trackNo,
      );
    }
    return all;
  }

  test(
    'supprimer le n° 5 : 6–9 deviennent 5–8, fichier à la Corbeille',
    () async {
      final all = await nine();
      final preview = await ops.renumberPreview([all[4]]);
      expect(
        [for (final p in preview) (p.$1.trackNo, p.$2)],
        [(6, 5), (7, 6), (8, 7), (9, 8)],
      );
      final r = await ops.delete([all[4]]);
      expect(r.ok, isTrue);
      expect(trash.trashed, [all[4].path]);
      final left = await album();
      expect(left.length, 8);
      expect([for (final t in left) t.trackNo], [1, 2, 3, 4, 5, 6, 7, 8]);
      expect(io.files[all[8].path]!.trackNo, 8);
      expect(player.calls, contains('removeTrack ${all[4].path}'));
    },
  );

  test('Corbeille refusée : rien ne change', () async {
    final all = await nine();
    trash.failOn.add(all[4].path);
    final r = await ops.delete([all[4]]);
    expect(r.ok, isFalse);
    expect(r.failedPath, all[4].path);
    expect((await album()).length, 9);
    expect(io.files[all[8].path]!.trackNo, 9);
    expect(player.calls, isEmpty);
  });

  test('remplacer : album / numéro / pochette de l’ancien, titre modifié, écoutes gardées', () async {
    final all = await nine();
    io.pictures[all[5].path] = [
      Picture(bytes: Uint8List.fromList([1, 2, 3]), mimeType: 'image/jpeg'),
    ];
    await db.addPlay(all[5].path, DateTime(2026));
    final src = File(
      '${Directory.systemTemp.path}/sunset-remaster-${DateTime.now().microsecondsSinceEpoch}.flac',
    )..writeAsStringSync('new');
    final fields = (await ops.readFields(src, all[5]))!;
    expect(
      (fields.title, fields.artist, fields.album, fields.trackNo),
      ('Remaster', 'Divers', 'Studio', 6),
    );
    final r = await ops.replace(
      all[5],
      src,
      fields.copyWith(title: 'Sunset Tape (Remaster)'),
    );
    expect(r.ok, isTrue);
    final copy = '${dir.path}/${src.uri.pathSegments.last}';
    expect(File(copy).existsSync(), isTrue);
    expect(src.existsSync(), isTrue); // l'original choisi n'est pas touché
    expect(io.files[copy]!.title, 'Sunset Tape (Remaster)');
    expect(io.files[copy]!.album, 'Studio');
    expect(io.files[copy]!.trackNo, 6);
    expect(io.pictures[copy]!.single.bytes, [1, 2, 3]);
    expect(trash.trashed, [all[5].path]);
    final top = await db.watchTop(10).first;
    expect(top.single.$1.path, copy);
    expect(player.calls, contains('replaceTrack ${all[5].path}'));
    src.deleteSync();
  });

  test('nom déjà pris dans le dossier → « nom (2) »', () async {
    final all = await nine();
    final src =
        File(
            '${Directory.systemTemp.path}/ops-src-${DateTime.now().microsecondsSinceEpoch}/01.flac',
          )
          ..createSync(recursive: true)
          ..writeAsStringSync('new');
    final r = await ops.replace(
      all[4],
      src,
      (await ops.readFields(src, all[4]))!,
    );
    expect(r.ok, isTrue);
    expect(File('${dir.path}/01 (2).flac').existsSync(), isTrue);
    expect(File(all[0].path).readAsStringSync(), 'audio 1');
    src.parent.deleteSync(recursive: true);
  });

  test('pas de l’audio → readFields null', () async {
    final all = await nine();
    final txt = File('${dir.path}/notes.txt')..writeAsStringSync('x');
    expect(await ops.readFields(txt, all[0]), isNull);
  });

  test('écriture des tags refusée : copie retirée, ancien jamais à la Corbeille', () async {
    final all = await nine();
    final src = File(
      '${Directory.systemTemp.path}/ro-${DateTime.now().microsecondsSinceEpoch}.flac',
    )..writeAsStringSync('n');
    io.readOnly.add('${dir.path}/${src.uri.pathSegments.last}');
    final r = await ops.replace(
      all[2],
      src,
      (await ops.readFields(src, all[2]))!,
    );
    expect(r.ok, isFalse);
    expect(
      File('${dir.path}/${src.uri.pathSegments.last}').existsSync(),
      isFalse,
    );
    expect(trash.trashed, isEmpty);
    expect((await album()).length, 9);
    src.deleteSync();
  });

  test('Modifier : titre, artiste, album, numéro écrits', () async {
    final all = await nine();
    final r = await ops.edit(
      all[0],
      const TrackFields(
        title: 'Ocean',
        artist: 'Johnny',
        album: 'Studio',
        trackNo: 1,
      ),
    );
    expect(r.ok, isTrue);
    expect(io.files[all[0].path]!.title, 'Ocean');
    expect(io.files[all[0].path]!.artist, 'Johnny');
  });

  test(
    'renumérotation limitée au dossier de l’album (même nom ailleurs : intact)',
    () async {
      final all = await nine();
      final other = Directory('${dir.path}/autre')..createSync();
      final far = Track(
        path: '${other.path}/07.flac',
        folderId: 1,
        title: 'Live 7',
        artist: 'X',
        album: 'Studio',
        trackNo: 7,
        durationMs: 1000,
        hasCover: false,
        mtime: 1,
        size: 1,
      );
      File(far.path).writeAsStringSync('x');
      await db.upsertTrack(far);
      io.files[far.path] = TagEdit(
        path: far.path,
        title: 'Live 7',
        artist: 'X',
        album: 'Studio',
        trackNo: 7,
      );
      final preview = await ops.renumberPreview([all[4]]);
      expect(preview.map((p) => p.$1.path), isNot(contains(far.path)));
      await ops.delete([all[4]]);
      expect(io.files[far.path]!.trackNo, 7);
    },
  );
}
