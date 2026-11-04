import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'skin_loader.dart';

/// Un skin prêt à afficher : une image par sprite, couleurs de la playlist et du visualiseur.
class Skin {
  Skin._(this.name, this._images, this._data);
  final String name;
  final Map<String, ui.Image> _images;
  final SkinData _data;

  ui.Image? image(String sprite) => _images[sprite];

  /// Couleur d'un pixel d'un sprite (ex. couleurs de la courbe de l'égaliseur).
  ui.Color? pixel(String sprite, int x, int y) {
    final b = _data.sprites[sprite];
    if (b == null || x < 0 || y < 0 || x >= b.w || y >= b.h) return null;
    final i = (y * b.w + x) * 4;
    return ui.Color.fromARGB(
      b.rgba[i + 3],
      b.rgba[i],
      b.rgba[i + 1],
      b.rgba[i + 2],
    );
  }

  ui.Color playlistColor(String key) =>
      ui.Color(_data.playlistColors[key] ?? 0xFFFFFFFF);
  List<ui.Color> get visColors => [
    for (final c in _data.visColors) ui.Color(c),
  ];
  String? get playlistFont => _data.playlistFont;

  static Future<Skin> fromData(SkinData d) async {
    final images = <String, ui.Image>{};
    for (final e in d.sprites.entries) {
      final c = Completer<ui.Image>();
      ui.decodeImageFromPixels(
        e.value.rgba,
        e.value.w,
        e.value.h,
        ui.PixelFormat.rgba8888,
        c.complete,
      );
      images[e.key] = await c.future;
    }
    return Skin._(d.name, images, d);
  }

  // skins déjà lus (même fichier, même date, même taille) : repasser à un skin est immédiat
  static final _cache = <String, Future<Skin?>>{};

  /// Lit un .wsz ; null si illisible.
  static Future<Skin?> load(File f) {
    String key;
    try {
      final st = f.statSync();
      key = '${f.path}|${st.modified.millisecondsSinceEpoch}|${st.size}';
    } on FileSystemException {
      return Future.value(null);
    }
    return _cache.putIfAbsent(key, () async {
      final d = await loadSkinData(f);
      return d == null ? null : fromData(d);
    });
  }
}
