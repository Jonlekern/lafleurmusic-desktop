// Essai réel (réseau) : dart run tool/try_artists.dart "Nom" "Nom"…
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:lafleurmusic/artists/artist_lookup.dart';
import 'package:lafleurmusic/repair/musicbrainz.dart';

Future<void> main(List<String> names) async {
  final c = http.Client();
  final l = ArtistLookup(MusicBrainz(c), c);
  for (final n in names) {
    final i = await l.find(n);
    stdout.writeln('== $n');
    stdout.writeln(
      i == null
          ? '  introuvable'
          : '  ${i.kind} | ${i.place} | ${i.since}\n  photo: ${i.photoUrl}\n  page: ${i.pageUrl}\n  ${(i.summary ?? '-').substring(0, (i.summary ?? '-').length.clamp(0, 120))}',
    );
  }
  c.close();
}
