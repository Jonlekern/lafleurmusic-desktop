import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

import '../../app_scope.dart';
import '../../skins/skin.dart';
import '../../skins/skins_folder.dart';
import '../../theme/colors.dart';
import 'eq_window.dart';
import 'main_window.dart';
import 'playlist_window.dart';
import 'winamp_scope.dart';

/// Taille de la fenêtre Winamp : 275 de large, 116 par fenêtre affichée, × l'échelle.
Size winampSize({required bool double, required bool eq, required bool pl}) {
  final k = double ? 2.0 : 1.0;
  return Size(275 * k, 116 * k * (1 + (eq ? 1 : 0) + (pl ? 1 : 0)));
}

String skinName(File f) => p.basenameWithoutExtension(f.path);

void _say(BuildContext context, String text) =>
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        backgroundColor: LafleurColors.bar,
        content: Text(text, style: const TextStyle(color: LafleurColors.text)),
      ),
    );

/// Relit le dossier des skins (le bouton Skins suit).
Future<void> refreshSkins(BuildContext context) async {
  final app = AppScope.of(context);
  final folder = app.skins;
  if (folder == null) return;
  app.skinFiles?.value = await folder.list();
}

/// Fichiers glissés sur la fenêtre : les .wsz sont copiés dans le dossier Skins.
Future<List<File>> addDroppedSkins(
  BuildContext context,
  List<String> paths,
) async {
  final app = AppScope.of(context);
  final folder = app.skins;
  if (folder == null) return const [];
  final added = <File>[];
  for (final path in paths.where(SkinsFolder.isSkin)) {
    final f = await folder.add(File(path));
    if (f != null) added.add(f);
  }
  if (added.isNotEmpty) app.skinFiles?.value = await folder.list();
  return added;
}

bool _opening = false; // un seul Winamp à la fois (double-clic sur le bouton)

/// Bouton Skins : la fenêtre devient le petit Winamp, avec le dernier skin utilisé
/// (ou le premier qui se lit, si celui-là est abîmé ou a disparu).
Future<void> openWinamp(BuildContext context) async {
  if (_opening) return;
  _opening = true;
  try {
    await _open(context);
  } finally {
    _opening = false;
  }
}

// prépare le skin et la fenêtre ; le garde-fou tombe dès que l'écran Winamp est poussé
Future<void> _open(BuildContext context) async {
  final app = AppScope.of(context);
  final folder = app.skins, settings = app.settings, window = app.window;
  if (folder == null || settings == null || window == null) return;
  final files = await folder.list();
  if (files.isEmpty) return;
  final saved = files.where((f) => p.basename(f.path) == settings.skin);
  File? file;
  Skin? skin;
  for (final f in [...saved, ...files.where((f) => !saved.contains(f))]) {
    skin = await Skin.load(f);
    if (skin != null) {
      file = f;
      break;
    }
  }
  if (!context.mounted) return;
  if (skin == null || file == null) {
    _say(context, app.strings.unreadableSkin(skinName(files.first)));
    return;
  }
  final ready = skin;
  settings.skin = p.basename(file.path);
  final size = winampSize(
    double: settings.winampDouble,
    eq: settings.winampEq,
    pl: settings.winampPl,
  );
  final previous = await window.enterWinamp(size);
  // relancée en Winamp, la fenêtre a sa taille de départ : on garde la taille LAFLEUR enregistrée
  if (!settings.winampMode) settings.lafleurSize = previous;
  settings.winampMode = true;
  app.saveSettings?.call();
  if (!context.mounted) return;
  _opening = false;
  await Navigator.of(context).push(
    PageRouteBuilder<void>(
      pageBuilder: (_, _, _) => WinampScreen(skin: ready),
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
    ),
  );
  await window.leaveWinamp(settings.lafleurSize);
  settings.winampMode = false;
  app.saveSettings?.call();
  if (context.mounted) await refreshSkins(context);
}

/// Les 3 fenêtres Winamp empilées (principale, égaliseur, playlist), comme à l'époque.
class WinampScreen extends StatefulWidget {
  const WinampScreen({super.key, required this.skin});
  final Skin skin;
  @override
  State<WinampScreen> createState() => _WinampScreenState();
}

