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
    color: const Color(0xFF232323),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(10),
      side: const BorderSide(color: Color(0xFF3A3A3A)),
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
    color: const Color(0xFF232323),
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
