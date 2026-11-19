import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../player/player.dart';
import '../player/queue.dart';
import '../theme/colors.dart';
import '../theme/widgets.dart';
import 'format.dart';

/// Les pièces de la barre de lecture, partagées par la barre du bas et le mini-lecteur.

/// Aléatoire, précédent, rond rose Lecture / Pause, suivant, répéter.
class PlaybackButtons extends StatelessWidget {
  const PlaybackButtons({super.key, required this.st});
  final PlayerState st;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final q = app.player.queue;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _Btn(
          Icons.shuffle_rounded,
          on: q?.shuffle ?? false,
          onTap: app.player.toggleShuffle,
        ),
        _Btn(Icons.skip_previous_rounded, onTap: app.player.previous),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: InkWell(
            key: const Key('playpause'),
            onTap: app.player.toggle,
            customBorder: const CircleBorder(),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: LafleurColors.p.play,
                shape: BoxShape.circle,
              ),
              child: Icon(
                st.playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: LafleurColors.ink,
              ),
            ),
          ),
        ),
        _Btn(Icons.skip_next_rounded, onTap: app.player.next),
        _Btn(
          q?.repeat == Repeat.one
              ? Icons.repeat_one_rounded
              : Icons.repeat_rounded,
          on: (q?.repeat ?? Repeat.off) != Repeat.off,
          onTap: app.player.cycleRepeat,
        ),
      ],
    );
  }
}

/// Temps écoulé, barre de progression (zone cliquable de 26, rond qui se glisse), temps restant.
/// [width] : la largeur voulue ; plus étroite si la place manque.
class ProgressRow extends StatefulWidget {
  const ProgressRow({super.key, required this.st, this.width = 560});
  final PlayerState st;
  final double width;

  @override
  State<ProgressRow> createState() => _ProgressRowState();
}

class _ProgressRowState extends State<ProgressRow> {
  double? _drag; // le rond qu'on glisse (0 à 1)

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final st = widget.st;
    final total = st.duration.inMilliseconds;
    final played = total > 0
        ? (st.position.inMilliseconds / total).clamp(0.0, 1.0)
        : 0.0;
    final time = TextStyle(color: LafleurColors.sub, fontSize: 12);
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: widget.width),
      child: Row(
        children: [
          Text(clock(st.position), style: time),
          const SizedBox(width: 10),
          Expanded(
            child: LayoutBuilder(
              builder: (_, c) {
                double at(double dx) => (dx / c.maxWidth).clamp(0.0, 1.0);
                void go(double frac) => total > 0
                    ? app.player.seek(
                        Duration(milliseconds: (frac * total).round()),
                      )
                    : null;
                final f = _drag ?? played;
                // zone cliquable plus haute que la ligne, et le rond se glisse
                return GestureDetector(
                  key: const Key('progress'),
                  behavior: HitTestBehavior.opaque,
                  onTapUp: (d) => go(at(d.localPosition.dx)),
                  onHorizontalDragStart: (d) =>
                      setState(() => _drag = at(d.localPosition.dx)),
                  onHorizontalDragUpdate: (d) =>
                      setState(() => _drag = at(d.localPosition.dx)),
                  onHorizontalDragEnd: (_) {
                    final d = _drag;
                    setState(() => _drag = null);
                    if (d != null) go(d);
                  },
                  onHorizontalDragCancel: () => setState(() => _drag = null),
                  child: SizedBox(
                    height: 26,
                    child: Stack(
                      alignment: Alignment.centerLeft,
                      children: [
                        Container(
                          height: 5,
                          decoration: BoxDecoration(
                            color: LafleurColors.p.track,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        Container(
                          height: 5,
                          width: c.maxWidth * f,
                          decoration: BoxDecoration(
                            color: LafleurColors.pink,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        Positioned(
                          // très étroite : le rond reste au bord sans planter
                          left: (c.maxWidth * f - 6.5).clamp(
                            0,
                            (c.maxWidth - 13).clamp(0.0, double.infinity),
                          ),
                          child: Container(
                            width: 13,
                            height: 13,
                            decoration: knobDecoration(),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 10),
          Text('-${clock(st.duration - st.position)}', style: time),
        ],
      ),
    );
  }
}

/// Haut-parleur + curseur de volume (90 de large).
class VolumeControl extends StatefulWidget {
  const VolumeControl({super.key});
  @override
  State<VolumeControl> createState() => _VolumeControlState();
}

class _VolumeControlState extends State<VolumeControl> {
  double? _volume; // lu sur le lecteur au premier dessin

  @override
  Widget build(BuildContext context) {
    final player = AppScope.of(context).player;
    final v = _volume ?? player.volume.clamp(0.0, 100.0);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.volume_up_rounded, size: 18, color: LafleurColors.sub),
        SizedBox(
          width: 90,
          child: SliderTheme(
            data: const SliderThemeData(
              trackHeight: 3,
              thumbShape: RoundSliderThumbShape(enabledThumbRadius: 6),
              overlayShape: RoundSliderOverlayShape(overlayRadius: 10),
            ),
            child: Slider(
              value: v,
              max: 100,
              activeColor: LafleurColors.text,
              inactiveColor: LafleurColors.p.track,
              onChanged: (x) {
                setState(() => _volume = x);
                player.setVolume(x);
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _Btn extends StatelessWidget {
  const _Btn(this.icon, {this.on = false, required this.onTap});
  final IconData icon;
  final bool on;
  final Future<void> Function() onTap;
  @override
  Widget build(BuildContext context) => IconButton(
    onPressed: onTap,
    icon: Icon(
      icon,
      size: 20,
      color: on ? LafleurColors.pink : LafleurColors.text,
    ),
  );
}
