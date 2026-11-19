import 'dart:io';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../library/models.dart';
import '../library/scanner.dart';
import '../theme/colors.dart';
import 'delete_dialog.dart';
import 'track_edit_dialog.dart';

const danger = Color(0xFFFF6B6B); // maquette 8b

enum _Action { playNext, enqueue, edit, replace, delete }

PopupMenuItem<_Action> _item(_Action a, String label, {Color? color}) =>
    PopupMenuItem(
      value: a,
      height: 36,
      child: Text(label, style: TextStyle(fontSize: 14, color: color)),
    );

/// Menu clic droit d'un morceau (maquette 8a).
Future<void> showTrackMenu(BuildContext context, Offset at, Track track) async {
  final app = AppScope.of(context);
  final s = app.strings;
  final canEdit = app.writer != null && app.ops != null && !track.missing;
  final a = await showMenu<_Action>(
    context: context,
    position: RelativeRect.fromLTRB(at.dx, at.dy, at.dx, at.dy),
    color: LafleurColors.p.menu,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(10),
      side: BorderSide(color: LafleurColors.p.menuLine),
    ),
    items: [
      _item(_Action.playNext, s.playNextAction),
      _item(_Action.enqueue, s.addToQueue),
      if (canEdit) ...[
        const PopupMenuDivider(),
        _item(_Action.edit, s.editTrack),
        _item(_Action.replace, s.replaceWith),
        const PopupMenuDivider(),
        _item(_Action.delete, s.deleteTrack, color: danger),
      ],
    ],
  );
  if (a == null || !context.mounted) return;
  switch (a) {
    case _Action.playNext:
      await app.player.playNext([track]);
    case _Action.enqueue:
      await app.player.enqueue([track]);
    case _Action.edit:
      await openEdit(context, track);
    case _Action.replace:
      await openReplace(context, track);
    case _Action.delete:
      await confirmDelete(context, track);
  }
}

/// Menu clic droit d'un album ou d'un artiste : ajouter tous ses morceaux, dans l'ordre.
Future<void> showTracksMenu(
  BuildContext context,
  Offset at,
  Future<List<Track>> Function() tracks,
) async {
  final app = AppScope.of(context);
  final s = app.strings;
  final a = await showMenu<_Action>(
    context: context,
    position: RelativeRect.fromLTRB(at.dx, at.dy, at.dx, at.dy),
    color: LafleurColors.p.menu,
    items: [
      _item(_Action.playNext, s.playNextAction),
      _item(_Action.enqueue, s.addToQueue),
    ],
  );
  if (a == null) return;
  final list = await tracks();
  if (a == _Action.playNext) {
    await app.player.playNext(list);
  } else {
    await app.player.enqueue(list);
  }
}

/// Une ligne de morceau : clic droit → menu ; fichier audio glissé dessus → Remplacer.
class TrackMenuArea extends StatefulWidget {
  const TrackMenuArea({super.key, required this.track, required this.child});
  final Track track;
  final Widget child;
  @override
  State<TrackMenuArea> createState() => _TrackMenuAreaState();
}

class _TrackMenuAreaState extends State<TrackMenuArea> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    Widget child = GestureDetector(
      behavior: HitTestBehavior.translucent,
      onSecondaryTapUp: (d) =>
          showTrackMenu(context, d.globalPosition, widget.track),
      child: widget.child,
    );
    if (app.ops == null || app.writer == null || widget.track.missing) {
      return child;
    }
    return DropTarget(
      onDragEntered: (_) => setState(() => _hover = true),
      onDragExited: (_) => setState(() => _hover = false),
      onDragDone: (d) {
        setState(() => _hover = false);
        // un seul fichier audio (un .wsz glissé ici va au dossier Skins, pas en remplacement)
        if (d.files.length != 1 || !Scanner.isMusic(d.files.single.path)) {
          return;
        }
        openReplace(context, widget.track, File(d.files.single.path));
      },
      child: DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          border: _hover
              ? Border.all(color: LafleurColors.pink, width: 2)
              : null,
          borderRadius: BorderRadius.circular(6),
        ),
        child: child,
      ),
    );
  }
}

/// Trackpad : deux doigts vers la gauche sur une ligne → « Lire ensuite » (bandeau rose, comme sur le téléphone).
/// La souris n'est pas concernée : glisser une ligne la dépose sur une playlist ou change l'ordre.
class SwipeToPlayNext extends StatefulWidget {
  const SwipeToPlayNext({super.key, required this.track, required this.child});
  final Track track;
  final Widget child;

  /// Assez loin pour déclencher ; le bandeau ne dépasse pas [band].
  static const trigger = 80.0, band = 130.0;

  @override
  State<SwipeToPlayNext> createState() => _SwipeToPlayNextState();
}

class _SwipeToPlayNextState extends State<SwipeToPlayNext>
    with SingleTickerProviderStateMixin {
  late final AnimationController _back = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 180),
  )..addListener(() => setState(() => _dx = _from * (1 - _back.value)));
  double _dx = 0, _from = 0; // décalage de la ligne (négatif = vers la gauche)
  bool? _horizontal; // décidé au début du geste : horizontal (pour nous) ou vertical (défilement)

  @override
  void dispose() {
    _back.dispose();
    super.dispose();
  }

  void _update(Offset pan) {
    // le sens se décide une fois le geste un peu engagé
    _horizontal ??= pan.distance < 6 ? null : pan.dx.abs() > pan.dy.abs();
    if (_horizontal != true) return;
    setState(() => _dx = pan.dx.clamp(-SwipeToPlayNext.band, 0));
  }

  void _end() {
    if (_horizontal == true && _dx <= -SwipeToPlayNext.trigger) {
      AppScope.of(context).player.playNext([widget.track]);
    }
    _horizontal = null;
    _from = _dx;
    _back.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final w = -_dx;
    final s = AppScope.of(context).strings;
    return Listener(
      onPointerPanZoomStart: (_) {
        _back.stop();
        _horizontal = null;
      },
      onPointerPanZoomUpdate: (e) => _update(e.pan),
      onPointerPanZoomEnd: (_) => _end(),
      child: Stack(
        children: [
          Transform.translate(offset: Offset(_dx, 0), child: widget.child),
          if (w > 0)
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              width: w,
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: LafleurColors.pink,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: w >= 110
                    ? Text(
                        s.swipePlayNext,
                        maxLines: 1,
                        style: const TextStyle(
                          color: LafleurColors.ink,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      )
                    : null,
              ),
            ),
        ],
      ),
    );
  }
}
