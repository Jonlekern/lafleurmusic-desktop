import 'dart:typed_data';

import '../library/models.dart';
import '../tags/tag_writer.dart';
import 'musicbrainz.dart';

class FieldChange {
  const FieldChange(this.before, this.after);
  final String before, after;
  bool get changed => before != after;
}

class TrackRow {
  const TrackRow({required this.track, required this.after, this.trackNo});
  final Track track;
  final String after;
  final int? trackNo;
  bool get changed =>
      after != track.title || (trackNo != null && trackNo != track.trackNo);
}

/// Proposition « Réparer » (maquette 5) : avant / après pour l'album, l'artiste et chaque morceau.
class Proposal {
  Proposal._(this.candidate, this.album, this.artist, this.rows);
  final ReleaseCandidate candidate;
  final FieldChange album, artist;
  final List<TrackRow> rows;
  Uint8List? cover; // pochette trouvée (Cover Art Archive)

  static String _norm(String s) => s
      .toLowerCase()
      .replaceAll(RegExp(r'\(\d+\)|\[\d+\]'), '')
      .replaceAll(RegExp(r'[^a-z0-9]+'), '');

  static Proposal build(
    List<Track> tracks,
    ReleaseCandidate c,
    List<(int, String)> list,
  ) {
    final byNo = {for (final x in list) x.$1: x.$2};
    final rows = <TrackRow>[];
    for (final t in tracks) {
      // 1) même titre (une fois nettoyé), 2) même numéro, 3) rien : on garde
      final same = list.where(
        (x) => _norm(x.$2) == _norm(t.title) && _norm(t.title).isNotEmpty,
      );
      if (same.isNotEmpty) {
        rows.add(
          TrackRow(track: t, after: same.first.$2, trackNo: same.first.$1),
        );
      } else if (t.trackNo != null && byNo.containsKey(t.trackNo)) {
        rows.add(
          TrackRow(track: t, after: byNo[t.trackNo]!, trackNo: t.trackNo),
        );
      } else {
        rows.add(TrackRow(track: t, after: t.title));
      }
    }
    final first = tracks.isEmpty ? null : tracks.first;
    return Proposal._(
      c,
      FieldChange(first?.album ?? '', c.title),
      FieldChange(first?.artist ?? '', c.artist),
      rows,
    );
  }

  List<TagEdit> edits() => [
    for (final r in rows)
      TagEdit(
        path: r.track.path,
        title: r.after != r.track.title ? r.after : null,
        artist: artist.after,
        album: album.after,
        trackNo: r.trackNo,
        cover: cover,
      ),
  ];
}
