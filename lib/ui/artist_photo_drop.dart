import 'dart:io';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../library/cover_prepare.dart';
import '../theme/colors.dart';
import 'artist_avatar.dart';

/// Grande photo ronde d'un artiste ; glisser une image dessus la remplace (et l'appli n'y touche plus).
class ArtistPhotoDrop extends StatefulWidget {
  const ArtistPhotoDrop({super.key, required this.name, this.size = 190});
  final String name;
  final double size;
  @override
  State<ArtistPhotoDrop> createState() => _ArtistPhotoDropState();
}

class _ArtistPhotoDropState extends State<ArtistPhotoDrop> {
  bool _hover = false;

  Future<void> _drop(DropDoneDetails d) async {
    setState(() => _hover = false);
    final store = AppScope.of(context).artists;
    if (store == null || d.files.isEmpty) return;
    final jpg = await prepareCover(
      await File(d.files.first.path).readAsBytes(),
    );
    if (jpg != null) await store.setUserPhoto(widget.name, jpg);
  }

  @override
  Widget build(BuildContext context) => DropTarget(
    onDragEntered: (_) => setState(() => _hover = true),
    onDragExited: (_) => setState(() => _hover = false),
    onDragDone: _drop,
    child: Stack(
      children: [
        ArtistAvatar(name: widget.name, size: widget.size),
        if (_hover)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0x66000000),
                shape: BoxShape.circle,
                border: Border.all(color: LafleurColors.pink, width: 3),
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
