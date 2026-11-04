import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:image/image.dart' as img;

import 'sprites.dart';

/// Un sprite découpé : pixels RGBA, prêt à devenir une image à l'écran.
class SpriteBitmap {
  const SpriteBitmap(this.w, this.h, this.rgba);
  final int w, h;
  final Uint8List rgba;
}

/// Un skin lu (sans rien d'affichable : passe d'un isolate à l'autre).
class SkinData {
  const SkinData({
    required this.name,
    required this.sprites,
    required this.missing,
    required this.playlistColors,
    required this.visColors,
    this.playlistFont,
  });
  final String name;
  final Map<String, SpriteBitmap> sprites;
  final Set<String>
  missing; // sprites remplacés par le secours (image absente ou abîmée)
  final Map<String, int>
  playlistColors; // normal, current, normalbg, selectedbg (ARGB)
  final List<int> visColors; // 24 couleurs ARGB du visualiseur
  final String? playlistFont;
}

const maxSkinBytes = 20 * 1024 * 1024;
const _fallback = 0xFF2A2A2A; // gris du skin de secours LAFLEUR
// image absente : on prend la même position dans une autre image (comme Winamp)
const _aliases = {
  'numbers': ['nums_ex'],
  'balance': ['volume'],
};

/// Lit un .wsz ; null si ce n'est pas un skin classique lisible.
Future<SkinData?> loadSkinData(File f) async {
  try {
    if (await f.length() > maxSkinBytes) return null;
    final bytes = await f.readAsBytes();
    final name = f.uri.pathSegments.last.replaceAll(
      RegExp(r'\.wsz$', caseSensitive: false),
      '',
    );
    return await Isolate.run(() => parseSkin(bytes, name));
  } on Object {
    return null;
  }
}

/// Décompresse et découpe un skin (noms sans casse, fichiers éventuellement dans un sous-dossier).
SkinData? parseSkin(Uint8List zip, String name) {
  final Archive archive;
  try {
    archive = ZipDecoder().decodeBytes(zip);
  } on Object {
    return null;
  }
  final files = <String, ArchiveFile>{};
  for (final f in archive.files) {
    if (!f.isFile) continue;
    final base = f.name.split(RegExp(r'[/\\]')).last.toLowerCase();
    files.putIfAbsent(base, () => f);
  }
  final images = <String, img.Image?>{};
  img.Image? sheet(String file) => images.putIfAbsent(file, () {
    final f = files['$file.bmp'] ?? files['$file.png'];
    if (f == null) return null;
    try {
      final bytes = f.readBytes();
      if (bytes == null) return null;
      final im = img.decodeBmp(bytes) ?? img.decodeImage(bytes);
      return im?.convert(numChannels: 4, format: img.Format.uint8);
    } on Object {
      return null;
    }
  });
  if (sheet('main') == null) return null;

  final out = <String, SpriteBitmap>{};
  final missing = <String>{};
  for (final e in allSprites.entries) {
    final r = e.value;
    var src = sheet(r.file);
    for (final alt in _aliases[r.file] ?? const <String>[]) {
      src ??= sheet(alt);
    }
    if (src == null) {
      missing.add(e.key);
      out[e.key] = _solid(r.w, r.h, _fallback);
      continue;
    }
    // image plus petite que prévu (curseur de volume absent…) : transparent, comme dans Winamp
    out[e.key] = _crop(src, r);
  }
  String? text(String n) {
    final f = files[n];
    final b = f?.readBytes();
    return b == null ? null : String.fromCharCodes(b);
  }

  final colors = <String, int>{};
  String? font;
  for (final m in RegExp(
    r'^\s*(\w+)\s*=\s*([^\r\n]+)',
    multiLine: true,
  ).allMatches(text('pledit.txt') ?? '')) {
    final key = m.group(1)!.toLowerCase();
    final v = m.group(2)!.trim();
    if (key == 'font') {
      font = v;
    } else {
      final hex = RegExp(r'#?([0-9a-fA-F]{6})').firstMatch(v);
      if (hex != null) {
        colors[key] = 0xFF000000 | int.parse(hex.group(1)!, radix: 16);
      }
    }
  }
  final vis = [
    for (final m in RegExp(
      r'(\d+)\s*,\s*(\d+)\s*,\s*(\d+)',
    ).allMatches(text('viscolor.txt') ?? ''))
      0xFF000000 |
          (int.parse(m.group(1)!).clamp(0, 255) << 16) |
          (int.parse(m.group(2)!).clamp(0, 255) << 8) |
          int.parse(m.group(3)!).clamp(0, 255),
  ];
  return SkinData(
    name: name,
    sprites: out,
    missing: missing,
    playlistColors: {
      'normal': colors['normal'] ?? 0xFF00FF00,
      'current': colors['current'] ?? 0xFFFFFFFF,
      'normalbg': colors['normalbg'] ?? 0xFF000000,
      'selectedbg': colors['selectedbg'] ?? 0xFF0000C6,
    },
    visColors: vis.length >= 24
        ? vis.sublist(0, 24)
        : [for (var i = 0; i < 24; i++) i < vis.length ? vis[i] : 0xFFF26EF2],
    playlistFont: font,
  );
}

SpriteBitmap _solid(int w, int h, int argb) {
  final b = Uint8List(w * h * 4);
  for (var i = 0; i < w * h; i++) {
    b[i * 4] = (argb >> 16) & 0xFF;
    b[i * 4 + 1] = (argb >> 8) & 0xFF;
    b[i * 4 + 2] = argb & 0xFF;
    b[i * 4 + 3] = 0xFF;
  }
  return SpriteBitmap(w, h, b);
}

// découpe ; ce qui dépasse de l'image du skin reste transparent (alpha 0)
SpriteBitmap _crop(img.Image src, SpriteRect r) {
  final b = Uint8List(r.w * r.h * 4);
  for (var y = 0; y < r.h; y++) {
    final sy = r.y + y;
    if (sy >= src.height) break;
    for (var x = 0; x < r.w; x++) {
      final sx = r.x + x;
      if (sx >= src.width) break;
      final p = src.getPixel(sx, sy);
      final i = (y * r.w + x) * 4;
      b[i] = p.r.toInt();
      b[i + 1] = p.g.toInt();
      b[i + 2] = p.b.toInt();
      b[i + 3] = 0xFF;
    }
  }
  return SpriteBitmap(r.w, r.h, b);
}
