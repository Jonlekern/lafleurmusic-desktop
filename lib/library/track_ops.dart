import 'dart:io';

import 'package:path/path.dart' as p;

import '../platform/trash.dart';
import '../player/player.dart';
import '../tags/tag_reader.dart';
import '../tags/tag_writer.dart';
import 'db.dart';
import 'models.dart';
import 'scanner.dart';

/// Les champs modifiables d'un morceau (fenêtres Remplacer / Modifier).
class TrackFields {
  const TrackFields({
    required this.title,
    required this.artist,
    required this.album,
    this.trackNo,
  });
  final String title, artist, album;
  final int? trackNo;

  TrackFields copyWith({
    String? title,
    String? artist,
    String? album,
    int? trackNo,
  }) => TrackFields(
    title: title ?? this.title,
    artist: artist ?? this.artist,
    album: album ?? this.album,
    trackNo: trackNo ?? this.trackNo,
  );
}

class OpResult {
  const OpResult.ok() : ok = true, failedPath = null;
  const OpResult.failed(this.failedPath) : ok = false;
  final bool ok;
  final String? failedPath; // le fichier qui a refusé (message)
}

/// Supprimer, remplacer, modifier un morceau : fichier (Corbeille, jamais effacé), base, file de lecture, numéros.
class TrackOps {
  TrackOps(this.db, this.writer, this.trash, this.player, {TagReader? reader})
    : reader = reader ?? TagLibReader();
  final LibraryDb db;
  final TagWriter writer;
  final Trash trash;
  final PlayerController player;
  final TagReader reader;

  /// Les morceaux qui changent de numéro si on retire [removed], avec leur nouveau numéro (fenêtre 8b).
  Future<List<(Track, int)>> renumberPreview(List<Track> removed) async {
    final gone = {for (final t in removed) t.path};
    final out = <(Track, int)>[];
    // un album = même nom **et** même dossier (un autre « Greatest Hits » ailleurs n'est pas touché)
    for (final (album, dir) in {
      for (final t in removed) (t.album, p.dirname(t.path)),
    }) {
      final cut = [
        for (final t in removed)
          if (t.album == album && p.dirname(t.path) == dir && t.trackNo != null)
            t.trackNo!,
      ];
      for (final t in await db.watchAlbumTracks(album).first) {
        final no = t.trackNo;
        if (no == null || gone.contains(t.path) || p.dirname(t.path) != dir) {
          continue;
        }
        final shift = cut.where((c) => c < no).length;
        if (shift > 0) out.add((t, no - shift));
      }
    }
    return out;
  }

  /// Corbeille d'abord : si elle refuse, rien d'autre ne change pour ce morceau (ni pour les suivants).
  Future<OpResult> delete(List<Track> tracks) async {
    final done = <Track>[];
    String? failed;
    for (final t in tracks) {
      try {
        await trash.trash(t.path);
        done.add(t);
      } on FileSystemException {
        failed = t.path;
        break;
      }
    }
    if (done.isNotEmpty) {
      final renumber = await renumberPreview(done);
      for (final t in done) {
        await player.removeTrack(t.path);
      }
      await db.deletePaths([for (final t in done) t.path]);
      if (renumber.isNotEmpty) {
        final r = await writer.apply([
          for (final (t, no) in renumber) TagEdit(path: t.path, trackNo: no),
        ]);
        if (!r.ok) return OpResult.failed(r.failedPath);
      }
    }
    return failed == null ? const OpResult.ok() : OpResult.failed(failed);
  }

  /// Champs proposés pour remplacer [old] par [source] ; null si ce n'est pas un fichier audio lisible.
  Future<TrackFields?> readFields(File source, Track old) async {
    if (!Scanner.isMusic(source.path)) return null;
    final tags = await reader.read(source.path);
    if (tags == null) return null;
    return TrackFields(
      title: tags.title.trim().isEmpty
          ? p.basenameWithoutExtension(source.path)
          : tags.title,
      artist: tags.artist,
      album: old.album,
      trackNo: old.trackNo,
    );
  }

  /// Copie [source] dans le dossier de [old], y écrit [fields] et la pochette de l'ancien, puis l'ancien va à la Corbeille.
  Future<OpResult> replace(Track old, File source, TrackFields fields) async {
    final dest = _freePath(p.dirname(old.path), p.basename(source.path));
    Future<OpResult> undo(String failed) async {
      await db.deletePaths([dest]);
      try {
        File(dest).deleteSync();
      } on FileSystemException {
        // déjà absent
      }
      return OpResult.failed(failed);
    }

    try {
      source.copySync(dest);
    } on FileSystemException {
      return OpResult.failed(dest);
    }
    final tags = await reader.read(dest);
    if (tags == null) return undo(source.path);
    final st = File(dest).statSync();
    await db.upsertTrack(
      Track(
        path: dest,
        folderId: old.folderId,
        title: fields.title,
        artist: fields.artist,
        album: fields.album,
        genre: tags.genre,
        trackNo: fields.trackNo,
        durationMs: tags.durationMs,
        hasCover: old.hasCover,
        mtime: st.modified.millisecondsSinceEpoch,
        size: st.size,
      ),
    );
    final pics = (await writer.io.snapshot(
      TagEdit(path: old.path, pictures: const []),
    ))?.pictures;
    final w = await writer.apply([
      TagEdit(
        path: dest,
        title: fields.title,
        artist: fields.artist,
        album: fields.album,
        trackNo: fields.trackNo ?? 0,
        pictures: pics ?? const [],
      ),
    ], record: false);
    if (!w.ok) return undo(dest);
    try {
      await trash.trash(old.path);
    } on FileSystemException {
      return undo(old.path);
    }
    await db.movePlays(old.path, dest);
    await db.deletePaths([old.path]);
    final now = await db.trackByPath(dest);
    if (now != null) await player.replaceTrack(old.path, now);
    return const OpResult.ok();
  }

  /// Modifier… : titre, artiste, album, numéro (annulable par Cmd + Z).
  Future<OpResult> edit(Track t, TrackFields fields) async {
    final r = await writer.apply([
      TagEdit(
        path: t.path,
        title: fields.title,
        artist: fields.artist,
        album: fields.album,
        trackNo: fields.trackNo ?? 0,
      ),
    ]);
    return r.ok ? const OpResult.ok() : OpResult.failed(r.failedPath);
  }

  static String _freePath(String dir, String name) {
    var path = p.join(dir, name);
    final base = p.basenameWithoutExtension(name), ext = p.extension(name);
    for (var i = 2; File(path).existsSync(); i++) {
      path = p.join(dir, '$base ($i)$ext');
    }
    return path;
  }
}
