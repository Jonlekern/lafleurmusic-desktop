import 'dart:io';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../library/cover_prepare.dart';
import '../library/models.dart';
import '../tags/tag_writer.dart';
import '../theme/colors.dart';
import 'track_list.dart' show writeEdits;

/// Glisser une image sur la pochette d'une playlist : elle devient la pochette de tous ses morceaux.
class CoverDrop extends StatefulWidget {
  const CoverDrop({super.key, required this.tracks, required this.child});
  final List<Track> tracks;
  final Widget child;
  @override
  State<CoverDrop> createState() => _CoverDropState();
}

class _CoverDropState extends State<CoverDrop> {
  bool _hover = false;

  Future<void> _drop(DropDoneDetails d) async {
    setState(() => _hover = false);
    final app = AppScope.of(context);
    if (d.files.isEmpty || widget.tracks.isEmpty || app.writer == null) return;
    final jpg = await prepareCover(
      await File(d.files.first.path).readAsBytes(),
    );
    if (jpg == null || !mounted) return;
    await writeEdits(context, [
      for (final t in widget.tracks) TagEdit(path: t.path, cover: jpg),
    ]);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (widget.tracks.isEmpty) return widget.child;
    return DropTarget(
      onDragEntered: (_) => setState(() => _hover = true),
      onDragExited: (_) => setState(() => _hover = false),
      onDragDone: _drop,
      child: Stack(
        children: [
          widget.child,
          if (_hover)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0x66000000),
                  border: Border.all(color: LafleurColors.pink, width: 3),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(
                  Icons.image_rounded,
                  color: LafleurColors.pink,
                  size: 40,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
