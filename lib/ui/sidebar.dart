import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../library/models.dart';
import '../theme/colors.dart';
import '../theme/widgets.dart';
import 'cover_image.dart';
import 'track_menu.dart';
import '../library/playlist_ops.dart';
import 'track_list.dart' show writeEdits;
import 'coverflow_screen.dart';

enum LibraryView { album, songs, toRepair, artists, genres, top }

/// Barre latérale (maquette 2) : bibliothèque, playlists (= albums), outils.
class Sidebar extends StatelessWidget {
  const Sidebar({
    super.key,
    required this.view,
    required this.album,
    required this.onAlbum,
    required this.onView,
    this.pending = const [],
    this.creating = false,
    this.onStartCreate,
    this.onCreate,
  });
  final List<String> pending; // nouvelles playlists encore vides
  final bool creating;
  final VoidCallback? onStartCreate;
  final void Function(String name)? onCreate;
  final LibraryView view;
  final String? album;
  final void Function(String album) onAlbum;
  final void Function(LibraryView view) onView;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final s = app.strings;
    return Container(
      width: 240,
      decoration: BoxDecoration(
        color: LafleurColors.panel,
        border: Border(right: BorderSide(color: LafleurColors.line)),
      ),
      padding: const EdgeInsets.fromLTRB(12, 18, 12, 12),
      child: StreamBuilder<List<Album>>(
        stream: app.db.watchAlbums(),
        builder: (context, snap) {
          final albums = snap.data ?? const <Album>[];
          return ListView(
            children: [
              _Head(s.library),
              _Item(
                icon: Icons.view_carousel_rounded,
                label: s.coverFlow,
                onTap: () => openCoverflow(context, onOpen: onAlbum),
              ),
              _Item(
                icon: Icons.music_note_rounded,
                label: s.songs,
                selected: view == LibraryView.songs,
                onTap: () => onView(LibraryView.songs),
              ),
              _Item(
                icon: Icons.person_rounded,
                label: s.artists,
                selected: view == LibraryView.artists,
                onTap: () => onView(LibraryView.artists),
              ),
              _Item(
                icon: Icons.album_rounded,
                label: s.genres,
                selected: view == LibraryView.genres,
                onTap: () => onView(LibraryView.genres),
              ),
              _Item(
                icon: Icons.star_rounded,
                label: s.top100,
                selected: view == LibraryView.top,
                onTap: () => onView(LibraryView.top),
              ),
              _Head(s.playlists),
              for (final a in albums)
                _Drop(
                  album: a.name,
                  child: GestureDetector(
                    // clic droit : Lire ensuite / Ajouter à la file pour tout l'album
                    onSecondaryTapUp: (d) => showTracksMenu(
                      context,
                      d.globalPosition,
                      () => app.db.watchAlbumTracks(a.name).first,
                    ),
                    child: _Item(
                      leading: CoverImage(
                        trackPath: a.coverTrackPath,
                        size: 26,
                      ),
                      label: a.name.isEmpty ? s.unknownArtist : a.name,
                      selected: view == LibraryView.album && a.name == album,
                      onTap: () => onAlbum(a.name),
                    ),
                  ),
                ),
              for (final n in pending.where(
                (n) => !albums.any((a) => a.name == n),
              ))
                _Drop(
                  album: n,
                  child: _Item(
                    icon: Icons.queue_music_rounded,
                    label: n,
                    sub: true,
                  ),
                ),
              if (creating)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  child: FocusOnShow(
                    builder: (node) => TextField(
                      key: const Key('new-playlist'),
                      focusNode: node,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: s.newPlaylist,
                        filled: true,
                        fillColor: LafleurColors.p.field,
                        border: InputBorder.none,
                      ),
                      onSubmitted: (v) => onCreate?.call(v.trim()),
                    ),
                  ),
                )
              else
                _Item(
                  icon: Icons.add_rounded,
                  label: s.newPlaylist,
                  enabled: app.writer != null,
                  sub: true,
                  onTap: onStartCreate,
                ),
              _Head(s.tools),
              StreamBuilder<int>(
                stream: app.db.watchToRepairCount(),
                builder: (_, c) => _Item(
                  icon: Icons.auto_fix_high_rounded,
                  label: s.toRepair,
                  badge: (c.data ?? 0) > 0 ? '${c.data}' : null,
                  selected: view == LibraryView.toRepair,
                  onTap: () => onView(LibraryView.toRepair),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Déposer un morceau sur une playlist : son album change.
class _Drop extends StatelessWidget {
  const _Drop({required this.album, required this.child});
  final String album;
  final Widget child;
  @override
  Widget build(BuildContext context) => DragTarget<Track>(
    onWillAcceptWithDetails: (d) => d.data.album != album,
    onAcceptWithDetails: (d) =>
        writeEdits(context, [moveToPlaylistEdit(d.data, album)]),
    builder: (_, cand, _) => Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: cand.isEmpty ? Colors.transparent : LafleurColors.pink,
          width: 2,
        ),
      ),
      child: child,
    ),
  );
}

class _Head extends StatelessWidget {
  const _Head(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(10, 14, 10, 8),
    child: Text(
      text,
      style: TextStyle(
        color: LafleurColors.sub,
        fontSize: 11,
        letterSpacing: 0.9,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class _Item extends StatelessWidget {
  const _Item({
    this.icon,
    this.leading,
    required this.label,
    this.selected = false,
    this.onTap,
    this.enabled = true,
    this.badge,
    this.sub = false,
  });
  final IconData? icon;
  final Widget? leading;
  final String label;
  final bool selected, enabled, sub;
  final VoidCallback? onTap;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final fg = selected
        ? LafleurColors.ink
        : (sub || !enabled ? LafleurColors.sub : LafleurColors.text);
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? LafleurColors.pink : null,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              if (leading != null)
                leading!
              else if (icon != null)
                Icon(icon, size: 16, color: fg),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: fg,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
              if (badge != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: LafleurColors.pink,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Text(
                    badge!,
                    style: const TextStyle(
                      color: LafleurColors.ink,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
