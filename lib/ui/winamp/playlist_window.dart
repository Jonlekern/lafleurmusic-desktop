import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../library/models.dart';
import '../../player/player.dart';
import '../../skins/skin.dart';
import 'bitmap_text.dart';
import 'sprite.dart';
import 'winamp_scope.dart';

/// Playlist de Winamp (275 × 116) : la file en cours, couleurs et police du skin. Positions : Webamp (MIT).
class PlaylistWindow extends StatefulWidget {
  const PlaylistWindow({
    super.key,
    required this.player,
    required this.onClose,
  });
  final PlayerController player;
  final VoidCallback onClose;
  @override
  State<PlaylistWindow> createState() => _PlaylistWindowState();
}

class _PlaylistWindowState extends State<PlaylistWindow> {
  static const _rows = 4; // 58 px de liste / 13 px par ligne
  int _top = 0;
  int? _selected;
  Duration? _lastDown;
  int? _lastRow;
  final _focus = FocusNode();

  PlayerController get _p => widget.player;

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  void _scroll(int by, int count) => setState(
    () => _top = (_top + by).clamp(0, (count - _rows).clamp(0, count)),
  );

  // simple clic : sélection ; double-clic : jouer (comme Winamp)
  void _down(int i, PointerDownEvent e, List<Track> order) {
    _focus.requestFocus();
    final last = _lastDown;
    final double =
        last != null &&
        _lastRow == i &&
        e.timeStamp - last < const Duration(milliseconds: 400);
    _lastDown = e.timeStamp;
    _lastRow = i;
    setState(() => _selected = i);
    if (double) _p.jumpTo(i);
  }

  KeyEventResult _key(FocusNode _, KeyEvent e) {
    final sel = _selected;
    if (e is KeyDownEvent &&
        sel != null &&
        (e.logicalKey == LogicalKeyboardKey.delete ||
            e.logicalKey == LogicalKeyboardKey.backspace)) {
      _p.removeAt(sel);
      setState(() => _selected = null);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  static String _len(Duration d) =>
      '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final w = WinampScope.of(context);
    final k = w.scale;
    final skin = w.skin;
    return StreamBuilder<PlayerState>(
      stream: _p.state,
      initialData: _p.current,
      builder: (context, snap) {
        final q = _p.queue;
        final order = q?.order ?? const <Track>[];
        final cur = q?.position;
        final total = order.fold<int>(0, (s, t) => s + t.durationMs);
        final style = TextStyle(
          fontFamily: skin.playlistFont,
          fontFamilyFallback: const ['Arial', 'Helvetica'],
          fontSize: 9 * k,
          height: 1,
        );
        return Focus(
          focusNode: _focus,
          onKeyEvent: _key,
          child: Listener(
            onPointerSignal: (e) {
              if (e is PointerScrollEvent) {
                _scroll(e.scrollDelta.dy > 0 ? 4 : -4, order.length);
              }
            },
            child: SizedBox(
              width: 275 * k,
              height: 116 * k,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ColoredBox(color: skin.playlistColor('normalbg')),
                  ),
                  // cadre : haut (coins, carrelage, titre), côtés, bas
                  const At(0, 0, Sprite('PLAYLIST_TOP_LEFT_SELECTED')),
                  for (var x = 25.0; x < 250; x += 25)
                    At(x, 0, const Sprite('PLAYLIST_TOP_TILE_SELECTED')),
                  const At(87.5, 0, Sprite('PLAYLIST_TITLE_BAR_SELECTED')),
                  const At(
                    250,
                    0,
                    Sprite('PLAYLIST_TOP_RIGHT_CORNER_SELECTED'),
                  ),
                  for (final y in const [20.0, 49.0]) ...[
                    At(0, y, const Sprite('PLAYLIST_LEFT_TILE')),
                    At(255, y, const Sprite('PLAYLIST_RIGHT_TILE')),
                  ],
                  const At(0, 78, Sprite('PLAYLIST_BOTTOM_LEFT_CORNER')),
                  const At(125, 78, Sprite('PLAYLIST_BOTTOM_RIGHT_CORNER')),
                  At(
                    264,
                    3,
                    GestureDetector(
                      key: const Key('wa-pl-close'),
                      behavior: HitTestBehavior.opaque,
                      onTap: widget.onClose,
                      child: SizedBox(width: 9 * k, height: 9 * k),
                    ),
                  ),
                  At(
                    260,
                    20 +
                        (order.length <= _rows
                            ? 0
                            : 40 * _top / (order.length - _rows)),
                    const Sprite('PLAYLIST_SCROLL_HANDLE'),
                  ),
                  At(
                    132,
                    88,
                    BitmapText(
                      '${cur == null || order.isEmpty ? '0:00' : _len(Duration(milliseconds: order[cur].durationMs))}/${_len(Duration(milliseconds: total))}',
                    ),
                  ),
                  for (var r = 0; r < _rows && _top + r < order.length; r++)
                    At(
                      12,
                      23 + 13.0 * r,
                      _row(_top + r, order, cur, style, skin, k),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _row(
    int i,
    List<Track> order,
    int? cur,
    TextStyle style,
    Skin skin,
    double k,
  ) {
    final t = order[i];
    final color = skin.playlistColor(i == cur ? 'current' : 'normal');
    final who = t.artist.isEmpty ? '' : '${t.artist} - ';
    return Listener(
      onPointerDown: (e) => _down(i, e, order),
      child: Container(
        width: 243 * k,
        height: 13 * k,
        color: i == _selected ? skin.playlistColor('selectedbg') : null,
        padding: EdgeInsets.symmetric(horizontal: 2 * k),
        alignment: Alignment.centerLeft,
        child: Row(
          children: [
            Expanded(
              child: Text(
                '${i + 1}. $who${t.title}',
                maxLines: 1,
                overflow: TextOverflow.clip,
                softWrap: false,
                style: style.copyWith(color: color),
              ),
            ),
            Text(
              _len(Duration(milliseconds: t.durationMs)),
              style: style.copyWith(color: color),
            ),
          ],
        ),
      ),
    );
  }
}
