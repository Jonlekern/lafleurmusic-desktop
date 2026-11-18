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
  DesktopWindow({WindowManager? wm}) : _wm = wm ?? windowManager;
  static const lafleurDefault = Size(920, 690);

  final WindowManager _wm;
  // la grande fenêtre était en plein écran / agrandie : on y revient en quittant le Winamp
  bool _wasFullScreen = false, _wasMaximized = false;

  @override
  Future<Size> enterWinamp(Size size) async {
    // en plein écran (ou agrandie), macOS ignore la nouvelle taille : le skin flotterait dans une grande page
    _wasFullScreen = await _wm.isFullScreen();
    if (_wasFullScreen) {
      await _wm.setFullScreen(false);
      // la sortie du plein écran est animée : on attend qu'elle soit finie
      for (var i = 0; i < 30 && await _wm.isFullScreen(); i++) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
    }
    _wasMaximized = await _wm.isMaximized();
    if (_wasMaximized) await _wm.unmaximize();
    final old = await _wm.getSize();
    await _wm.setTitleBarStyle(
      TitleBarStyle.hidden,
      windowButtonVisibility: false,
    );
    await _wm.setMinimumSize(Size.zero);
    await _wm.setResizable(false);
    await _wm.setSize(size);
    return old;
  }

  @override
  Future<void> resize(Size size) => _wm.setSize(size);

  @override
  Future<void> leaveWinamp(Size? previous) async {
    await _wm.setTitleBarStyle(TitleBarStyle.normal);
    await _wm.setResizable(true);
    await _wm.setSize(previous ?? lafleurDefault);
    if (_wasMaximized) await _wm.maximize();
    if (_wasFullScreen) await _wm.setFullScreen(true);
    _wasFullScreen = _wasMaximized = false;
  }

  @override
  Future<void> startDrag() => _wm.startDragging();
}
