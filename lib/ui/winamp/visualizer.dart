import 'package:flutter/widgets.dart';

import 'winamp_scope.dart';

/// Visualiseur Winamp (76 × 16) : 0 barres du spectre, 1 vague (oscilloscope), 2 rien. Couleurs du skin (viscolor.txt).
class Visualizer extends StatelessWidget {
  const Visualizer({super.key, required this.mode, required this.values});
  final int mode;
  final List<double> values; // barres 0–1 ou vague −1…1

  @override
  Widget build(BuildContext context) {
    final w = WinampScope.of(context);
    final size = Size(76 * w.scale, 16 * w.scale);
    if (mode == 2) return SizedBox.fromSize(size: size);
    return CustomPaint(
      size: size,
      painter: VisPainter(mode, values, w.skin.visColors, w.scale),
    );
  }
}

class VisPainter extends CustomPainter {
  VisPainter(this.mode, this.values, this.colors, this.k);
  final int mode;
  final List<double> values;
  final List<Color> colors;
  final double k;

  void _px(Canvas c, int x, int y, Color col) =>
      c.drawRect(Rect.fromLTWH(x * k, y * k, k, k), Paint()..color = col);

  @override
  void paint(Canvas canvas, Size size) {
    // fond : couleur 0, points de la couleur 1 une case sur deux (comme Winamp)
    canvas.drawRect(Offset.zero & size, Paint()..color = colors[0]);
    for (var y = 1; y < 16; y += 2) {
      for (var x = 1; x < 76; x += 2) {
        _px(canvas, x, y, colors[1]);
      }
    }
    if (mode == 0) {
      for (var i = 0; i < 19 && i < values.length; i++) {
        final h = (values[i].clamp(0.0, 1.0) * 16).round();
        for (var r = 0; r < h; r++) {
          final y = 15 - r;
          // couleurs 2 (haut) … 17 (bas)
          final col = colors[2 + y];
          for (var dx = 0; dx < 3; dx++) {
            _px(canvas, i * 4 + dx, y, col);
          }
        }
      }
    } else {
      for (var x = 0; x < 76 && x < values.length; x++) {
        final y = (8 - values[x].clamp(-1.0, 1.0) * 7.5).round().clamp(0, 15);
        // couleurs 18–22 selon l'écart au centre
        final col = colors[18 + ((y - 8).abs() ~/ 2).clamp(0, 4)];
        _px(canvas, x, y, col);
      }
    }
  }

  @override
  bool shouldRepaint(VisPainter old) =>
      old.values != values || old.mode != mode || old.colors != colors;
}
