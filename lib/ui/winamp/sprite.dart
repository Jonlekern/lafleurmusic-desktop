import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import '../../skins/sprites.dart';
import 'winamp_scope.dart';

/// Un morceau du skin, à sa taille × l'échelle, pixels nets.
class Sprite extends StatelessWidget {
  const Sprite(this.name, {super.key, this.width, this.height, this.region});
  final String name;
  final double? width, height; // en pixels ×1 ; par défaut la taille du sprite
  final Rect?
  region; // une partie seulement du sprite (ex. une case de la barre de volume)

  @override
  Widget build(BuildContext context) {
    final w = WinampScope.of(context);
    final r = allSprites[name];
    final img = w.skin.image(name);
    final width =
        (this.width ?? region?.width ?? r?.w.toDouble() ?? 0) * w.scale;
    final height =
        (this.height ?? region?.height ?? r?.h.toDouble() ?? 0) * w.scale;
    if (img == null) return SizedBox(width: width, height: height);
    if (region != null) {
      return CustomPaint(
        size: Size(width, height),
        painter: _RegionPainter(img, region!),
      );
    }
    return RawImage(
      image: img,
      width: width,
      height: height,
      fit: BoxFit.fill,
      filterQuality: FilterQuality.none,
    );
  }
}

class _RegionPainter extends CustomPainter {
  _RegionPainter(this.img, this.src);
  final ui.Image img;
  final Rect src;
  @override
  void paint(Canvas canvas, Size size) => canvas.drawImageRect(
    img,
    src,
    Offset.zero & size,
    Paint()..filterQuality = FilterQuality.none,
  );
  @override
  bool shouldRepaint(_RegionPainter old) => old.img != img || old.src != src;
}
