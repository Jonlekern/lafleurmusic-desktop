import 'dart:io';

import 'package:path/path.dart' as p;

/// Le dossier où l'on dépose ses skins Winamp (.wsz) : Musique › LAFLEURMUSIC › Skins.
class SkinsFolder {
  SkinsFolder(this.dir);
  final Directory dir;

  static Directory defaultDir({String? home}) {
    final h =
        home ??
        Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'] ??
        '';
    return Directory(p.join(h, 'Music', 'LAFLEURMUSIC', 'Skins'));
  }

  static bool isSkin(String path) => path.toLowerCase().endsWith('.wsz');

  Future<void> ensure() => dir.create(recursive: true);

  /// Les .wsz du dossier, triés par nom (sans tenir compte de la casse).
  Future<List<File>> list() async {
    if (!await dir.exists()) return const [];
    final out = [
      await for (final e in dir.list())
        if (e is File && isSkin(e.path)) e,
    ];
    out.sort(
      (a, b) => p
          .basename(a.path)
          .toLowerCase()
          .compareTo(p.basename(b.path).toLowerCase()),
    );
    return out;
  }

  /// Copie un skin glissé sur la fenêtre ; même nom déjà pris → « nom (2).wsz ».
  Future<File?> add(File src) async {
    if (!isSkin(src.path)) return null;
    await ensure();
    final base = p.basenameWithoutExtension(src.path);
    final ext = p.extension(src.path);
    var target = File(p.join(dir.path, '$base$ext'));
    for (var n = 2; await target.exists(); n++) {
      target = File(p.join(dir.path, '$base ($n)$ext'));
    }
    return src.copy(target.path);
  }
}