class _WinampScreenState extends State<WinampScreen> {
  late Skin _skin = widget.skin;
  final _focus = FocusNode();

  AppScope get _app => AppScope.of(context);

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  void _changed() {
    final s = _app.settings!;
    _app.window?.resize(
      winampSize(double: s.winampDouble, eq: s.winampEq, pl: s.winampPl),
    );
    _app.saveSettings?.call();
    setState(() {});
  }

  Future<void> _use(File f) async {
    final skin = await Skin.load(f);
    if (!mounted) return;
    if (skin == null) {
      _say(context, _app.strings.unreadableSkin(skinName(f)));
      return;
    }
    _app.settings!.skin = p.basename(f.path);
    _app.saveSettings?.call();
    setState(() => _skin = skin);
  }

  Future<void> _menu(Offset at) async {
    // seulement les skins qui se lisent (déjà lus : immédiat grâce au cache)
    final files = <File>[
      for (final f in await _app.skins?.list() ?? const <File>[])
        if (await Skin.load(f) != null) f,
    ];
    if (!mounted) return;
    final s = _app.strings;
    final current = _app.settings?.skin;
    final pick = await showMenu<Object>(
      context: context,
      position: RelativeRect.fromLTRB(at.dx, at.dy, at.dx, at.dy),
      items: [
        for (final f in files)
          CheckedPopupMenuItem<Object>(
            value: f,
            checked: p.basename(f.path) == current,
            child: Text(skinName(f)),
          ),
        if (files.isNotEmpty) const PopupMenuDivider(),
        CheckedPopupMenuItem<Object>(
          value: 'double',
          checked: _app.settings?.winampDouble ?? true,
          child: Text(s.doubleSize),
        ),
        PopupMenuItem<Object>(value: 'back', child: Text(s.backToLafleur)),
      ],
    );
    if (!mounted || pick == null) return;
    if (pick is File) {
      await _use(pick);
    } else if (pick == 'double') {
      _toggleDouble();
    } else if (pick == 'back') {
      _exit();
    }
  }

  void _toggleDouble() {
    final st = _app.settings!;
    st.winampDouble = !st.winampDouble;
    _changed();
  }

  void _exit() => Navigator.of(context).maybePop();

  KeyEventResult _key(FocusNode _, KeyEvent e) {
    final cmd =
        HardwareKeyboard.instance.isMetaPressed ||
        HardwareKeyboard.instance.isControlPressed;
    if (e is KeyDownEvent && cmd && e.logicalKey == LogicalKeyboardKey.keyD) {
      _toggleDouble();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final app = _app;
    final st = app.settings!;
    final k = st.winampDouble ? 2.0 : 1.0;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Focus(
        focusNode: _focus,
        autofocus: true,
        onKeyEvent: _key,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onSecondaryTapDown: (d) => _menu(d.globalPosition),
          child: WinampScope(
            skin: _skin,
            scale: k,
            child: Align(
              alignment: Alignment.topLeft,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  MainWindow(
                    player: app.player,
                    eqOpen: st.winampEq,
                    plOpen: st.winampPl,
                    visMode: st.visMode,
                    onClose: _exit,
                    onMenu: () {
                      final box = context.findRenderObject() as RenderBox?;
                      _menu(
                        box?.localToGlobal(Offset(6 * k, 14 * k)) ??
                            Offset.zero,
                      );
                    },
                    onDragWindow: () => app.window?.startDrag(),
                    onToggleEq: () {
                      st.winampEq = !st.winampEq;
                      _changed();
                    },
                    onTogglePl: () {
                      st.winampPl = !st.winampPl;
                      _changed();
                    },
                    onVisMode: () {
                      st.visMode = (st.visMode + 1) % 3;
                      _changed();
                    },
                  ),
                  if (st.winampEq)
                    EqWindow(
                      equalizer: app.equalizer,
                      strings: app.strings,
                      onClose: () {
                        st.winampEq = false;
                        _changed();
                      },
                    ),
                  if (st.winampPl)
                    PlaylistWindow(
                      player: app.player,
                      onClose: () {
                        st.winampPl = false;
                        _changed();
                      },
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
