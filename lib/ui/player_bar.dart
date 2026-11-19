import 'dart:io';

import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../player/player.dart';
import '../theme/colors.dart';
import '../theme/widgets.dart';
import 'cover_image.dart';
import 'coverflow_screen.dart';
import 'now_playing_screen.dart';
import 'winamp/winamp_screen.dart';
import 'player_controls.dart';
import 'window_steps.dart';

/// Barre de lecture du bas (maquette 2).
class PlayerBar extends StatefulWidget {
  const PlayerBar({super.key, this.eqOpen = false});
  final bool eqOpen; // sur l'écran En cours : la puce EQ est allumée
  @override
  State<PlayerBar> createState() => _PlayerBarState();
}

class _PlayerBarState extends State<PlayerBar> {
  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final s = app.strings;
    // moyenne : plus de pochette ni de titre à gauche, le titre passe au-dessus de la barre de temps
    final medium = stepFor(MediaQuery.sizeOf(context)) != WindowStep.large;
    return Container(
      height: medium
          ? 96
          : 84, // moyenne : le titre s'ajoute au-dessus de la barre de temps
      decoration: BoxDecoration(
        color: LafleurColors.bar,
        border: Border(top: BorderSide(color: LafleurColors.line)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: StreamBuilder<PlayerState>(
        stream: app.player.state,
        initialData: app.player.current,
        builder: (context, snap) {
          final st = snap.data ?? const PlayerState();
          final t = st.track;
          return Row(
            children: [
              if (!medium)
                SizedBox(
                  width: 300,
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: widget.eqOpen
                            ? null
                            : () => openNowPlaying(context),
                        child: CoverImage(trackPath: t?.path, size: 54),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              t?.title ?? '',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              t == null
                                  ? ''
                                  : (t.artist.isEmpty
                                        ? s.unknownArtist
                                        : t.artist),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: LafleurColors.sub,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (medium)
                      Text(
                        t?.title ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: PlaybackButtons(st: st),
                    ),
                    // la zone cliquable de la barre (26) remplace l'écart
                    ProgressRow(st: st),
                  ],
                ),
              ),
              // au moins 300 (comme la partie gauche), plus large si le bouton Skins s'ajoute
              ConstrainedBox(
                constraints: BoxConstraints(minWidth: medium ? 0 : 300),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    ValueListenableBuilder(
                      valueListenable: app.equalizer,
                      builder: (_, eq, _) => LafleurChip(
                        label: 'EQ',
                        on: widget.eqOpen || eq.enabled,
                        onPressed: widget.eqOpen
                            ? null
                            : () => openNowPlaying(context),
                      ),
                    ),
                    // Skins : seulement s'il y a des skins dans le dossier
                    if (app.skinFiles != null)
                      ValueListenableBuilder<List<File>>(
                        valueListenable: app.skinFiles!,
                        builder: (context, files, _) => files.isEmpty
                            ? const SizedBox.shrink()
                            : Padding(
                                padding: const EdgeInsets.only(left: 12),
                                child: LafleurChip(
                                  label: s.skins,
                                  onPressed: () => openWinamp(context),
                                ),
                              ),
                      ),
                    const SizedBox(width: 12),
                    LafleurChip(
                      label: s.coverFlow,
                      onPressed: () => openCoverflow(context),
                    ),
                    const SizedBox(width: 12),
                    const VolumeControl(),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
