import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_scope.dart';
import '../library/models.dart';
import '../player/player.dart';
import '../tags/tag_writer.dart';
import '../theme/colors.dart';
import '../theme/widgets.dart';
import 'cover_image.dart';
import 'cover_mosaic.dart';
import 'cover_drop.dart';
import 'track_menu.dart';
import 'repair_dialog.dart';
import '../library/playlist_ops.dart';
import 'format.dart';

/// En-tête de playlist + liste des morceaux (maquette 2). Un clic = jouer à partir de ce morceau.
class TrackList extends StatelessWidget {
  const TrackList({
    super.key,
    required this.title,
    required this.tracks,
    this.showHeader = true,
    this.onPlay,
    this.renamable = false,
    this.label,
    this.headerImage,
    this.albumColumn = false,
  });
  final Widget? headerImage; // à la place de la pochette (photo d'artiste)
  final bool albumColumn; // page d'artiste : colonne ALBUM au lieu d'ARTISTE
  final String? label; // au-dessus du titre ; null = ALBUM
  final bool renamable; // vue playlist (album) : le titre se renomme
  final String title;
  final VoidCallback? onPlay; // ex. rendre le clavier au lecteur après un clic
  final List<Track> tracks;
  final bool showHeader;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final s = app.strings;
    final minutes = tracks.fold<int>(0, (m, t) => m + t.durationMs) ~/ 60000;
    return Padding(
      padding: const EdgeInsets.fromLTRB(30, 26, 30, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showHeader)
            Padding(
              padding: const EdgeInsets.only(bottom: 26),
              // liste étroite : pas de grande pochette, le titre et les boutons ont la place
              child: LayoutBuilder(
                builder: (context, box) {
                  final cover = box.maxWidth >= 520;
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (cover)
                        Container(
                          decoration: BoxDecoration(
                            boxShadow: [
                              BoxShadow(
                                color: LafleurColors.p.shadow,
                                blurRadius: 40,
                                offset: Offset(0, 12),
                              ),
                            ],
                            shape: headerImage != null
                                ? BoxShape.circle
                                : BoxShape.rectangle,
                            borderRadius: headerImage != null
                                ? null
                                : BorderRadius.circular(6),
                          ),
                          child: CoverDrop(
                            tracks: renamable ? tracks : const [],
                            // un album : sa pochette ; une autre liste (Morceaux, Artiste…) : mosaïque de ses albums
                            child: headerImage != null
                                ? headerImage!
                                : renamable
                                ? CoverImage(
                                    trackPath: tracks.isEmpty
                                        ? null
                                        : tracks.first.path,
                                    size: 190,
                                    radius: 6,
                                  )
                                : CoverMosaic(tracks: tracks, size: 190),
                          ),
                        ),
                      if (cover) const SizedBox(width: 26),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              label ?? s.playlistLabel,
                              style: TextStyle(
                                color: LafleurColors.sub,
                                fontSize: 12,
                                letterSpacing: 1,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 6),
                            EditableTitle(
                              text: title,
                              // renommer = changer l'album de tous les morceaux (seulement pour une vraie playlist)
                              onRename: app.writer == null || !renamable
                                  ? null
                                  : (v) => writeEdits(context, [
                                      for (final t in tracks)
                                        TagEdit(path: t.path, album: v),
                                    ]),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${s.nSongs(tracks.length)} · ${s.minutes(minutes)}',
                              style: TextStyle(
                                color: LafleurColors.sub,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 18),
                            // fenêtre étroite : les boutons passent à la ligne
                            Wrap(
                              spacing: 12,
                              runSpacing: 10,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                PillButton(
                                  label: s.play,
                                  icon: Icons.play_arrow_rounded,
                                  primary: true,
                                  onPressed: tracks.isEmpty
                                      ? null
                                      : () => app.player.playTracks(tracks, 0),
                                ),
                                PillButton(
                                  label: s.shuffle,
                                  icon: Icons.shuffle_rounded,
                                  onPressed: tracks.isEmpty
                                      ? null
                                      : () => app.player.playTracks(
                                          tracks,
                                          0,
                                          shuffle: true,
                                        ),
                                ),
                                PillButton(
                                  label: s.repair,
                                  icon: Icons.auto_fix_high_rounded,
                                  onPressed:
                                      tracks.isEmpty ||
                                          app.writer == null ||
                                          app.musicbrainz == null
                                      ? null
                                      : () => openRepair(
                                          context,
                                          tracks
                                              .where(
                                                (t) =>
                                                    t.album ==
                                                    tracks.first.album,
                                              )
                                              .toList(),
                                        ),
                                ), // plan 3
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          _Row(
            no: '#',
            title: s.title,
            artist: albumColumn ? s.albumHeader : s.artist,
            time: s.duration,
            head: true,
          ),
          Expanded(
            child: StreamBuilder<PlayerState>(
              stream: app.player.state,
              initialData: app.player.current,
              builder: (context, snap) {
                final playing = snap.data?.track?.path;
                return ListView.builder(
                  itemCount: tracks.length,
                  itemBuilder: (_, i) {
                    final t = tracks[i];
                    final row = _Row(
                      key: ValueKey(t.path),
                      no: '${t.trackNo ?? i + 1}',
                      title: t.title,
                      artist: albumColumn
                          ? t.album
                          : (t.artist.isEmpty ? s.unknownArtist : t.artist),
                      time: clock(Duration(milliseconds: t.durationMs)),
                      selected: t.path == playing,
                      missing: t.missing,
                      onEdit: app.writer == null || t.missing
                          ? null
                          : (field, v) => _write(
                              context,
                              TagEdit(
                                path: t.path,
                                title: field == EditField.title ? v : null,
                                artist:
                                    field == EditField.artist && !albumColumn
                                    ? v
                                    : null,
                                album: field == EditField.artist && albumColumn
                                    ? v
                                    : null,
                              ),
                            ),
                      onTap: t.missing
                          ? null
                          : () {
                              onPlay?.call();
                              app.player.playTracks(tracks, i);
                            },
                    );
                    final menu = SwipeToPlayNext(
                      track: t,
                      child: TrackMenuArea(track: t, child: row),
                    );
                    if (app.writer == null || t.missing) return menu;
                    // glisser un morceau : sur une autre ligne (réordonner) ou sur une playlist de la barre latérale
                    final draggable = Draggable<Track>(
                      data: t,
                      feedback: DragGhost(track: t),
                      childWhenDragging: Opacity(opacity: 0.3, child: row),
                      child: menu,
                    );
                    if (!renamable) return draggable;
                    return DragTarget<Track>(
                      onWillAcceptWithDetails: (d) =>
                          d.data.path != t.path && tracks.contains(d.data),
                      onAcceptWithDetails: (d) => writeEdits(
                        context,
                        reorderEdits(tracks, tracks.indexOf(d.data), i),
                      ),
                      builder: (_, cand, _) => Container(
                        decoration: BoxDecoration(
                          border: Border(
                            top: BorderSide(
                              color: cand.isEmpty
                                  ? Colors.transparent
                                  : LafleurColors.pink,
                              width: 2,
                            ),
                          ),
                        ),
                        child: draggable,
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

enum EditField { title, artist }

/// Ligne de morceau : un clic joue tout de suite ; un double-clic sur le titre ou l'artiste le modifie.
/// Écrit dans les fichiers ; en cas de refus (lecture seule…), un message avec le nom du fichier.
Future<void> _write(BuildContext context, TagEdit edit) =>
    writeEdits(context, [edit]);

Future<void> writeEdits(BuildContext context, List<TagEdit> edits) async {
  final app = AppScope.of(context);
  final r = await app.writer?.apply(edits);
  if (r != null && !r.ok && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: LafleurColors.bar,
        content: Text(
          app.strings.cannotWrite(r.failedPath ?? ''),
          style: TextStyle(color: LafleurColors.text),
        ),
      ),
    );
  }
}

class _Row extends StatefulWidget {
  const _Row({
    super.key,
    required this.no,
    required this.title,
    required this.artist,
    required this.time,
    this.head = false,
    this.selected = false,
    this.missing = false,
    this.onTap,
    this.onEdit,
  });
  final String no, title, artist, time;
  final bool head, selected, missing;
  final VoidCallback? onTap;
  final void Function(EditField field, String value)? onEdit;

  @override
  State<_Row> createState() => _RowState();
}

class _RowState extends State<_Row> {
  EditField? _editing;
  final _lastDown = <EditField, Duration>{};
  late final _ctrl = TextEditingController();

  // double-clic repéré sans retarder le simple clic (le Listener ne participe pas à l'arène des gestes)
  void _down(EditField f, PointerDownEvent e) {
    final last = _lastDown[f];
    _lastDown[f] = e.timeStamp;
    if (widget.onEdit != null &&
        last != null &&
        e.timeStamp - last < const Duration(milliseconds: 400)) {
      setState(() {
        _editing = f;
        _ctrl.text = f == EditField.title ? widget.title : widget.artist;
        _ctrl.selection = TextSelection(
          baseOffset: 0,
          extentOffset: _ctrl.text.length,
        );
      });
    }
  }

  void _commit() {
    final f = _editing;
    final v = _ctrl.text.trim();
    setState(() => _editing = null);
    if (f != null &&
        v.isNotEmpty &&
        v != (f == EditField.title ? widget.title : widget.artist)) {
      widget.onEdit?.call(f, v);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Widget _cell(EditField f, String text, TextStyle style) {
    if (_editing == f) {
      return Focus(
        onKeyEvent: (_, e) {
          if (e is KeyDownEvent && e.logicalKey == LogicalKeyboardKey.escape) {
            setState(() => _editing = null);
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: FocusOnShow(
          builder: (node) => TextField(
            key: const Key('edit-field'),
            controller: _ctrl,
            focusNode: node,
            style: style.copyWith(color: LafleurColors.text),
            decoration: InputDecoration(
              isDense: true,
              border: InputBorder.none,
              filled: true,
              fillColor: LafleurColors.p.field,
            ),
            onSubmitted: (_) => _commit(),
          ),
        ),
      );
    }
    return Listener(
      onPointerDown: widget.head ? null : (e) => _down(f, e),
      child: Text(text, overflow: TextOverflow.ellipsis, style: style),
    );
  }

  @override
  Widget build(BuildContext context) {
    final w = widget;
    final fg = w.selected
        ? LafleurColors.ink
        : (w.head ? LafleurColors.sub : LafleurColors.p.rowText);
    TextStyle st(bool bold) => TextStyle(
      color: fg,
      fontSize: w.head ? 12 : 14,
      letterSpacing: w.head ? 0.7 : 0,
      fontWeight: bold || w.head ? FontWeight.w700 : FontWeight.w400,
    );
    return Opacity(
      opacity: w.missing ? 0.35 : 1,
      child: GestureDetector(
        onTap: () {
          if (_editing == null) w.onTap?.call();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: w.selected ? LafleurColors.pink : null,
            borderRadius: w.head ? null : BorderRadius.circular(8),
            border: w.head
                ? Border(bottom: BorderSide(color: LafleurColors.line))
                : null,
          ),
          child: LayoutBuilder(
            builder: (_, c) {
              // le titre garde au moins 200 ; l'artiste prend jusqu'à 260, disparaît s'il reste trop peu
              final artist = (c.maxWidth - 40 - 12 - 70 - 200).clamp(
                0.0,
                260.0,
              );
              return Row(
                children: [
                  SizedBox(
                    width: 40,
                    child: Text(
                      w.no,
                      style: st(false)
                          .copyWith(color: fg.withValues(alpha: 0.75)),
                    ),
                  ),
                  Expanded(child: _cell(EditField.title, w.title, st(true))),
                  const SizedBox(width: 12),
                  if (artist >= 80)
                    SizedBox(
                      width: artist,
                      child: _cell(EditField.artist, w.artist, st(false)),
                    ),
                  SizedBox(
                    width: 70,
                    child: Text(
                      w.time,
                      style: st(false)
                          .copyWith(color: fg.withValues(alpha: 0.75)),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Grand titre de playlist : double-clic pour le renommer.
class EditableTitle extends StatefulWidget {
  const EditableTitle({super.key, required this.text, this.onRename});
  final String text;
  final void Function(String value)? onRename;
  @override
  State<EditableTitle> createState() => _EditableTitleState();
}

class _EditableTitleState extends State<EditableTitle> {
  bool _editing = false;
  Duration? _last;
  late final _ctrl = TextEditingController();
  static const _style = TextStyle(fontSize: 44, fontWeight: FontWeight.w700);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_editing) {
      return Focus(
        onKeyEvent: (_, e) {
          if (e is KeyDownEvent && e.logicalKey == LogicalKeyboardKey.escape) {
            setState(() => _editing = false);
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: FocusOnShow(
          builder: (node) => TextField(
            key: const Key('edit-album'),
            controller: _ctrl,
            focusNode: node,
            style: _style,
            decoration: InputDecoration(
              isDense: true,
              border: InputBorder.none,
              filled: true,
              fillColor: LafleurColors.p.field,
            ),
            onSubmitted: (v) {
              setState(() => _editing = false);
              if (v.trim().isNotEmpty && v.trim() != widget.text) {
                widget.onRename?.call(v.trim());
              }
            },
          ),
        ),
      );
    }
    return Listener(
      onPointerDown: widget.onRename == null
          ? null
          : (e) {
              final last = _last;
              _last = e.timeStamp;
              if (last != null &&
                  e.timeStamp - last < const Duration(milliseconds: 400)) {
                setState(() {
                  _editing = true;
                  _ctrl.text = widget.text;
                });
              }
            },
      child: Text(
        widget.text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: _style,
      ),
    );
  }
}

/// Fantôme rose qui suit la souris pendant le glisser-déposer (maquette 2).
class DragGhost extends StatelessWidget {
  const DragGhost({super.key, required this.track});
  final Track track;
  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: Transform.rotate(
      angle: -0.026,
      child: Container(
        width: 520,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: LafleurColors.p.field,
          border: Border.all(color: LafleurColors.pink),
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: LafleurColors.p.shadow,
              blurRadius: 30,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Text(
          '${track.title}   ${track.artist}',
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 14,
            color: LafleurColors.text,
          ),
        ),
      ),
    ),
  );
}
