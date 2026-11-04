import 'package:flutter_test/flutter_test.dart';
import 'package:lafleurmusic/library/models.dart';
import 'package:lafleurmusic/library/playlist_ops.dart';

List<Track> list(int n) => [
  for (var i = 1; i <= n; i++)
    Track(
      path: '/m/$i.flac',
      folderId: 1,
      title: 'T$i',
      artist: 'A',
      album: 'Studio',
      trackNo: i,
      durationMs: 1,
      hasCover: true,
      mtime: 1,
      size: 1,
    ),
];

void main() {
  test('le 5e passe en tête : 5 numéros réécrits', () {
    final e = reorderEdits(list(9), 4, 0);
    expect(e.length, 5);
    expect(
      {for (final x in e) x.path: x.trackNo},
      {
        '/m/5.flac': 1,
        '/m/1.flac': 2,
        '/m/2.flac': 3,
        '/m/3.flac': 4,
        '/m/4.flac': 5,
      },
    );
  });
  test('même place : aucune écriture', () {
    expect(reorderEdits(list(9), 3, 3), isEmpty);
  });
  test(
    'vers le bas (index de destination « après » comme ReorderableListView)',
    () {
      final e = reorderEdits(list(4), 0, 4); // le 1er tout en bas
      expect(
        {for (final x in e) x.path: x.trackNo},
        {'/m/2.flac': 1, '/m/3.flac': 2, '/m/4.flac': 3, '/m/1.flac': 4},
      );
    },
  );
  test('numéros manquants comblés', () {
    final l = list(3);
    final noNumbers = [
      for (final t in l)
        Track(
          path: t.path,
          folderId: 1,
          title: t.title,
          artist: 'A',
          album: 'S',
          durationMs: 1,
          hasCover: true,
          mtime: 1,
          size: 1,
        ),
    ];
    expect(reorderEdits(noNumbers, 2, 2).length, 3);
  });
  test('vers une autre playlist : album changé', () {
    final e = moveToPlaylistEdit(list(1).single, 'Night Drive');
    expect(e.album, 'Night Drive');
    expect(e.path, '/m/1.flac');
    expect(e.trackNo, isNull);
  });
}
