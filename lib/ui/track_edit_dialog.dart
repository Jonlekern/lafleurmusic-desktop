import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../app_scope.dart';
import '../library/models.dart';
import '../library/scanner.dart';
import '../library/track_ops.dart';
import '../theme/colors.dart';
import 'dialog_frame.dart';
import 'message.dart';

/// Choisir un fichier audio (Remplacer par…).
Future<File?> pickAudioFile() async {
  final f = await openFile(
    acceptedTypeGroups: [
      XTypeGroup(label: 'Audio', extensions: musicExtensions.toList()),
    ],
  );
  return f == null ? null : File(f.path);
}

/// Remplacer par… (maquette 8c) : fichier choisi ou glissé, champs pré-remplis et modifiables.
Future<void> openReplace(
  BuildContext context,
  Track track, [
  File? file,
]) async {
  final app = AppScope.of(context);
  final ops = app.ops;
  if (ops == null) return;
  final s = app.strings;
  final source = file ?? await (app.pickAudio ?? pickAudioFile)();
  if (source == null || !context.mounted) return;
  final fields = await ops.readFields(source, track);
  if (!context.mounted) return;
  if (fields == null) {
    showMessage(context, s.notAudio(p.basename(source.path)));
    return;
  }
  final chosen = await showDialog<TrackFields>(
    context: context,
    barrierColor: const Color(0x8C000000),
    builder: (_) => TrackEditDialog(
      title: s.replaceTitle(track.title),
      fileName: p.basename(source.path),
      fields: fields,
      confirm: s.replaceAction,
    ),
  );
  if (chosen == null || !context.mounted) return;
  final r = await ops.replace(track, source, chosen);
  if (!r.ok && context.mounted) {
    showMessage(context, s.cannotWrite(r.failedPath ?? source.path));
  }
}

/// Modifier… : titre, artiste, album, numéro.
Future<void> openEdit(BuildContext context, Track track) async {
  final app = AppScope.of(context);
  final ops = app.ops;
  if (ops == null) return;
  final s = app.strings;
  final chosen = await showDialog<TrackFields>(
    context: context,
    barrierColor: const Color(0x8C000000),
    builder: (_) => TrackEditDialog(
      title: s.editTitle(track.title),
      fields: TrackFields(
        title: track.title,
        artist: track.artist,
        album: track.album,
        trackNo: track.trackNo,
      ),
      confirm: s.save,
    ),
  );
  if (chosen == null || !context.mounted) return;
  final r = await ops.edit(track, chosen);
  if (!r.ok && context.mounted) {
    showMessage(context, s.cannotWrite(r.failedPath ?? track.path));
  }
}

class TrackEditDialog extends StatefulWidget {
  const TrackEditDialog({
    super.key,
    required this.title,
    required this.fields,
    required this.confirm,
    this.fileName,
  });
  final String title, confirm;
  final String? fileName; // null : Modifier (pas de nouveau fichier)
  final TrackFields fields;
  @override
  State<TrackEditDialog> createState() => _TrackEditDialogState();
}

class _TrackEditDialogState extends State<TrackEditDialog> {
  late final _title = TextEditingController(text: widget.fields.title);
  late final _artist = TextEditingController(text: widget.fields.artist);
  late final _album = TextEditingController(text: widget.fields.album);
  late final _no = TextEditingController(
    text: widget.fields.trackNo?.toString() ?? '',
  );

  @override
  void dispose() {
    for (final c in [_title, _artist, _album, _no]) {
      c.dispose();
    }
    super.dispose();
  }

  void _ok() => Navigator.pop(
    context,
    TrackFields(
      title: _title.text.trim(),
      artist: _artist.text.trim(),
      album: _album.text.trim(),
      trackNo: int.tryParse(_no.text.trim()),
    ),
  );

  Widget _field(
    String label,
    TextEditingController c, {
    bool autofocus = false,
    bool number = false,
  }) => Padding(
    padding: const EdgeInsets.only(top: 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: LafleurColors.sub,
            fontSize: 11,
            letterSpacing: 1,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: c,
          autofocus: autofocus,
          keyboardType: number ? TextInputType.number : null,
          onSubmitted: (_) => _ok(),
          style: const TextStyle(fontSize: 14),
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: LafleurColors.bg,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF444444)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: LafleurColors.pink),
            ),
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context).strings;
    return DialogFrame(
      title: widget.title,
      cancel: s.cancel,
      confirm: widget.confirm,
      onConfirm: _ok,
      children: [
        if (widget.fileName != null)
          Text.rich(
            TextSpan(
              children: [
                TextSpan(text: s.newFile('')),
                TextSpan(
                  text: widget.fileName,
                  style: const TextStyle(
                    color: Color(0xFFEEEEEE),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            style: DialogFrame.body,
          ),
        _field(s.fieldTitle, _title, autofocus: true),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _field(s.fieldArtist, _artist)),
            const SizedBox(width: 12),
            Expanded(child: _field(s.fieldAlbum, _album)),
            const SizedBox(width: 12),
            SizedBox(width: 70, child: _field(s.fieldNo, _no, number: true)),
          ],
        ),
        if (widget.fileName != null) NoteBox(child: Text(s.replaceNote)),
      ],
    );
  }
}
