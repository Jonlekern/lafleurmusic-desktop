import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../library/models.dart' show sortKey;
import '../repair/musicbrainz.dart';

/// Ce qu'on sait d'un artiste : fiche MusicBrainz, résumé Wikipédia, photo (Wikipédia, sinon Deezer).
class ArtistInfo {
  const ArtistInfo({
    required this.name,
    this.kind,
    this.place,
    this.since,
    this.summary,
    this.pageUrl,
    this.photoUrl,
  });
  final String name;
  final String? kind; // group / person
  final String? place, since, summary, pageUrl, photoUrl;

  Map<String, Object?> toJson() => {
    'name': name,
    'kind': kind,
    'place': place,
    'since': since,
    'summary': summary,
    'pageUrl': pageUrl,
    'photoUrl': photoUrl,
  };

  factory ArtistInfo.fromJson(Map<String, Object?> j) => ArtistInfo(
    name: j['name'] as String? ?? '',
    kind: j['kind'] as String?,
    place: j['place'] as String?,
    since: j['since'] as String?,
    summary: j['summary'] as String?,
    pageUrl: j['pageUrl'] as String?,
    photoUrl: j['photoUrl'] as String?,
  );
}

/// Cherche un artiste : MusicBrainz → Wikidata (photo, article) → Wikipédia (résumé) ; photo Deezer en secours.
/// Gratuit et sans clé. Pas de réseau : RepairError(offline) pour réessayer plus tard.
class ArtistLookup {
  ArtistLookup(
    this._mb,
    this._http, {
    this.lang = 'fr',
    this.timeout = const Duration(seconds: 15),
  });
  final MusicBrainz _mb;
  final http.Client _http;
  final String lang;
  final Duration timeout;

  // « Zerb & The Chainsmokers & Ink », « X feat. Y » : on essaie aussi le premier nom
  static final _split = RegExp(
    r'\s*(?:&|,|\bfeat\.?|\bft\.?|\bvs\.?|\bx\b)\s*',
    caseSensitive: false,
  );

  Future<ArtistInfo?> find(String name) async {
    final first = name.split(_split).first.trim();
    final tries = [name, if (first.isNotEmpty && first != name) first];
    MbArtist? mb;
    var matched = name;
    for (final t in tries) {
      mb = await _mb.searchArtist(t);
      if (mb != null) {
        matched = t;
        break;
      }
    }
    String? photo, summary, page;
    final q = mb == null ? null : await _mb.wikidataId(mb.id);
    if (q != null && q.startsWith('Q')) {
      final w = await _getJson(
        Uri.https('www.wikidata.org', '/wiki/Special:EntityData/$q.json'),
      );
      final e = (w?['entities'] as Map?)?[q] as Map?;
      final file = _try(
        () =>
            (((e?['claims'] as Map?)?['P18'] as List?)?.first
                    as Map)['mainsnak']['datavalue']['value']
                as String?,
      );
      if (file != null) {
        photo =
            'https://commons.wikimedia.org/wiki/Special:FilePath/${Uri.encodeComponent(file)}?width=400';
      }
      final links = e?['sitelinks'] as Map?;
      for (final l in {lang, 'en'}) {
        final title = (links?['${l}wiki'] as Map?)?['title'] as String?;
        if (title == null) continue;
        final sum = await _getJson(
          Uri.https('$l.wikipedia.org', '/api/rest_v1/page/summary/$title'),
        );
        summary = sum?['extract'] as String?;
        page = _try(
          () => (sum?['content_urls'] as Map)['desktop']['page'] as String?,
        );
        if (summary != null && summary.isNotEmpty) break;
      }
    }
    photo ??= await _deezerPhoto(matched);
    if (mb == null && summary == null && photo == null) return null;
    return ArtistInfo(
      name: name,
      kind: mb?.kind,
      place: mb?.place,
      since: mb?.since,
      summary: summary,
      pageUrl: page,
      photoUrl: photo,
    );
  }

  Future<String?> _deezerPhoto(String name) async {
    final j = await _getJson(
      Uri.https('api.deezer.com', '/search/artist', {'q': name, 'limit': '5'}),
    );
    for (final a in (j?['data'] as List? ?? const [])) {
      if (a is! Map || sortKey(a['name'] as String? ?? '') != sortKey(name)) {
        continue;
      }
      final url = a['picture_xl'] as String?;
      // Deezer renvoie une image grise « sans photo » au chemin vide …/artist//…
      if (url == null || url.contains('/artist//')) return null;
      return url;
    }
    return null;
  }

  Future<Map<String, Object?>?> _getJson(Uri url) async {
    final http.Response r;
    try {
      r = await _http
          .get(url, headers: {'User-Agent': MusicBrainz.userAgent})
          .timeout(timeout);
    } on TimeoutException {
      throw const RepairError('timeout', offline: true);
    } on SocketException catch (e) {
      throw RepairError(e.message, offline: true);
    } on http.ClientException catch (e) {
      throw RepairError(e.message, offline: true);
    }
    if (r.statusCode != 200) return null;
    return _try(
      () =>
          (jsonDecode(utf8.decode(r.bodyBytes)) as Map).cast<String, Object?>(),
    );
  }

  static T? _try<T>(T? Function() read) {
    try {
      return read();
    } on Object {
      return null; // réponse inattendue : on fait sans
    }
  }
}
