import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../app_scope.dart';
import '../library/models.dart';
import '../theme/colors.dart';
import 'dialog_frame.dart';
import 'message.dart';

/// Supprimer le morceau… (maquette 8b) : confirmation avec la renumérotation exacte, puis Corbeille.
Future<void> confirmDelete(BuildContext context, Track track) async {
  final app = AppScope.of(context);
  final ops = app.ops;
  if (ops == null) return;
  final s = app.strings;
  final renumber = await ops.renumberPreview([track]);
  final dir = p.dirname(track.path);
  final count = (await app.db.watchAlbumTracks(track.album).first)
      .where((t) => p.dirname(t.path) == dir)
      .length;
  if (!context.mounted) return;
  final ok = await showDialog<bool>(
    context: context,
    barrierColor: const Color(0x8C000000),
    builder: (ctx) => DialogFrame(
      title: s.deleteQuestion(track.title),
      cancel: s.cancel,
      confirm: s.deleteAction,
      confirmColor: const Color(0xFFFF6B6B),
      onConfirm: () => Navigator.pop(ctx, true),
      children: [
        Text(s.deleteExplain(track.album), style: DialogFrame.body),
        if (renumber.isNotEmpty)
          NoteBox(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: '${s.renumberHead}\n'),
                  for (final (i, (t, no)) in renumber.indexed) ...[
                    if (i > 0) const TextSpan(text: ' · '),
                    TextSpan(text: '${t.trackNo} ${t.title} → '),
                    TextSpan(
                      text: '$no',
                      style: const TextStyle(
                        color: LafleurColors.pink,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                  TextSpan(text: '\n${s.albumNowHas(count - 1)}'),
                ],
              ),
            ),
          ),
      ],
    ),
  );
  if (ok != true || !context.mounted) return;
  final r = await ops.delete([track]);
  if (!r.ok && context.mounted) {
    showMessage(context, s.trashFailed(p.basename(r.failedPath ?? track.path)));
  }
}
