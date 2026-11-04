import 'package:flutter/widgets.dart';

import '../../player/player.dart';
import '../../player/queue.dart';
import 'bitmap_text.dart';
import 'controls.dart';
import 'sprite.dart';
import 'visualizer.dart';
import 'winamp_scope.dart';

/// Fenêtre principale de Winamp (275 × 116). Positions : Webamp (MIT).
class MainWindow extends StatefulWidget {
  const MainWindow({
    super.key,
    required this.player,
    required this.eqOpen,
    required this.plOpen,
    required this.visMode,
    required this.onClose,
    required this.onToggleEq,
    required this.onTogglePl,
    required this.onVisMode,
    this.onMenu,
    this.onDragWindow,
  });
  final PlayerController player;
  final bool eqOpen, plOpen;
  final int visMode;
  final VoidCallback onClose, onToggleEq, onTogglePl, onVisMode;
  final VoidCallback? onMenu; // bouton menu en haut à gauche
  final VoidCallback?
  onDragWindow; // barre de titre tirée : déplacer la fenêtre

  @override
  State<MainWindow> createState() => _MainWindowState();
}

class _MainWindowState extends State<MainWindow> {
  bool _remaining = false;
  bool _stopped = false;
  late double _volume = widget.player.volume;
  late double _balance = widget.player.balance;
  // un seul abonnement, même si l'état du lecteur redessine la fenêtre 30 fois par seconde
  late final Stream<AudioInfo> _info = widget.player.infoStream;

  PlayerController get _p => widget.player;

  Future<void> _play() async {
    final s = _p.current;
    if (s.track == null) return;
    setState(() => _stopped = false);
    s.playing ? await _p.seek(Duration.zero) : await _p.toggle();
  }

  Future<void> _pause() async {
    if (_p.current.track == null || (_stopped && !_p.current.playing)) return;
    await _p.toggle();
  }

  Future<void> _stop() async {
    if (_p.current.track == null) return;
    if (_p.current.playing) await _p.toggle();
    await _p.seek(Duration.zero);
    setState(() => _stopped = true);
  }

  String _title(PlayerState s) {
    final t = s.track;
    if (t == null) return 'LAFLEURMUSIC';
    final n = (_p.queue?.position ?? 0) + 1;
    final d = Duration(milliseconds: t.durationMs);
    final len =
        '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
    final who = t.artist.isEmpty ? '' : '${t.artist} - ';
    return '$n. $who${t.title} ($len)';
  }

