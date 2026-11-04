import 'package:flutter/widgets.dart';
import 'package:window_manager/window_manager.dart';

/// La fenêtre de l'ordi : grande fenêtre LAFLEUR, ou petit Winamp sans barre de titre.
abstract interface class WindowMode {
  /// Passe en Winamp à cette taille ; rend la taille d'avant (pour y revenir).
  Future<Size> enterWinamp(Size size);
  Future<void> resize(Size size);
  Future<void> leaveWinamp(Size? previous);
  Future<void> startDrag();
}

class DesktopWindow implements WindowMode {
  static const lafleurDefault = Size(920, 690);

  @override
  Future<Size> enterWinamp(Size size) async {
    final old = await windowManager.getSize();
    await windowManager.setTitleBarStyle(
      TitleBarStyle.hidden,
      windowButtonVisibility: false,
    );
    await windowManager.setMinimumSize(Size.zero);
    await windowManager.setResizable(false);
    await windowManager.setSize(size);
    return old;
  }

  @override
  Future<void> resize(Size size) => windowManager.setSize(size);

  @override
  Future<void> leaveWinamp(Size? previous) async {
    await windowManager.setTitleBarStyle(TitleBarStyle.normal);
    await windowManager.setResizable(true);
    await windowManager.setSize(previous ?? lafleurDefault);
  }

  @override
  Future<void> startDrag() => windowManager.startDragging();
}
