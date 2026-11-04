import '../tags/tag_writer.dart';
import 'models.dart';

/// Déplacer un morceau dans une playlist : numéros 1..n réécrits, seulement ceux qui changent.
/// [to] suit la convention de ReorderableListView (index avant retrait).
List<TagEdit> reorderEdits(List<Track> tracks, int from, int to) {
  final order = List.of(tracks);
  final moved = order.removeAt(from);
  order.insert(to > from ? to - 1 : to, moved);
  return [
    for (var i = 0; i < order.length; i++)
      if (order[i].trackNo != i + 1)
        TagEdit(path: order[i].path, trackNo: i + 1),
  ];
}

/// Glisser un morceau sur une autre playlist = changer son album (le fichier reste dans son dossier).
TagEdit moveToPlaylistEdit(Track t, String album) =>
    TagEdit(path: t.path, album: album);
