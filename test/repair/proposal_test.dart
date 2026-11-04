import 'package:flutter_test/flutter_test.dart';
import 'package:lafleurmusic/library/models.dart';
import 'package:lafleurmusic/repair/musicbrainz.dart';
import 'package:lafleurmusic/repair/proposal.dart';

Track t(String title, int? no) => Track(
  path: '/m/$title.flac',
  folderId: 1,
  title: title,
  artist: '',
  album: 'night drive',
  trackNo: no,
  durationMs: 1,
  hasCover: false,
  mtime: 1,
  size: 1,
);

const cand = ReleaseCandidate(
  id: 'rel-1',
  title: 'Night Drive',
  artist: 'Kavinsky',
  year: '2010',
  trackCount: 5,
);
const list = [
  (1, 'Pacific Coast Highway'),
  (2, 'Nightcall'),
  (3, 'Testarossa Autodrive'),
  (4, 'Grand Canyon'),
  (5, 'Roadgame'),
];

void main() {
  test('pistes associées par numéro, puis par titre proche', () {
    final p = Proposal.build(
      [t('track03', 3), t('nightcall (1)', null), t('roadgame', 9)],
      cand,
      list,
    );
    expect(p.rows.map((r) => r.after), [
      'Testarossa Autodrive',
      'Nightcall',
      'Roadgame',
    ]);
    expect(p.rows.map((r) => r.trackNo), [3, 2, 5]);
  });
  test('album et artiste proposés, seulement ce qui change est marqué', () {
    final p = Proposal.build([t('Testarossa Autodrive', 3)], cand, list);
    expect(
      (p.album.before, p.album.after, p.album.changed),
      ('night drive', 'Night Drive', true),
    );
    expect(p.artist.after, 'Kavinsky');
    expect(p.rows.single.changed, isFalse);
  });
  test('modifications pour les fichiers', () {
    final p = Proposal.build([t('track03', 3)], cand, list);
    final e = p.edits().single;
    expect(
      (e.title, e.artist, e.album, e.trackNo),
      ('Testarossa Autodrive', 'Kavinsky', 'Night Drive', 3),
    );
  });
  test('piste sans correspondance : titre gardé', () {
    final p = Proposal.build([t('bonus live', null)], cand, list);
    expect(p.rows.single.after, 'bonus live');
    expect(p.edits().single.title, isNull);
  });
}
