import 'dart:convert';
import 'dart:io';

class MusicFolder {
  const MusicFolder({required this.id, required this.path});
  final int id;
  final String path;
  Map<String, Object> toJson() => {'id': id, 'path': path};
}

/// Dossiers de musique choisis par l'utilisateur, rangés en JSON dans le dossier de support de l'appli.
class MusicFolders {
  MusicFolders(this.file);
  final File file;

  Future<List<MusicFolder>> load() async {
    if (!await file.exists()) return [];
    try {
      final list = jsonDecode(await file.readAsString()) as List;
      return [
        for (final m in list.cast<Map>())
          MusicFolder(id: m['id'] as int, path: m['path'] as String),
      ];
    } on FormatException {
      return [];
    }
  }

  Future<void> _save(List<MusicFolder> list) async {
    await file.parent.create(recursive: true);
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsString(jsonEncode([for (final f in list) f.toJson()]));
    await tmp.rename(file.path);
  }

  Future<MusicFolder> add(String path) async {
    final list = await load();
    final existing = list.where((f) => f.path == path);
    if (existing.isNotEmpty) return existing.first;
    final next = list.fold<int>(0, (m, f) => f.id > m ? f.id : m) + 1;
    final folder = MusicFolder(id: next, path: path);
    await _save([...list, folder]);
    return folder;
  }

  Future<void> remove(int id) async =>
      _save((await load()).where((f) => f.id != id).toList());
}
