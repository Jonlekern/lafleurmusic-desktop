import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image/image.dart' as img;
import 'package:lafleurmusic/artists/artist_lookup.dart';
import 'package:lafleurmusic/artists/artist_store.dart';
import 'package:lafleurmusic/repair/musicbrainz.dart';

Uint8List jpg(int w) =>
    Uint8List.fromList(img.encodeJpg(img.Image(width: w, height: w)));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;
  late DateTime now;
  late List<String> asked;
  late Future<ArtistInfo?> Function(String) answer;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('art');
    now = DateTime(2026, 10, 17);
    asked = [];
    answer = (n) async => ArtistInfo(
      name: n,
      summary: 'Résumé',
      photoUrl: 'https://img.test/$n.jpg',
    );
  });
  tearDown(() => dir.deleteSync(recursive: true));

  ArtistStore store() => ArtistStore(
    dir: dir,
    find: (n) {
      asked.add(n);
      return answer(n);
    },
    client: MockClient((r) async => http.Response.bytes(jpg(600), 200)),
    clock: () => now,
  );

  test(
    'trouvé : photo et résumé gardés ; relancé, rien n’est redemandé',
    () async {
      final e = await store().get('Kavinsky');
      expect(e.info?.summary, 'Résumé');
      expect(e.photo!.existsSync(), isTrue);
      final again = await store().get('Kavinsky');
      expect(again.photo!.existsSync(), isTrue);
      expect(asked, ['Kavinsky']);
    },
  );

  test('introuvable : on ne redemande qu’après 30 jours', () async {
    answer = (_) async => null;
    await store().get('Personne');
    now = now.add(const Duration(days: 29));
    await store().get('Personne');
    expect(asked.length, 1);
    now = now.add(const Duration(days: 2));
    await store().get('Personne');
    expect(asked.length, 2);
  });

  test(
    'pas de réseau : rien de gardé, on redemande au prochain lancement',
    () async {
      answer = (_) async => throw const RepairError('off', offline: true);
      final e = await store().get('Kavinsky');
      expect(e.photo, isNull);
      answer = (n) async => ArtistInfo(name: n);
      await store().get('Kavinsky');
      expect(asked.length, 2);
    },
  );

  test(
    'ta propre photo : gardée, jamais remplacée, l’écran est prévenu',
    () async {
      final s = store();
      final changed = <String>[];
      s.changes.listen(changed.add);
      await s.setUserPhoto('Kavinsky', jpg(300));
      await Future<void>.delayed(Duration.zero);
      expect(changed, ['Kavinsky']);
      expect((await s.get('Kavinsky')).userPhoto, isTrue);
      now = now.add(const Duration(days: 400));
      final later = await store().get('Kavinsky');
      expect(later.userPhoto, isTrue);
      expect(later.photo!.existsSync(), isTrue);
      expect(asked, isEmpty);
    },
  );

  test('artistes inconnus ou « Divers » : rien n’est cherché', () async {
    final s = store();
    for (final n in ['', 'Inconnu', 'Unknown', 'Divers', 'Various Artists']) {
      await s.get(n);
    }
    expect(asked, isEmpty);
  });

  test(
    'une recherche à la fois (MusicBrainz : 1 requête par seconde)',
    () async {
      var running = 0, most = 0;
      answer = (n) async {
        running++;
        most = running > most ? running : most;
        await Future<void>.delayed(const Duration(milliseconds: 10));
        running--;
        return ArtistInfo(name: n);
      };
      final s = store();
      await Future.wait([
        for (final n in ['A', 'B', 'C', 'D']) s.get(n),
      ]);
      expect(most, 1);
      expect(asked.toSet(), {'A', 'B', 'C', 'D'});
    },
  );

  test(
    'même artiste écrit autrement (casse, accents) : une seule recherche',
    () async {
      final s = store();
      await s.get('Beyoncé');
      await s.get('BEYONCE');
      expect(asked.length, 1);
    },
  );
}
