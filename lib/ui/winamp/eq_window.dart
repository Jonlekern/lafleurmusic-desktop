import 'package:flutter/material.dart';

import '../../l10n/strings.dart';
import '../../player/equalizer.dart';
import 'controls.dart';
import 'eq_mapping.dart';
import 'sprite.dart';
import 'winamp_scope.dart';

/// Fenêtre égaliseur de Winamp (275 × 116), branchée sur l'égaliseur de l'appli. Positions : Webamp (MIT).
class EqWindow extends StatefulWidget {
  const EqWindow({
    super.key,
    required this.equalizer,
    required this.strings,
    required this.onClose,
  });
  final ValueNotifier<Equalizer> equalizer;
  final Strings strings;
  final VoidCallback onClose;

  @override
  State<EqWindow> createState() => _EqWindowState();
}

class _EqWindowState extends State<EqWindow> {
  double _preamp = 0; // dB, affiché seulement (l'appli garde les bandes)
  List<double>? _base; // bandes au début du glisser du préampli
  double _from = 0; // préampli au début du glisser

  ValueNotifier<Equalizer> get _eq => widget.equalizer;

  static double _toV(double db) => (db + 12) / 24;
  static double _toDb(double v) => v * 24 - 12;

  void _band(int i, double v) {
    final g = List.of(_eq.value.gains)..[i] = _toDb(v);
    _eq.value = withWinamp(_eq.value, base: g, preamp: 0);
  }

  void _pre(double v) {
    if (_base == null) {
      _base = List.of(_eq.value.gains);
      _from = _preamp;
    }
    setState(() => _preamp = _toDb(v));
    _eq.value = withWinamp(
      _eq.value,
      base: preampGains(_base!, from: _from, to: _preamp),
      preamp: 0,
    );
  }

  Future<void> _presets(BuildContext context) async {
    final box = context.findRenderObject() as RenderBox?;
    final at = box?.localToGlobal(Offset.zero) ?? Offset.zero;
    final pick = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(at.dx, at.dy, at.dx, at.dy),
      items: [
        for (final p in Equalizer.presets.keys)
          PopupMenuItem(value: p, child: Text(widget.strings.presetName(p))),
      ],
    );
    if (pick == null) return;
    setState(() => _preamp = 0);
    _eq.value = Equalizer.named(pick).copyWith(enabled: _eq.value.enabled);
  }

  @override
  Widget build(BuildContext context) {
    final w = WinampScope.of(context);
    final k = w.scale;
    return ValueListenableBuilder<Equalizer>(
      valueListenable: _eq,
      builder: (context, eq, _) => SizedBox(
        width: 275 * k,
        height: 116 * k,
        child: Stack(
          children: [
            const Positioned.fill(child: Sprite('EQ_WINDOW_BACKGROUND')),
            const At(0, 0, Sprite('EQ_TITLE_BAR_SELECTED')),
            At(
              264,
              3,
              PushButton(
                key: const Key('wa-eq-close'),
                normal: 'EQ_CLOSE_BUTTON',
                pressed: 'EQ_CLOSE_BUTTON_ACTIVE',
                onTap: widget.onClose,
              ),
            ),
            At(
              14,
              18,
              PushButton(
                key: const Key('wa-eq-on'),
                normal: eq.enabled ? 'EQ_ON_BUTTON_SELECTED' : 'EQ_ON_BUTTON',
                pressed: eq.enabled
                    ? 'EQ_ON_BUTTON_SELECTED_DEPRESSED'
                    : 'EQ_ON_BUTTON_DEPRESSED',
                onTap: () =>
                    _eq.value = _eq.value.copyWith(enabled: !_eq.value.enabled),
              ),
            ),
            const At(40, 18, Sprite('EQ_AUTO_BUTTON')), // AUTO : pas utilisé
            At(
              217,
              18,
              Builder(
                builder: (context) => PushButton(
                  key: const Key('wa-eq-presets'),
                  normal: 'EQ_PRESETS_BUTTON',
                  pressed: 'EQ_PRESETS_BUTTON_SELECTED',
                  onTap: () => _presets(context),
                ),
              ),
            ),
            At(
              86,
              17,
              Stack(
                children: [
                  const Sprite('EQ_GRAPH_BACKGROUND'),
                  CustomPaint(
                    size: Size(113 * k, 19 * k),
                    painter: _Curve(eq.gains, w),
                  ),
                ],
              ),
            ),
            At(
              21,
              38,
              _EqSlider(
                key: const Key('wa-preamp'),
                id: 'wa-preamp',
                value: _toV(_preamp),
                onChanged: _pre,
                onEnd: () => _base = null,
              ),
            ),
            for (var i = 0; i < 10; i++)
              At(
                78 + 18.0 * i,
                38,
                _EqSlider(
                  key: Key('wa-band-$i'),
                  id: 'wa-band-$i',
                  value: _toV(eq.gains[i]),
                  onChanged: (v) => _band(i, v),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Curseur vertical de l'égaliseur (14 × 63) : fond = une des 28 cases du skin, pouce 11 × 11.
class _EqSlider extends StatefulWidget {
  const _EqSlider({
    super.key,
    required this.id,
    required this.value,
    required this.onChanged,
    this.onEnd,
  });
  final String id;
  final double value; // 0 (−12 dB) … 1 (+12 dB)
  final ValueChanged<double> onChanged;
  final VoidCallback? onEnd;
  @override
  State<_EqSlider> createState() => _EqSliderState();
}

class _EqSliderState extends State<_EqSlider> {
  bool _down = false;

  double _at(double y, double k) => (1 - (y / k - 5.5) / 51).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    final k = WinampScope.of(context).scale;
    final v = widget.value.clamp(0.0, 1.0);
    final f = (v * 27).round();
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onVerticalDragStart: (d) {
        setState(() => _down = true);
        widget.onChanged(_at(d.localPosition.dy, k));
      },
      onVerticalDragUpdate: (d) => widget.onChanged(_at(d.localPosition.dy, k)),
      onVerticalDragEnd: (_) {
        setState(() => _down = false);
        widget.onEnd?.call();
      },
      child: SizedBox(
        width: 14 * k,
        height: 63 * k,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Sprite(
              'EQ_SLIDER_BACKGROUND',
              region: Rect.fromLTWH((f % 14) * 15.0, (f ~/ 14) * 65.0, 14, 63),
            ),
            At(
              1,
              (1 - v) * 51,
              Sprite(
                _down ? 'EQ_SLIDER_THUMB_SELECTED' : 'EQ_SLIDER_THUMB',
                key: Key('${widget.id}-thumb'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Courbe de l'égaliseur, couleurs prises dans le skin (EQ_GRAPH_LINE_COLORS, une par hauteur).
class _Curve extends CustomPainter {
  _Curve(this.gains, this.w);
  final List<double> gains;
  final WinampScope w;

  @override
  void paint(Canvas canvas, Size size) {
    final k = w.scale;
    for (var x = 0; x < 109; x++) {
      final t = x / 108 * (gains.length - 1);
      final i = t.floor().clamp(0, gains.length - 2);
      final db = gains[i] + (gains[i + 1] - gains[i]) * (t - i);
      final y = ((1 - (db + 12) / 24) * 18).round().clamp(0, 18);
      final c =
          w.skin.pixel('EQ_GRAPH_LINE_COLORS', 0, y) ?? const Color(0xFFF26EF2);
      canvas.drawRect(
        Rect.fromLTWH((x + 2) * k, y * k, k, k),
        Paint()..color = c,
      );
    }
  }

  @override
  bool shouldRepaint(_Curve old) => old.gains != gains;
}
