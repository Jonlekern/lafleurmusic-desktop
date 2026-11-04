import 'package:flutter/widgets.dart';

import '../../skins/skin.dart';

/// Le skin et l'échelle (×1 / ×2) du petit Winamp.
class WinampScope extends InheritedWidget {
  const WinampScope({
    super.key,
    required this.skin,
    required this.scale,
    required super.child,
  });
  final Skin skin;
  final double scale;

  static WinampScope of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<WinampScope>()!;

  @override
  bool updateShouldNotify(WinampScope old) =>
      old.skin != skin || old.scale != scale;
}

/// Place un élément à sa position Winamp (en pixels ×1) dans une fenêtre.
class At extends StatelessWidget {
  const At(this.left, this.top, this.child, {super.key});
  final double left, top;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final k = WinampScope.of(context).scale;
    return Positioned(left: left * k, top: top * k, child: child);
  }
}
