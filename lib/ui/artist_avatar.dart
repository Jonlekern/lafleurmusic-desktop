import 'dart:async';

import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../artists/artist_store.dart';

/// Photo ronde d'un artiste (cherchée toute seule), la fleur LAFLEUR en attendant ou s'il n'y en a pas.
class ArtistAvatar extends StatefulWidget {
  const ArtistAvatar({super.key, required this.name, required this.size});
  final String name;
  final double size;
  @override
  State<ArtistAvatar> createState() => _ArtistAvatarState();
}

class _ArtistAvatarState extends State<ArtistAvatar> {
  StreamSubscription<String>? _sub;
  Future<ArtistEntry>? _entry;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final store = AppScope.of(context).artists;
    _entry ??= store?.get(widget.name);
    _sub ??= store?.changes.listen((n) {
      if (n == widget.name && mounted) {
        setState(() => _entry = store.get(widget.name));
      }
    });
  }

  @override
  void didUpdateWidget(ArtistAvatar old) {
    super.didUpdateWidget(old);
    if (old.name != widget.name) {
      _entry = AppScope.of(context).artists?.get(widget.name);
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fallback = Image.asset(
      'assets/fleur-tile.png',
      width: widget.size,
      height: widget.size,
      fit: BoxFit.cover,
    );
    return ClipOval(
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: FutureBuilder<ArtistEntry>(
          future: _entry,
          builder: (_, snap) {
            final f = snap.data?.photo;
            return f == null
                ? fallback
                : Image.file(
                    f,
                    width: widget.size,
                    height: widget.size,
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                  );
          },
        ),
      ),
    );
  }
}
