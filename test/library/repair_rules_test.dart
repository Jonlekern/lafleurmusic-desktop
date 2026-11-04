import 'package:flutter_test/flutter_test.dart';
import 'package:lafleurmusic/library/models.dart';
import 'package:lafleurmusic/library/repair_rules.dart';

Track t({
  String title = 'Ocean Drive',
  String artist = 'Johnny',
  bool cover = true,
  String path = '/m/01 Ocean Drive.flac',
}) => Track(
  path: path,
  folderId: 1,
  title: title,
  artist: artist,
  album: 'A',
  durationMs: 1,
  hasCover: cover,
  mtime: 1,
  size: 1,
);

void main() {
  test(
    'piste complète : rien à réparer',
    () => expect(needsRepair(t()), false),
  );
  test('sans pochette', () => expect(needsRepair(t(cover: false)), true));
  test('sans artiste', () => expect(needsRepair(t(artist: '')), true));
  test(
    'titre type track03',
    () => expect(needsRepair(t(title: 'track03')), true),
  );
  test(
    'titre type « 01 - x »',
    () => expect(needsRepair(t(title: '01 - Ocean Drive')), true),
  );
  test(
    'titre = nom du fichier',
    () => expect(needsRepair(t(title: '01 Ocean Drive')), true),
  );
}
