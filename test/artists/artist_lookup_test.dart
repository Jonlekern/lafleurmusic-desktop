import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lafleurmusic/artists/artist_lookup.dart';
import 'package:lafleurmusic/repair/musicbrainz.dart';

String fx(String n) => File('test/artists/fixtures/$n').readAsStringSync();
http.Response js(String n) => http.Response.bytes(
  File('test/artists/fixtures/$n').readAsBytesSync(),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

void main() {
  late List<Uri> seen;
  late List<String?> agents;

  ArtistLookup lookup(Future<http.Response> Function(Uri) route) {
    seen = [];
    agents = [];
    final client = MockClient((r) {
      seen.add(r.url);
      agents.add(r.headers['User-Agent']);
      return route(r.url);
    });
    return ArtistLookup(MusicBrainz(client, sleep: (_) async {}), client);
  }

  Future<http.Response> cage(Uri u) async {
    if (u.host == 'musicbrainz.org' && u.path == '/ws/2/artist/') {
      return js('mb_artist_search.json');
    }
    if (u.host == 'musicbrainz.org') {
      return js('mb_artist.json');
    }
    if (u.host == 'www.wikidata.org') {
      return js('wikidata.json');
    }
    if (u.host == 'fr.wikipedia.org') {
      return js('wiki_summary.json');
    }
    return http.Response('', 404);
  }

  test(
    'artiste trouvé : genre, lieu, depuis, résumé, photo Wikipédia',
    () async {
      final i = (await lookup(cage).find('Cage The Elephant'))!;
      expect(i.kind, 'group');
      expect(i.place, 'Bowling Green, United States');
      expect(i.since, '2006');
      expect(i.summary, startsWith('Texte d'));
      expect(i.pageUrl, 'https://fr.wikipedia.org/wiki/Cage_the_Elephant');
      expect(
        i.photoUrl,
        'https://commons.wikimedia.org/wiki/Special:FilePath/Cage%20the%20Elephant%202019.jpg?width=400',
      );
      expect(seen.where((u) => u.host == 'api.deezer.com'), isEmpty);
      expect(agents.every((a) => a == MusicBrainz.userAgent), isTrue);
    },
  );

  test(
    'pas d’article en français ni de photo Wikipédia : anglais + photo Deezer',
    () async {
      final i = (await lookup((u) async {
        if (u.host == 'musicbrainz.org' && u.path == '/ws/2/artist/') {
          return http.Response(
            '{"artists":[{"id":"z","type":"Group","score":100,"name":"Some Band"}]}',
            200,
          );
        }
        if (u.host == 'musicbrainz.org') {
          return http.Response(
            '{"id":"z","relations":[{"type":"wikidata","url":{"resource":"https://www.wikidata.org/wiki/Q9"}}]}',
            200,
          );
        }
        if (u.host == 'www.wikidata.org') {
          return js('wikidata_nophoto.json');
        }
        if (u.host == 'en.wikipedia.org') {
          return js('wiki_summary.json');
        }
        if (u.host == 'api.deezer.com') {
          return js('deezer_search.json');
        }
        return http.Response('', 404);
      }).find('Some Band'))!;
      expect(seen.any((u) => u.host == 'en.wikipedia.org'), isTrue);
      expect(i.summary, isNotNull);
      expect(i.photoUrl, contains('dzcdn.net/images/artist/abc123/'));
    },
  );

  test('photo Deezer par défaut (vide) : pas de photo', () async {
    final i = (await lookup((u) async {
      if (u.host == 'musicbrainz.org') {
        return http.Response('{"artists":[]}', 200);
      }
      if (u.host == 'api.deezer.com') {
        return js('deezer_nopicture.json');
      }
      return http.Response('', 404);
    }).find('Some Band'));
    expect(i?.photoUrl, isNull);
  });

  test('inconnu partout : null', () async {
    final i = await lookup((u) async {
      if (u.host == 'musicbrainz.org') {
        return http.Response(
          '{"artists":[{"id":"q","score":90,"name":"Someone Else"}]}',
          200,
        );
      }
      if (u.host == 'api.deezer.com') {
        return http.Response('{"data":[]}', 200);
      }
      return http.Response('', 404);
    }).find('Personne Du Tout');
    expect(i, isNull);
  });

  test(
    '« Zerb & The Chainsmokers & Ink » : on cherche aussi « Zerb »',
    () async {
      await lookup((u) async {
        if (u.host == 'musicbrainz.org') {
          return http.Response('{"artists":[]}', 200);
        }
        if (u.host == 'api.deezer.com') {
          return http.Response('{"data":[]}', 200);
        }
        return http.Response('', 404);
      }).find('Zerb & The Chainsmokers & Ink');
      final queries = seen
          .where((u) => u.path == '/ws/2/artist/')
          .map((u) => u.queryParameters['query'])
          .toList();
      expect(queries.last, contains('Zerb'));
      expect(queries.last, isNot(contains('Chainsmokers')));
    },
  );

  test(
    'pas de réseau : RepairError.offline (pour réessayer plus tard)',
    () async {
      final l = lookup((_) async => throw const SocketException('off'));
      await expectLater(
        l.find('Kavinsky'),
        throwsA(isA<RepairError>().having((e) => e.offline, 'offline', isTrue)),
      );
    },
  );

  test('ArtistInfo : aller-retour JSON', () {
    const i = ArtistInfo(
      name: 'A',
      kind: 'person',
      place: 'Paris',
      since: '1990',
      summary: 's',
      pageUrl: 'p',
      photoUrl: 'u',
    );
    final b = ArtistInfo.fromJson(i.toJson());
    expect(
      [b.name, b.kind, b.place, b.since, b.summary, b.pageUrl, b.photoUrl],
      ['A', 'person', 'Paris', '1990', 's', 'p', 'u'],
    );
  });
}
