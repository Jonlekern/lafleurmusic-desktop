import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../library/models.dart' show sortKey;

class ReleaseCandidate {
  const ReleaseCandidate({
    required this.id,
    required this.title,
    required this.artist,
    this.year,
    required this.trackCount,
  });
  final String id, title, artist;
  final String? year;
  final int trackCount;
}

class RepairError implements Exception {
  const RepairError(this.message, {this.offline = false, this.busy = false});
  final String message;
  final bool offline; // pas de réseau, ou pas de réponse à temps
  final bool busy; // MusicBrainz surchargé (503, 429) : réessayer plus tard
  @override
  String toString() => 'RepairError($message)';
}

/// MusicBrainz + Cover Art Archive : gratuits, sans clé ; 1 requête par seconde au plus, User-Agent obligatoire.
class MusicBrainz {
  MusicBrainz(
    this._http, {
    DateTime Function()? clock,
    Future<void> Function(Duration)? sleep,
    this.timeout = const Duration(seconds: 15),
  }) : _clock = clock ?? DateTime.now,
       _sleep = sleep ?? Future<void>.delayed;

  static const userAgent = 'LAFLEURMUSIC/0.1 ( https://github.com/Jonlekern )';
  final http.Client _http;
  final Duration timeout;
  final DateTime Function() _clock;
  final Future<void> Function(Duration) _sleep;
  DateTime? _last;

  Future<http.Response> _get(Uri url) async {
    final last = _last;
    if (last != null) {
      final wait = const Duration(seconds: 1) - _clock().difference(last);
      if (wait > Duration.zero) await _sleep(wait);
    }
    _last = _clock();
    try {
      return await _http
          .get(
            url,
            headers: {'User-Agent': userAgent, 'Accept': 'application/json'},
          )
          .timeout(timeout);
    } on TimeoutException {
      throw const RepairError('timeout', offline: true);
    } on SocketException catch (e) {
      throw RepairError(e.message, offline: true);
    } on http.ClientException catch (e) {
      throw RepairError(e.message, offline: true);
    }
  }

  Map<String, Object?> _json(http.Response r) {
    if (r.statusCode == 503 || r.statusCode == 429) {
      throw RepairError('MusicBrainz ${r.statusCode}', busy: true);
    }
    if (r.statusCode != 200) throw RepairError('MusicBrainz ${r.statusCode}');
    return _parse(
      () =>
          (jsonDecode(utf8.decode(r.bodyBytes)) as Map).cast<String, Object?>(),
    );
  }

  // réponse inattendue (page de connexion wifi, format changé) : une erreur propre, pas un plantage
  static T _parse<T>(T Function() read) {
    try {
      return read();
    } on FormatException {
      throw const RepairError('bad response');
    } on TypeError {
      throw const RepairError('bad response');
    }
  }

  static String _q(String s) => s.replaceAll('"', ' ').trim();

  Future<List<ReleaseCandidate>> searchRelease(
    String artist,
    String album,
  ) async {
    final query = [
      if (album.trim().isNotEmpty) 'release:"${_q(album)}"',
      if (artist.trim().isNotEmpty &&
          artist != 'Inconnu' &&
          artist != 'Unknown')
        'artist:"${_q(artist)}"',
    ].join(' AND ');
    final j = _json(
      await _get(
        Uri.https('musicbrainz.org', '/ws/2/release/', {
          'query': query,
          'fmt': 'json',
          'limit': '5',
        }),
      ),
    );
    return _parse(() => _candidates(j));
  }

  static List<ReleaseCandidate> _candidates(Map<String, Object?> j) {
    final list = (j['releases'] as List? ?? const []).cast<Map>();
    final out = [
      for (final r in list)
        (
          (r['score'] as num?)?.toInt() ?? 0,
          ReleaseCandidate(
            id: r['id'] as String,
            title: r['title'] as String? ?? '',
            artist: ((r['artist-credit'] as List?)?.cast<Map>() ?? const [])
                .map((a) => a['name'] as String? ?? '')
                .join(', '),
            year: (r['date'] as String?)?.split('-').first,
            trackCount: (r['track-count'] as num?)?.toInt() ?? 0,
          ),
        ),
    ]..sort((a, b) => b.$1.compareTo(a.$1));
    return [for (final x in out) x.$2];
  }

  Future<List<(int, String)>> tracklist(String releaseId) async {
    final j = _json(
      await _get(
        Uri.https('musicbrainz.org', '/ws/2/release/$releaseId', {
          'inc': 'recordings',
          'fmt': 'json',
        }),
      ),
    );
    return _parse(() => _tracks(j));
  }

  static List<(int, String)> _tracks(Map<String, Object?> j) {
    final out = <(int, String)>[];
    var n = 0;
    for (final m in (j['media'] as List? ?? const []).cast<Map>()) {
      for (final t in (m['tracks'] as List? ?? const []).cast<Map>()) {
        n++;
        out.add((n, t['title'] as String? ?? ''));
      }
    }
    return out;
  }

  Future<Uint8List?> cover(String releaseId) async {
    final r = await _get(
      Uri.https('coverartarchive.org', '/release/$releaseId/front-500'),
    );
    return r.statusCode == 200 && r.bodyBytes.isNotEmpty ? r.bodyBytes : null;
  }

  /// Fiche d'artiste dont le nom correspond (casse et accents ignorés), null sinon.
  Future<MbArtist?> searchArtist(String name) async {
    final j = _json(
      await _get(
        Uri.https('musicbrainz.org', '/ws/2/artist/', {
          'query': 'artist:"${_q(name)}"',
          'fmt': 'json',
          'limit': '5',
        }),
      ),
    );
    return _parse(() {
      for (final a in (j['artists'] as List? ?? const []).cast<Map>()) {
        if (sortKey(a['name'] as String? ?? '') != sortKey(name)) continue;
        final where = [
          (a['begin-area'] as Map?)?['name'] as String?,
          (a['area'] as Map?)?['name'] as String?,
        ].whereType<String>().toSet().toList();
        final begin = (a['life-span'] as Map?)?['begin'] as String?;
        return MbArtist(
          id: a['id'] as String,
          kind: switch (a['type']) {
            'Group' => 'group',
            'Person' => 'person',
            _ => null,
          },
          place: where.isEmpty ? null : where.join(', '),
          since: begin?.split('-').first,
        );
      }
      return null;
    });
  }

  /// Identifiant Wikidata (Q…) lié à l'artiste, s'il y en a un.
  Future<String?> wikidataId(String artistId) async {
    final j = _json(
      await _get(
        Uri.https('musicbrainz.org', '/ws/2/artist/$artistId', {
          'inc': 'url-rels',
          'fmt': 'json',
        }),
      ),
    );
    return _parse(() {
      for (final r in (j['relations'] as List? ?? const []).cast<Map>()) {
        if (r['type'] != 'wikidata') continue;
        final url = (r['url'] as Map?)?['resource'] as String? ?? '';
        return url.split('/').last;
      }
      return null;
    });
  }
}

class MbArtist {
  const MbArtist({required this.id, this.kind, this.place, this.since});
  final String id;
  final String? kind, place, since; // kind : group / person
}
