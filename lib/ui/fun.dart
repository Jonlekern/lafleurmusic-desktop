import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';

import '../player/player.dart';

/// Pour rire : le rond rose qui bat, la pluie de fleurs, secouer la fenêtre.

/// Le rond qui bat : 1 sur un coup de basse, puis redescend à 0 en 0,18 s.
class BeatPulse {
  double _avg = 0; // niveau moyen des basses
  double pulse = 0;

  double feed(List<double> bars, double dt) {
    final low = bars.take(3).toList();
    final bass = low.isEmpty ? 0.0 : low.reduce((a, b) => a + b) / low.length;
    pulse = max(0, pulse - dt / 0.18);
    // un coup : 15 % au-dessus de la moyenne, et pas dans le silence. Le spectre est pris après
    // le volume et plafonne à 1 : pas de seuil fixe (à bas volume rien ne battait), et près du
    // plafond l'écart demandé se réduit à la moitié de la place qui reste (à fort volume non plus).
    final margin = min(_avg * 0.15, (1 - _avg) * 0.5);
    if (_avg > 0 && bass > _avg + margin && bass > 0.02) pulse = 1;
    _avg = _avg == 0 ? bass : _avg * 0.9 + bass * 0.1;
    return pulse;
  }
}

/// Un mot tapé au clavier (sans majuscules) : vrai quand la dernière lettre complète le mot.
class SecretWord {
  SecretWord(this.word);
  final String word;
  String _typed = '';

  bool feed(String char) {
    _typed = (_typed + char.toLowerCase());
    if (_typed.length > word.length) {
      _typed = _typed.substring(_typed.length - word.length);
    }
    if (_typed == word) {
      _typed = '';
      return true;
    }
    return false;
  }

  void reset() => _typed = '';
}

/// Secouer la fenêtre : au moins 5 demi-tours d'au moins 20 px en moins d'une seconde.
class ShakeDetector {
  final _turns = <Duration>[];
  double? _last;
  double _from = 0; // où le mouvement en cours a commencé
  int _dir = 0;
  Duration? _quietUntil; // après une secousse, on attend un peu

  bool feed(double x, Duration t) {
    final last = _last;
    _last = x;
    if (last == null) {
      _from = x;
      return false;
    }
    final d = x - last;
    if (d == 0) return false;
    final dir = d > 0 ? 1 : -1;
    if (dir != _dir) {
      // demi-tour : compte seulement si le mouvement d'avant était assez grand
      if (_dir != 0 && (last - _from).abs() >= 20) _turns.add(t);
      _from = last;
      _dir = dir;
    }
    _turns.removeWhere((x) => t - x > const Duration(seconds: 1));
    final quiet = _quietUntil;
    if (quiet != null && t < quiet) return false;
    if (_turns.length >= 5) {
      _turns.clear();
      _quietUntil = t + const Duration(milliseconds: 1500);
      return true;
    }
    return false;
  }
}

/// Tape « lafleur » (hors champ de texte) : des fleurs roses tombent pendant 4 secondes.
class SecretRain extends StatefulWidget {
  const SecretRain({super.key, required this.child});
  final Widget child;
  @override
  State<SecretRain> createState() => _SecretRainState();
}

