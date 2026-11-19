import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_scope.dart';
import '../player/player.dart';
import '../theme/colors.dart';
import 'player_controls.dart';
import 'window_steps.dart';

/// Le mini-lecteur (fenêtre de moins de 300 de haut) : titre, boutons + volume, barre de temps.
class MiniPlayer extends StatefulWidget {
  const MiniPlayer({super.key});
  @override
  State<MiniPlayer> createState() => _MiniPlayerState();
}

class _MiniPlayerState extends State<MiniPlayer> {
  final _focus = FocusNode(debugLabel: 'mini');

  @override
  void initState() {
    super.initState();
    // le clavier vient au mini-lecteur, même si la recherche l'avait (autofocus ne suffit pas)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final player = AppScope.of(context).player;
    return Focus(
      focusNode: _focus,
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
      // posé au-dessus du Navigator (MaterialApp.builder) : il lui faut son propre Material
      child: Material(
        color: LafleurColors.bar,
        child: SizedBox.expand(
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
    final mini =
        off?.call() != true &&
        stepFor(MediaQuery.sizeOf(context)) == WindowStep.mini;
    // même arbre dans les deux cas : la page garde son état ; cachée, elle ne prend plus le clavier
    return Stack(
      fit: StackFit.expand,
      children: [
        Offstage(
          offstage: mini,
          child: ExcludeFocus(
            excluding: mini,
            child: TickerMode(enabled: !mini, child: child),
          ),
        ),
        if (mini)
          // au-dessus du Navigator : une Overlay pour le curseur de volume
          Overlay(
            initialEntries: [OverlayEntry(builder: (_) => const MiniPlayer())],
          ),
      ],
    );
  }
}
