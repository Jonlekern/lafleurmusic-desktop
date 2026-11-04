import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lafleurmusic/repair/musicbrainz.dart';

String fx(String name) => File('test/repair/fixtures/$name').readAsStringSync();

void main() {
  late List<http.Request> seen;
  late List<Duration> waits;

  MusicBrainz mb(Future<http.Response> Function(http.Request) handler) {
    seen = [];
    waits = [];
    var now = DateTime(2026);
    return MusicBrainz(
      MockClient((r) {
        seen.add(r);
        return handler(r);
      }),
      clock: () => now,
      sleep: (d) async {
        waits.add(d);
        now = now.add(d);
      },
    );
  }

  test(
    'recherche : candidats triés par score, avec artiste et année',
    () async {
      final m = mb(
        (_) async => http.Response(
          fx('search.json'),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        ),
      );
      final c = await m.searchRelease('Inconnu', 'night drive');
      expect(c.map((x) => x.title), ['Night Drive', 'Night Drive (Remixes)']);
      expect(c.first.artist, 'Kavinsky');
      expect(c.first.year, '2010');
      expect(seen.single.url.host, 'musicbrainz.org');
      expect(seen.single.headers['User-Agent'], startsWith('LAFLEURMUSIC/'));
      expect(seen.single.url.queryParameters['fmt'], 'json');
    },
  );

  test('liste des pistes d’une édition', () async {
    final m = mb((_) async => http.Response(fx('release.json'), 200));
    final t = await m.tracklist('rel-1');
    expect(t.length, 5);
    expect(t[2], (3, 'Testarossa Autodrive'));
  });

  test('au moins 1 s entre deux requêtes', () async {
    final m = mb((_) async => http.Response(fx('empty.json'), 200));
    await m.searchRelease('a', 'b');
    await m.searchRelease('a', 'b');
    expect(waits.single, greaterThanOrEqualTo(const Duration(seconds: 1)));
  });

  test('rien trouvé : liste vide', () async {
    final m = mb((_) async => http.Response(fx('empty.json'), 200));
    expect(await m.searchRelease('x', 'y'), isEmpty);
  });

  test('pas de réseau : RepairError.offline', () async {
    final m = mb((_) async => throw const SocketException('pas de réseau'));
    await expectLater(
      m.searchRelease('a', 'b'),
      throwsA(isA<RepairError>().having((e) => e.offline, 'offline', isTrue)),
    );
  });

  test('pochette : octets de Cover Art Archive, null si absente', () async {
    final m = mb(
      (r) async =>
          r.url.host == 'coverartarchive.org' && r.url.path.contains('rel-1')
          ? http.Response.bytes(Uint8List.fromList([255, 216, 255]), 200)
          : http.Response('', 404),
    );
    expect(await m.cover('rel-1'), [255, 216, 255]);
    expect(await m.cover('rel-9'), isNull);
    expect(seen.first.url.path, '/release/rel-1/front-500');
  });

  test(
    'requête bloquée : abandon après le délai, RepairError.offline',
    () async {
      final m = MusicBrainz(
        MockClient((_) => Completer<http.Response>().future),
        timeout: const Duration(milliseconds: 50),
      );
      await expectLater(
        m.searchRelease('a', 'b'),
        throwsA(isA<RepairError>().having((e) => e.offline, 'offline', isTrue)),
      );
    },
  );

  test('page HTML au lieu de JSON : RepairError', () async {
    final m = mb((_) async => http.Response('<html>login</html>', 200));
    await expectLater(m.searchRelease('a', 'b'), throwsA(isA<RepairError>()));
  });

  test('JSON inattendu (id numérique) : RepairError', () async {
    final m = mb((_) async => http.Response('{"releases":[{"id":12}]}', 200));
    await expectLater(m.searchRelease('a', 'b'), throwsA(isA<RepairError>()));
  });

  test('503 : RepairError.busy', () async {
    final m = mb((_) async => http.Response('', 503));
    await expectLater(
      m.searchRelease('a', 'b'),
      throwsA(isA<RepairError>().having((e) => e.busy, 'busy', isTrue)),
    );
  });
}
