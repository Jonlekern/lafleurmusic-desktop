// Fabrique test/fixtures/skins/lafleur-test.wsz : un skin Winamp d'essai dessiné par nous (gris et rose),
// aux dimensions exactes des images d'un skin classique. dart run tool/make_test_skin.dart
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:image/image.dart' as img;
import 'package:lafleurmusic/skins/sprites.dart';

void main() {
  final size = <String, (int, int)>{};
  for (final r in allSprites.values) {
    final (w, h) = size[r.file] ?? (0, 0);
    size[r.file] = (
      w > r.x + r.w ? w : r.x + r.w,
      h > r.y + r.h ? h : r.y + r.h,
    );
  }
  final gray = img.ColorRgb8(0x2A, 0x2A, 0x2A);
  final light = img.ColorRgb8(0x44, 0x44, 0x44);
  final pink = img.ColorRgb8(0xF2, 0x6E, 0xF2);
  final out = Archive();
  for (final e in size.entries) {
    final (w, h) = e.value;
    final im = img.Image(width: w, height: h)..clear(gray);
    for (final r in allSprites.values.where((r) => r.file == e.key)) {
      if (r.w >= 200 && r.h >= 100) continue; // fonds de fenêtre : gris uni
      img.fillRect(
        im,
        x1: r.x,
        y1: r.y,
        x2: r.x + r.w - 1,
        y2: r.y + r.h - 1,
        color: light,
      );
      img.drawRect(
        im,
        x1: r.x,
        y1: r.y,
        x2: r.x + r.w - 1,
        y2: r.y + r.h - 1,
        color: pink,
      );
    }
    final bmp = img.encodeBmp(im);
    out.addFile(ArchiveFile('${e.key}.bmp', bmp.length, bmp));
  }
  void text(String name, String body) => out.addFile(
    ArchiveFile(name, body.length, Uint8List.fromList(body.codeUnits)),
  );
  text(
    'pledit.txt',
    '[Text]\r\nNormal=#BBBBBB\r\nCurrent=#F26EF2\r\nNormalBG=#0D0D0D\r\nSelectedBG=#2A2A2A\r\nFont=Arial\r\n',
  );
  text(
    'viscolor.txt',
    [
      for (var i = 0; i < 24; i++)
        '${242 - i * 4},${110 + i},${242 - i * 4}, // $i',
    ].join('\r\n'),
  );
  Directory('test/fixtures/skins').createSync(recursive: true);
  File('test/fixtures/skins/lafleur-test.wsz')
      .writeAsBytesSync(ZipEncoder().encode(out));
  stdout.writeln('ok: ${size.length} images');
}
