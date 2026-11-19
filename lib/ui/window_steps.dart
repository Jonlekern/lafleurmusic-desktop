import 'dart:ui' show Size;

/// Les trois tailles de la fenêtre : grande, moyenne (sans « En cours »), mini-lecteur.
enum WindowStep { large, medium, mini }

const kMediumBelow = 880.0; // moins large : la colonne « En cours » part
const kMiniBelow = 300.0; // moins haute : mini-lecteur
const kLeaveMiniAbove =
    200.0; // en mini, tirée plus haut : on reprend la taille d'avant
const kMiniHeight = 130.0; // hauteur où le mini-lecteur se cale
const kMinWindow = Size(150, kMiniHeight); // le rond rose tout seul
const kMinPage = Size(
  560,
  kMiniHeight,
); // hors mini-lecteur : la page tient encore
const kDefaultWindow = Size(920, 690);
const kMiniCoverFrom =
    640.0; // mini-lecteur au moins aussi large : la pochette à gauche

WindowStep stepFor(Size s) {
  if (s.height < kMiniBelow) return WindowStep.mini;
  if (s.width < kMediumBelow) return WindowStep.medium;
  return WindowStep.large;
}

/// L'aimant du mini-lecteur. Appelé quand on lâche le bord de la fenêtre (jamais pendant qu'on tire) :
/// rend la taille à imposer, ou null pour laisser la fenêtre comme elle est.
class MiniSnap {
  MiniSnap({this.restore}) : _mini = restore != null;

  /// La taille d'avant le mini-lecteur, reprise en le quittant.
  Size? restore;
  bool _mini;
  Size? _last; // dernière taille hors mini-lecteur

  bool get mini => _mini;

  Size? settled(Size s, {bool fullScreen = false}) {
    if (fullScreen) return null;
    if (!_mini) {
      if (s.height >= kMiniBelow) {
        _last = s;
        return null;
      }
      _mini = true;
      restore = _last ?? kDefaultWindow;
      return s.height == kMiniHeight ? null : Size(s.width, kMiniHeight);
    }
    if (s.height > kLeaveMiniAbove) {
      final back = restore ?? kDefaultWindow;
      _mini = false;
      restore = null;
      _last = back;
      return back;
    }
    return s.height == kMiniHeight ? null : Size(s.width, kMiniHeight);
  }
}

/// Mini-lecteur plus étroit que ça : juste le rond rose.
const kMiniButtonBelow = 300.0;
