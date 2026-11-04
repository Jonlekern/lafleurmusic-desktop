import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/painting.dart' show FileImage;
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import '../library/cover_prepare.dart';
import '../library/models.dart' show sortKey;
import '../repair/musicbrainz.dart';
import 'artist_lookup.dart';

typedef FindArtist = Future<ArtistInfo?> Function(String name);

class ArtistEntry {
  const ArtistEntry({this.info, this.photo, this.userPhoto = false});
  final ArtistInfo? info;
  final File? photo; // carrée, JPEG
  final bool userPhoto; // photo glissée par toi : jamais remplacée
}

/// Photos et résumés d'artistes, cherchés tout seuls une fois puis gardés sur le disque.
/// Introuvable : on réessaie après 30 jours. Pas de réseau : au prochain lancement.
class ArtistStore {
  ArtistStore({
    required this.dir,
    this.find,
    http.Client? client,
    DateTime Function()? clock,
  }) : _http = client ?? http.Client(),
       _clock = clock ?? DateTime.now;
  final Directory dir;
  final FindArtist? find;
  final http.Client _http;
  final DateTime Function() _clock;
  static const retryAfter = Duration(days: 30);
  static const _skip = {
    '',
    'inconnu',
    'unknown',
    'divers',
    'various artists',
    'various',
  };

  final _memo = <String, Future<ArtistEntry>>{};
  final _changes = StreamController<String>.broadcast();
  Future<void> _queue = Future.value();

  /// Nom de l'artiste dont la photo vient de changer.
  Stream<String> get changes => _changes.stream;

  String _key(String name) =>
      sha1.convert(utf8.encode(sortKey(name.trim()))).toString();
  File _json(String name) => File(p.join(dir.path, '${_key(name)}.json'));
  File _jpg(String name) => File(p.join(dir.path, '${_key(name)}.jpg'));

  Future<ArtistEntry> get(String name) =>
      _memo.putIfAbsent(_key(name), () => _load(name));

  Future<void> setUserPhoto(String name, Uint8List jpg) async {
    await dir.create(recursive: true);
    final f = _jpg(name);
    await f.writeAsBytes(jpg);
    FileImage(f).evict();
    final old = await _read(name);
    await _write(name, found: true, user: true, info: old?.info);
    _memo[_key(name)] = Future.value(
      ArtistEntry(info: old?.info, photo: f, userPhoto: true),
    );
    _changes.add(name);
  }

  Future<ArtistEntry?> _read(String name) async {
    final f = _json(name);
    if (!await f.exists()) return null;
    try {
      final j = (jsonDecode(await f.readAsString()) as Map)
          .cast<String, Object?>();
      final found = j['found'] == true;
      final at = DateTime.fromMillisecondsSinceEpoch(
        (j['fetchedAt'] as num?)?.toInt() ?? 0,
      );
      final user = j['user'] == true;
      if (!user && !found && _clock().difference(at) >= retryAfter) {
        return null; // à redemander
      }
      final info = j['info'] is Map
          ? ArtistInfo.fromJson((j['info'] as Map).cast<String, Object?>())
          : null;
      final jpg = _jpg(name);
      return ArtistEntry(
        info: info,
        photo: await jpg.exists() ? jpg : null,
        userPhoto: user,
      );
    } on Object {
      return null; // fichier abîmé : on redemande
    }
  }

  Future<void> _write(
    String name, {
    required bool found,
    bool user = false,
    ArtistInfo? info,
  }) async {
    await dir.create(recursive: true);
    await _json(name).writeAsString(
      jsonEncode({
        'fetchedAt': _clock().millisecondsSinceEpoch,
        'found': found,
        'user': user,
        'info': info?.toJson(),
      }),
    );
  }

  Future<ArtistEntry> _load(String name) async {
    final cached = await _read(name);
    if (cached != null) return cached;
    final find = this.find;
    if (find == null || _skip.contains(sortKey(name.trim()))) {
      return const ArtistEntry();
    }
    // une recherche à la fois
    final done = Completer<ArtistEntry>();
    _queue = _queue.then((_) async {
      try {
        done.complete(await _fetch(find, name));
      } on Object catch (e, st) {
        done.completeError(e, st);
      }
    });
    try {
      return await done.future;
    } on RepairError {
      return const ArtistEntry(); // pas de réseau / service occupé : rien de gardé
    }
  }

  Future<ArtistEntry> _fetch(FindArtist find, String name) async {
    final info = await find(name);
    File? photo;
    final url = info?.photoUrl;
    if (url != null) {
      try {
        final r = await _http
            .get(Uri.parse(url), headers: {'User-Agent': MusicBrainz.userAgent})
            .timeout(const Duration(seconds: 20));
        final jpg = r.statusCode == 200
            ? await prepareCover(r.bodyBytes)
            : null;
        if (jpg != null) {
          await dir.create(recursive: true);
          photo = await _jpg(name).writeAsBytes(jpg);
        }
      } on Object {
        photo = null; // photo injoignable : on garde le reste
      }
    }
    await _write(name, found: info != null, info: info);
    return ArtistEntry(info: info, photo: photo);
  }
}