class _SecretRainState extends State<SecretRain>
    with SingleTickerProviderStateMixin {
  final _word = SecretWord('lafleur');
  late final _fall = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  );
  List<_Flower> _flowers = const [];

  // un champ de texte a le clavier (recherche, titre…) : les lettres lui reviennent
  bool get _typing =>
      FocusManager.instance.primaryFocus?.context
          ?.findAncestorWidgetOfExactType<EditableText>() !=
      null;

  bool _onKey(KeyEvent e) {
    if (e is! KeyDownEvent || e.character == null) return false;
    if (_typing) {
      _word.reset();
      return false;
    }
    if (_word.feed(e.character!)) _rain();
    return false; // la touche continue son chemin (espace, flèches…)
  }

  void _rain() {
    final r = Random();
    setState(() {
      _flowers = [
        for (var i = 0; i < 22; i++)
          _Flower(
            x: r.nextDouble(),
            size: 26 + r.nextDouble() * 32,
            delay: r.nextDouble() * 0.35,
            speed: 0.8 + r.nextDouble() * 0.5,
            spin: (r.nextDouble() - 0.5) * 4,
          ),
      ];
    });
    _fall.forward(from: 0);
  }

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onKey);
    // fini de tomber : plus rien à dessiner
    _fall.addStatusListener((st) {
      if (st == AnimationStatus.completed && mounted) {
        setState(() => _flowers = const []);
      }
    });
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    _fall.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      widget.child,
      if (_flowers.isNotEmpty)
        IgnorePointer(
          child: AnimatedBuilder(
            animation: _fall,
            builder: (context, _) => LayoutBuilder(
              builder: (context, box) => Stack(
                children: [
                  for (final f in _flowers)
                    Positioned(
                      left: f.x * (box.maxWidth - f.size),
                      top:
                          -f.size +
                          ((_fall.value - f.delay) * f.speed).clamp(0.0, 1.0) *
                              (box.maxHeight + 2 * f.size),
                      child: Transform.rotate(
                        angle: f.spin * _fall.value * pi,
                        child: Opacity(
                          opacity:
                              (1 - _fall.value).clamp(0.0, 1.0) * 0.4 + 0.6,
                          child: Image.asset(
                            'assets/fleur.png',
                            key: const Key('fleur'),
                            width: f.size,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
    ],
  );
}

class _Flower {
  const _Flower({
    required this.x,
    required this.size,
    required this.delay,
    required this.speed,
    required this.spin,
  });
  final double x, size, delay, speed, spin;
}

/// Secouer la fenêtre (window_manager) : morceau suivant.
class ShakeController with WindowListener {
  ShakeController(this._wm, this._player, {Duration Function()? clock})
    : _clock = clock ?? _since;

  static final _watch = Stopwatch()..start();
  static Duration _since() => _watch.elapsed;

  final WindowManager _wm;
  final PlayerController _player;
  final Duration Function() _clock;
  final _shake = ShakeDetector();

  // macOS : « move » ne vient qu'une fois au début du glissement, « moved » arrive tout du long
  @override
  void onWindowMoved() => moved();

  Future<void> moved() async {
    final p = await _wm.getPosition();
    if (_shake.feed(p.dx, _clock())) await _player.next();
  }
}

/// Le rond rose qui grossit un peu et s'illumine sur les basses (seulement en lecture).
class BeatingButton extends StatefulWidget {
  const BeatingButton({
    super.key,
    required this.spectrum,
    required this.playing,
    required this.child,
  });
  final Stream<List<double>> spectrum;
  final bool playing;
  final Widget child;
  @override
  State<BeatingButton> createState() => _BeatingButtonState();
}

class _BeatingButtonState extends State<BeatingButton> {
  final _beat = BeatPulse();
  double _pulse = 0;
  Duration? _last;

  @override
  Widget build(BuildContext context) {
    Widget round(double p) => Transform.scale(
      key: const Key('beat'),
      scale: 1 + 0.14 * p,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: p <= 0
              ? null
              : [
                  BoxShadow(
                    color: const Color(0xFFF26EF2).withValues(alpha: 0.6 * p),
                    blurRadius: 26 * p,
                    spreadRadius: 8 * p,
                  ),
                ],
        ),
        child: widget.child,
      ),
    );
    if (!widget.playing) return round(0);
    return StreamBuilder<List<double>>(
      stream: widget.spectrum,
      builder: (context, snap) {
        final bars = snap.data;
        if (bars != null) {
          final now = SchedulerBinding
              .instance
              .currentFrameTimeStamp; // l'horloge de l'écran
          final dt = _last == null ? 0.03 : (now - _last!).inMicroseconds / 1e6;
          _last = now;
          _pulse = _beat.feed(bars, dt);
        }
        return round(_pulse);
      },
    );
  }
}
