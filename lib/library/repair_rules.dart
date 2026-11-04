import 'package:path/path.dart' as p;

import 'models.dart';

final _trackLike = RegExp(r'^(track|piste|audio)\s*\d+$', caseSensitive: false);
final _numbered = RegExp(r'^\d{1,3}\s*[-_.]\s*\S');

/// « À réparer » : pas de pochette, pas d'artiste, ou un titre qui ressemble à un nom de fichier.
bool needsRepair(Track t) {
  if (!t.hasCover || t.artist.trim().isEmpty) return true;
  final title = t.title.trim();
  if (_trackLike.hasMatch(title) || _numbered.hasMatch(title)) return true;
  return title == p.basenameWithoutExtension(t.path);
}
