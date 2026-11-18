import 'package:flutter/material.dart';

import 'colors.dart';

ThemeData lafleurTheme([LafleurPalette p = LafleurPalette.night]) {
  final base = ThemeData(
    brightness: p.brightness,
    fontFamily: 'Inter',
    useMaterial3: true,
  );
  return base.copyWith(
    scaffoldBackgroundColor: p.bg,
    colorScheme: base.colorScheme.copyWith(
      primary: p.pink,
      onPrimary: p.ink,
      surface: p.panel,
      onSurface: p.text,
      outline: p.line,
    ),
    dividerColor: p.line,
    textSelectionTheme: TextSelectionThemeData(cursorColor: p.pink),
  );
}

/// Suit le réglage clair / sombre du Mac : jour = fond blanc, nuit = fond noir (comme l'iPhone).
/// Au changement, toute l'appli se redessine sans rien perdre (écran, file, défilement).
class FollowSystemPalette extends StatefulWidget {
  const FollowSystemPalette({super.key, required this.builder});
  final WidgetBuilder builder;

  @override
  State<FollowSystemPalette> createState() => _FollowSystemPaletteState();
}

class _FollowSystemPaletteState extends State<FollowSystemPalette>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _apply();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  bool _apply() {
    final p = LafleurPalette.of(
      WidgetsBinding.instance.platformDispatcher.platformBrightness,
    );
    if (identical(p, LafleurPalette.current)) return false;
    LafleurPalette.current = p;
    return true;
  }

  @override
  void didChangePlatformBrightness() {
    if (!_apply() || !mounted) return;
    setState(() {});
    // les écrans lisent LafleurColors directement : on les redessine tous
    void rebuild(Element e) {
      e.markNeedsBuild();
      e.visitChildren(rebuild);
    }

    (context as Element).visitChildren(rebuild);
  }

  @override
  Widget build(BuildContext context) => widget.builder(context);
}
