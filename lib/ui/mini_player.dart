import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_scope.dart';
import '../player/player.dart';
import '../theme/colors.dart';
import 'player_controls.dart';
import 'window_steps.dart';

/// Le mini-lecteur (fenêtre de moins de 300 de haut) : titre, boutons + volume, barre de temps.
class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    final player = AppScope.of(context).player;
    return Focus(
      autofocus: true,
      onKeyEvent: (_, e) {
        if (e is! KeyDownEvent) return KeyEventResult.ignored;
        if (e.logicalKey == LogicalKeyboardKey.space) {
          player.toggle();
        } else if (e.logicalKey == LogicalKeyboardKey.arrowRight) {
          player.next();
        } else if (e.logicalKey == LogicalKeyboardKey.arrowLeft) {
          player.previous();
        } else {
          return KeyEventResult.ignored;
        }
        return KeyEventResult.handled;
      },
      child: Container(
        color: LafleurColors.bar,
        width: double.infinity,
        height: double.infinity,
        child: StreamBuilder<PlayerState>(
          stream: player.state,
          initialData: player.current,
          builder: (context, snap) {
            final st = snap.data ?? const PlayerState();
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    height: 18,
                    child: Text(
                      st.track?.title ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        PlaybackButtons(st: st),
                        const SizedBox(width: 12),
                        const VolumeControl(),
                      ],
                    ),
                  ),
                  ProgressRow(st: st, width: 380),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Fenêtre basse : le mini-lecteur à la place de la page, qui reste vivante derrière (écran, défilement).
class WindowSteps extends StatelessWidget {
  const WindowSteps({super.key, required this.child, this.off});
  final Widget child;
  final bool Function()?
  off; // skin Winamp ouvert : sa petite fenêtre n'est pas le mini-lecteur

  @override
  Widget build(BuildContext context) {
    if (off?.call() == true ||
        stepFor(MediaQuery.sizeOf(context)) != WindowStep.mini) {
      return child;
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        Offstage(child: child),
        const Positioned.fill(child: MiniPlayer()),
      ],
    );
  }
}
