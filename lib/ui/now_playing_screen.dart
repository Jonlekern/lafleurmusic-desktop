import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_scope.dart';
import '../player/player.dart';
import '../theme/colors.dart';
import '../theme/widgets.dart';
import 'cover_image.dart';
import 'equalizer_panel.dart';
import 'now_panel.dart';
import 'playback_card.dart';
import 'player_bar.dart';

/// En cours (maquette 4) : onglets À suivre · Égaliseur · Lecture (maquette file-attente). Échap pour revenir.
class NowPlayingScreen extends StatefulWidget {
  const NowPlayingScreen({super.key});

  @override
  State<NowPlayingScreen> createState() => _NowPlayingScreenState();
}

class _NowPlayingScreenState extends State<NowPlayingScreen> {
  int? _tab; // 0 À suivre, 1 Égaliseur, 2 Lecture ; retenu dans les réglages

  void _choose(AppScope app, int tab) {
    setState(() => _tab = tab);
    final settings = app.settings;
    if (settings == null || settings.nowTab == tab) return;
    settings.nowTab = tab;
    app.saveSettings?.call();
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final tab = _tab ?? app.settings?.nowTab ?? 0;
    // pastilles comme sur le téléphone : bord et texte roses pour l'onglet choisi
    Widget pill(int k, String label) => GestureDetector(
      onTap: () => _choose(app, k),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            border: Border.all(
              color: tab == k ? LafleurColors.pink : LafleurColors.p.outline,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: tab == k ? LafleurColors.pink : LafleurColors.text,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
    final s = app.strings;
    return Focus(
      autofocus: true,
      onKeyEvent: (_, e) {
        if (e is KeyDownEvent && e.logicalKey == LogicalKeyboardKey.escape) {
          Navigator.of(context).maybePop();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Scaffold(
        body: Column(
          children: [
            const TitleBar(),
            Expanded(
              child: StreamBuilder<PlayerState>(
                stream: app.player.state,
                initialData: app.player.current,
                builder: (context, snap) {
                  final t = snap.data?.track;
                  final q = app.player.queue;
                  final cover = (MediaQuery.sizeOf(context).height * 0.52)
                      .clamp(220.0, 470.0);
                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(60, 46, 60, 30),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                color: LafleurColors.p.shadow,
                                blurRadius: 60,
                                offset: Offset(0, 20),
                              ),
                            ],
                          ),
                          child: CoverImage(
                            trackPath: t?.path,
                            size: cover,
                            radius: 8,
                          ),
                        ),
                        const SizedBox(width: 60),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 10),
                              if (t != null && q != null)
                                Text(
                                  s.nOfM(
                                    q.position + 1,
                                    q.order.length,
                                    t.album,
                                  ),
                                  style: TextStyle(
                                    color: LafleurColors.sub,
                                    fontSize: 14,
                                  ),
                                ),
                              const SizedBox(height: 10),
                              Text(
                                t?.title ?? '',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 46,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                t == null
                                    ? ''
                                    : (t.artist.isEmpty
                                          ? s.unknownArtist
                                          : t.artist),
                                style: const TextStyle(fontSize: 22),
                              ),
                              const SizedBox(height: 46),
                              Row(
                                children: [
                                  pill(0, s.upNextTab),
                                  const SizedBox(width: 8),
                                  pill(1, s.equalizer),
                                  const SizedBox(width: 8),
                                  pill(2, s.playbackCard),
                                ],
                              ),
                              const SizedBox(height: 16),
                              switch (tab) {
                                1 => EqualizerPanel(
                                  equalizer: app.equalizer,
                                  strings: s,
                                ),
                                2 => const PlaybackCard(),
                                _ => Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.fromLTRB(
                                    26,
                                    20,
                                    26,
                                    16,
                                  ),
                                  decoration: BoxDecoration(
                                    color: LafleurColors.panel,
                                    border: Border.all(
                                      color: LafleurColors.line,
                                    ),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: const UpNextSection(
                                    title: false,
                                    coverSize: 30,
                                  ),
                                ),
                              },
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const PlayerBar(eqOpen: true),
          ],
        ),
      ),
    );
  }
}

void openNowPlaying(BuildContext context) => Navigator.of(context).push(
  PageRouteBuilder<void>(
    pageBuilder: (_, _, _) => const NowPlayingScreen(),
    transitionsBuilder: (_, a, _, child) =>
        FadeTransition(opacity: a, child: child),
  ),
);
