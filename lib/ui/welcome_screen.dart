import 'dart:io';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../l10n/strings.dart';
import '../theme/colors.dart';
import '../theme/widgets.dart';

/// Premier lancement (maquette 1) : glisser un dossier, le choisir, ou prendre le dossier Musique.
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({
    super.key,
    required this.strings,
    required this.onFolder,
    this.progress,
    this.home,
    this.emptyFolder,
  });
  final Strings strings;
  final void Function(String path) onFolder;
  final (int, int)? progress; // (fait, total) pendant le scan
  final String? home; // dossier personnel (tests)
  final String? emptyFolder; // dossier choisi qui ne contenait aucune musique

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  bool _hover = false;

  String get _home =>
      widget.home ??
      Platform.environment['HOME'] ??
      Platform.environment['USERPROFILE'] ??
      '';

  Future<void> _choose() async {
    final path = await getDirectoryPath(
      confirmButtonText: widget.strings.chooseFolder.replaceAll('…', ''),
    );
    if (path != null) widget.onFolder(path);
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.strings;
    final progress = widget.progress;
    return Scaffold(
      body: Column(
        children: [
          const TitleBar(),
          Expanded(
            child: DropTarget(
              onDragEntered: (_) => setState(() => _hover = true),
              onDragExited: (_) => setState(() => _hover = false),
              onDragDone: (d) {
                setState(() => _hover = false);
                final dirs = d.files
                    .map((f) => f.path)
                    .where((x) => Directory(x).existsSync());
                if (dirs.isNotEmpty) widget.onFolder(dirs.first);
              },
              // fenêtre trop petite : on fait défiler (molette, trackpad) ; sinon le contenu reste centré
              child: LayoutBuilder(
                builder: (context, box) => SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: box.maxHeight,
                      minWidth: box.maxWidth,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 30),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Image.asset('assets/fleur.png', width: 150),
                            const SizedBox(height: 26),
                            Text(
                              s.whereIsMusic,
                              style: const TextStyle(
                                fontSize: 40,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              s.organizesAlone,
                              style: TextStyle(
                                fontSize: 17,
                                color: LafleurColors.sub,
                              ),
                            ),
                            const SizedBox(height: 40),
                            CustomPaint(
                              painter: DashedBorderPainter(
                                color: _hover
                                    ? LafleurColors.pink
                                    : LafleurColors.p.faintest,
                              ),
                              child: SizedBox(
                                width: 640,
                                height: 220,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.folder_rounded,
                                      size: 46,
                                      color: _hover
                                          ? LafleurColors.pink
                                          : LafleurColors.p.icon,
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      progress == null
                                          ? s.dropFolderHere
                                          : '${s.scanning} ${progress.$1} / ${progress.$2}',
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    if (progress == null)
                                      Text(
                                        s.folderOrNas,
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: LafleurColors.sub,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 30),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                PillButton(
                                  label: s.chooseFolder,
                                  primary: true,
                                  onPressed: progress == null ? _choose : null,
                                ),
                                const SizedBox(width: 16),
                                PillButton(
                                  label: s.useMusicFolder,
                                  onPressed: progress == null
                                      ? () => widget.onFolder(
                                          p.join(_home, 'Music'),
                                        )
                                      : null,
                                ),
                              ],
                            ),
                            if (widget.emptyFolder != null) ...[
                              const SizedBox(height: 22),
                              Text(
                                s.noMusicIn(widget.emptyFolder!),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: LafleurColors.pink,
                                ),
                              ),
                            ],
                            const SizedBox(height: 34),
                            Text(
                              s.nasHint,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                color: LafleurColors.sub,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
