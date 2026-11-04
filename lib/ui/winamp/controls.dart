import 'package:flutter/widgets.dart';

import 'sprite.dart';
import 'winamp_scope.dart';

/// Bouton du skin : image normale, image « enfoncée » tant qu'on appuie.
class PushButton extends StatefulWidget {
  const PushButton({
    super.key,
    required this.normal,
    required this.pressed,
    required this.onTap,
  });
  final String normal, pressed;
  final VoidCallback? onTap;
  @override
  State<PushButton> createState() => _PushButtonState();
}

class _PushButtonState extends State<PushButton> {
  bool _down = false;
  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTapDown: (_) => setState(() => _down = true),
    onTapCancel: () => setState(() => _down = false),
    onTapUp: (_) {
      setState(() => _down = false);
      widget.onTap?.call();
    },
    child: Sprite(_down ? widget.pressed : widget.normal),
  );
}

/// Curseur horizontal du skin (position, volume, balance, égaliseur ombré) : valeur 0–1.
class SkinSlider extends StatefulWidget {
  const SkinSlider({
    super.key,
    required this.width,
    required this.height,
    required this.value,
    required this.background,
    required this.thumb,
    required this.thumbPressed,
    required this.thumbWidth,
    this.thumbTop = 0,
    this.onChanged,
    this.onEnd,
  });
  final double width, height, value, thumbWidth, thumbTop; // pixels ×1
  final Widget Function(double value) background;
  final String thumb, thumbPressed;
  final ValueChanged<double>? onChanged; // pendant le glisser
  final ValueChanged<double>? onEnd; // au lâcher

  @override
  State<SkinSlider> createState() => _SkinSliderState();
}

class _SkinSliderState extends State<SkinSlider> {
  double? _drag;

  double _at(double localX) {
    final k = WinampScope.of(context).scale;
    final travel = widget.width - widget.thumbWidth;
    return travel <= 0
        ? 0
        : ((localX / k - widget.thumbWidth / 2) / travel).clamp(0.0, 1.0);
  }

  void _move(double v) {
    setState(() => _drag = v);
    widget.onChanged?.call(v);
  }

  void _end() {
    final v = _drag;
    setState(() => _drag = null);
    if (v != null) widget.onEnd?.call(v);
  }

  @override
  Widget build(BuildContext context) {
    final k = WinampScope.of(context).scale;
    final v = _drag ?? widget.value.clamp(0.0, 1.0);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragStart: (d) => _move(_at(d.localPosition.dx)),
      onHorizontalDragUpdate: (d) => _move(_at(d.localPosition.dx)),
      onHorizontalDragEnd: (_) => _end(),
      onTapDown: (d) => _move(_at(d.localPosition.dx)),
      onTapUp: (_) => _end(),
      child: SizedBox(
        width: widget.width * k,
        height: widget.height * k,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            widget.background(v),
            At(
              v * (widget.width - widget.thumbWidth),
              widget.thumbTop,
              Sprite(_drag != null ? widget.thumbPressed : widget.thumb),
            ),
          ],
        ),
      ),
    );
  }
}
