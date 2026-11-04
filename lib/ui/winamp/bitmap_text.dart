import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../library/models.dart' show sortKey;
import '../../skins/sprites.dart';
import 'sprite.dart';
import 'winamp_scope.dart';

/// Texte écrit avec la police du skin (text.bmp, lettres de 5 × 6).
class BitmapText extends StatelessWidget {
  const BitmapText(this.text, {super.key});
  final String text;

  static String glyph(String ch) {
    final c = sortKey(ch);
    final k = c.isEmpty ? ' ' : c[0];
    return fontLookup.containsKey(k) ? k : ' ';
  }

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [for (final ch in text.characters) Sprite(charSprite(glyph(ch)))],
  );
}

/// Titre qui défile d'une lettre toutes les 220 ms quand il est plus long que la place (comme Winamp).
class Marquee extends StatefulWidget {
  const Marquee(this.text, {super.key, required this.width});
  final String text;
  final double width; // en pixels ×1
  @override
  State<Marquee> createState() => _MarqueeState();
}

class _MarqueeState extends State<Marquee> {
  Timer? _timer;
  int _start = 0;

  int get _room => widget.width ~/ 5;
  bool get _long => widget.text.length > _room;

  void _arm() {
    _timer?.cancel();
    _start = 0;
    if (_long) {
      _timer = Timer.periodic(const Duration(milliseconds: 220), (_) {
        setState(() => _start++);
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _arm();
  }

  @override
  void didUpdateWidget(Marquee old) {
    super.didUpdateWidget(old);
    if (old.text != widget.text || old.width != widget.width) _arm();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var shown = widget.text;
    if (_long) {
      final loop = '${widget.text}  ***  ';
      final i = _start % loop.length;
      shown = (loop + loop).substring(i, i + _room);
    }
    return ClipRect(child: BitmapText(shown));
  }
}

/// Temps en chiffres du skin (mm:ss), signe moins pour le temps restant.
class TimeDigits extends StatelessWidget {
  const TimeDigits(this.time, {super.key, this.remaining = false});
  final Duration time;
  final bool remaining;

  @override
  Widget build(BuildContext context) {
    final s = time.inSeconds.clamp(0, 99 * 60 + 59);
    final m = s ~/ 60, sec = s % 60;
    final k = WinampScope.of(context).scale;
    // positions dans la zone du temps (Webamp) : signe, puis 9 / 21 / 39 / 51
    return SizedBox(
      width: 63 * k,
      height: 13 * k,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          At(-1, 6, Sprite(remaining ? 'MINUS_SIGN' : 'NO_MINUS_SIGN')),
          At(9, 0, Sprite('DIGIT_${m ~/ 10}')),
          At(21, 0, Sprite('DIGIT_${m % 10}')),
          At(39, 0, Sprite('DIGIT_${sec ~/ 10}')),
          At(51, 0, Sprite('DIGIT_${sec % 10}')),
        ],
      ),
    );
  }
}