  @override
  Widget build(BuildContext context) {
    final k = WinampScope.of(context).scale;
    return StreamBuilder<PlayerState>(
      stream: _p.state,
      initialData: _p.current,
      builder: (context, snap) {
        final s = snap.data ?? const PlayerState();
        // relancé autrement (Suivant, double-clic…) : plus à l'arrêt
        if (s.playing) {
          _stopped = false;
        }
        final q = _p.queue;
        final shuffle = q?.shuffle ?? false;
        final repeat = (q?.repeat ?? Repeat.off) != Repeat.off;
        final total = s.duration.inMilliseconds;
        final shown = _remaining ? s.duration - s.position : s.position;
        final title = _title(s);
        return SizedBox(
          width: 275 * k,
          height: 116 * k,
          child: Stack(
            children: [
              const Positioned.fill(child: Sprite('MAIN_WINDOW_BACKGROUND')),
              At(
                0,
                0,
                GestureDetector(
                  onPanStart: (_) => widget.onDragWindow?.call(),
                  child: const Sprite('MAIN_TITLE_BAR_SELECTED'),
                ),
              ),
              At(
                6,
                3,
                PushButton(
                  key: const Key('wa-menu'),
                  normal: 'MAIN_OPTIONS_BUTTON',
                  pressed: 'MAIN_OPTIONS_BUTTON_DEPRESSED',
                  onTap: widget.onMenu,
                ),
              ),
              At(
                264,
                3,
                PushButton(
                  key: const Key('wa-close'),
                  normal: 'MAIN_CLOSE_BUTTON',
                  pressed: 'MAIN_CLOSE_BUTTON_DEPRESSED',
                  onTap: widget.onClose,
                ),
              ),
              At(
                26,
                28,
                Sprite(
                  s.playing
                      ? 'MAIN_PLAYING_INDICATOR'
                      : (_stopped || s.track == null
                            ? 'MAIN_STOPPED_INDICATOR'
                            : 'MAIN_PAUSED_INDICATOR'),
                ),
              ),
              At(
                39,
                26,
                GestureDetector(
                  key: const Key('wa-time'),
                  behavior: HitTestBehavior.opaque,
                  onTap: () => setState(() => _remaining = !_remaining),
                  child: TimeDigits(shown, remaining: _remaining),
                ),
              ),
              At(
                24,
                43,
                GestureDetector(
                  key: const Key('wa-vis'),
                  behavior: HitTestBehavior.opaque,
                  onTap: widget.onVisMode,
                  child: _Vis(player: _p, mode: widget.visMode),
                ),
              ),
              At(
                111,
                24,
                SizedBox(
                  width: 154 * k,
                  height: 6 * k,
                  child: Marquee(
                    title,
                    key: ValueKey('marquee:$title'),
                    width: 154,
                  ),
                ),
              ),
              StreamBuilder<AudioInfo>(
                stream: _info,
                initialData: _p.info,
                builder: (_, i) {
                  final info = i.data ?? const AudioInfo();
                  final ch = info.channels;
                  return Stack(
                    children: [
                      At(111, 43, BitmapText(_pad(info.kbps, 3))),
                      At(156, 43, BitmapText(_pad(info.khz, 2))),
                      At(
                        212,
                        41,
                        Sprite(ch == 1 ? 'MAIN_MONO_SELECTED' : 'MAIN_MONO'),
                      ),
                      At(
                        239,
                        41,
                        Sprite(
                          ch != null && ch >= 2
                              ? 'MAIN_STEREO_SELECTED'
                              : 'MAIN_STEREO',
                        ),
                      ),
                    ],
                  );
                },
              ),
              At(
                107,
                57,
                SkinSlider(
                  key: const Key('wa-volume'),
                  width: 68,
                  height: 13,
                  value: _volume / 100,
                  thumbWidth: 14,
                  thumbTop: 1,
                  thumb: 'MAIN_VOLUME_THUMB',
                  thumbPressed: 'MAIN_VOLUME_THUMB_SELECTED',
                  background: (v) => Sprite(
                    'MAIN_VOLUME_BACKGROUND',
                    region: Rect.fromLTWH(0, (v * 27).round() * 15.0, 68, 13),
                  ),
                  onChanged: (v) {
                    setState(() => _volume = v * 100);
                    _p.setVolume(v * 100);
                  },
                ),
              ),
              At(
                177,
                57,
                SkinSlider(
                  key: const Key('wa-balance'),
                  width: 38,
                  height: 13,
                  value: (_balance + 1) / 2,
                  thumbWidth: 14,
                  thumbTop: 1,
                  thumb: 'MAIN_BALANCE_THUMB',
                  thumbPressed: 'MAIN_BALANCE_THUMB_ACTIVE',
                  background: (v) => Sprite(
                    'MAIN_BALANCE_BACKGROUND',
                    region: Rect.fromLTWH(
                      0,
                      ((v * 2 - 1).abs() * 27).round() * 15.0,
                      38,
                      13,
                    ),
                  ),
                  onChanged: (v) {
                    // près du centre : on se cale au centre, comme Winamp
                    final b = (v * 2 - 1).abs() < 0.08 ? 0.0 : v * 2 - 1;
                    setState(() => _balance = b);
                    _p.setBalance(b);
                  },
                ),
              ),
              At(
                219,
                58,
                PushButton(
                  key: const Key('wa-eqbutton'),
                  normal: widget.eqOpen
                      ? 'MAIN_EQ_BUTTON_SELECTED'
                      : 'MAIN_EQ_BUTTON',
                  pressed: widget.eqOpen
                      ? 'MAIN_EQ_BUTTON_DEPRESSED_SELECTED'
                      : 'MAIN_EQ_BUTTON_DEPRESSED',
                  onTap: widget.onToggleEq,
                ),
              ),
              At(
                242,
                58,
                PushButton(
                  key: const Key('wa-plbutton'),
                  normal: widget.plOpen
                      ? 'MAIN_PLAYLIST_BUTTON_SELECTED'
                      : 'MAIN_PLAYLIST_BUTTON',
                  pressed: widget.plOpen
                      ? 'MAIN_PLAYLIST_BUTTON_DEPRESSED_SELECTED'
                      : 'MAIN_PLAYLIST_BUTTON_DEPRESSED',
                  onTap: widget.onTogglePl,
                ),
              ),
              At(
                16,
                72,
                SkinSlider(
                  key: const Key('wa-position'),
                  width: 248,
                  height: 10,
                  value: total == 0 ? 0 : s.position.inMilliseconds / total,
                  thumbWidth: 29,
                  thumb: 'MAIN_POSITION_SLIDER_THUMB',
                  thumbPressed: 'MAIN_POSITION_SLIDER_THUMB_SELECTED',
                  background: (_) =>
                      const Sprite('MAIN_POSITION_SLIDER_BACKGROUND'),
                  onEnd: (v) =>
                      _p.seek(Duration(milliseconds: (v * total).round())),
                ),
              ),
              for (final (i, name, key, action) in [
                (0, 'PREVIOUS', 'wa-prev', _p.previous),
                (1, 'PLAY', 'wa-play', _play),
                (2, 'PAUSE', 'wa-pause', _pause),
                (3, 'STOP', 'wa-stop', _stop),
                (4, 'NEXT', 'wa-next', _p.next),
              ])
                At(
                  16 + i * 23.0,
                  88,
                  PushButton(
                    key: Key(key),
                    normal: 'MAIN_${name}_BUTTON',
                    pressed: 'MAIN_${name}_BUTTON_ACTIVE',
                    onTap: action,
                  ),
                ),
              At(
                136,
                89,
                PushButton(
                  key: const Key('wa-eject'),
                  normal: 'MAIN_EJECT_BUTTON',
                  pressed: 'MAIN_EJECT_BUTTON_ACTIVE',
                  onTap: widget.onClose,
                ),
              ),
              At(
                164,
                89,
                PushButton(
                  key: const Key('wa-shuffle'),
                  normal: shuffle
                      ? 'MAIN_SHUFFLE_BUTTON_SELECTED'
                      : 'MAIN_SHUFFLE_BUTTON',
                  pressed: shuffle
                      ? 'MAIN_SHUFFLE_BUTTON_SELECTED_DEPRESSED'
                      : 'MAIN_SHUFFLE_BUTTON_DEPRESSED',
                  onTap: () async {
                    await _p.toggleShuffle();
                    if (mounted) setState(() {});
                  },
                ),
              ),
              At(
                210,
                89,
                PushButton(
                  key: const Key('wa-repeat'),
                  normal: repeat
                      ? 'MAIN_REPEAT_BUTTON_SELECTED'
                      : 'MAIN_REPEAT_BUTTON',
                  pressed: repeat
                      ? 'MAIN_REPEAT_BUTTON_SELECTED_DEPRESSED'
                      : 'MAIN_REPEAT_BUTTON_DEPRESSED',
                  onTap: () async {
                    await _p.cycleRepeat();
                    if (mounted) setState(() {});
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  static String _pad(int? n, int w) =>
      n == null ? '' : n.toString().padLeft(w).substring(0, w);
}

class _Vis extends StatefulWidget {
  const _Vis({required this.player, required this.mode});
  final PlayerController player;
  final int mode;
  @override
  State<_Vis> createState() => _VisState();
}

class _VisState extends State<_Vis> {
  Stream<List<double>>? _stream;
  int? _for;

  // flux créé une fois par mode (sinon chaque redessin le coupe et le relance)
  Stream<List<double>>? _streamFor(int mode) {
    if (_for != mode) {
      _for = mode;
      _stream = switch (mode) {
        0 => widget.player.spectrum,
        1 => widget.player.wave,
        _ => null,
      };
    }
    return _stream;
  }

  @override
  Widget build(BuildContext context) {
    final stream = _streamFor(widget.mode);
    if (stream == null) return const Visualizer(mode: 2, values: []);
    return StreamBuilder<List<double>>(
      stream: stream,
      builder: (_, s) =>
          Visualizer(mode: widget.mode, values: s.data ?? const []),
    );
  }
}
