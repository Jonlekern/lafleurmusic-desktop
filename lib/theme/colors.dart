import 'dart:ui';

/// Les couleurs d'un mode : nuit (comme la console) ou jour (comme la version iPhone).
final class LafleurPalette {
  const LafleurPalette({
    required this.brightness,
    required this.bg,
    required this.bar,
    required this.panel,
    required this.line,
    required this.text,
    required this.sub,
    required this.outline,
    required this.track,
    required this.eqTrack,
    required this.field,
    required this.search,
    required this.warn,
    required this.menu,
    required this.dialog,
    required this.sheet,
    required this.menuLine,
    required this.sheetLine,
    required this.rowLine,
    required this.well,
    required this.faint,
    required this.fainter,
    required this.faintest,
    required this.soft,
    required this.softer,
    required this.body,
    required this.strong,
    required this.rowText,
    required this.play,
    required this.knobEdge,
    required this.icon,
    required this.shadow,
  });

  final Brightness brightness;
  final Color bg, bar, panel, line, text, sub;
  final Color outline; // contour des boutons pilule et des champs
  final Color track, eqTrack; // fond des curseurs (barre du bas, égaliseur)
  final Color field, search; // champs à remplir, recherche
  final Color warn; // bandeau « morceaux introuvables »
  final Color menu, dialog, sheet; // menu clic droit, fenêtres, fenêtre Réparer
  final Color menuLine, sheetLine, rowLine;
  final Color well; // cadre « avant / après » de Réparer, case sans pochette
  final Color faint, fainter, faintest; // textes discrets
  final Color soft,
      softer,
      body,
      strong; // textes un peu moins forts que `text`
  final Color rowText; // morceaux des listes
  final Color play; // rond Lecture / Pause
  final Color? knobEdge; // contour des boutons ronds des curseurs (blancs)
  final Color icon; // grande icône de dossier de l'accueil
  final Color shadow; // ombre sous les pochettes et les menus

  Color get pink => LafleurColors.pink; // le même rose jour et nuit
  Color get ink => LafleurColors.ink; // texte posé sur le rose

  static const night = LafleurPalette(
    brightness: Brightness.dark,
    bg: Color(0xFF0D0D0D),
    bar: Color(0xFF1C1C1C),
    panel: Color(0xFF141414),
    line: Color(0xFF282828),
    text: Color(0xFFFFFFFF),
    sub: Color(0xFF969696),
    outline: Color(0xFF444444),
    track: Color(0xFF3D3D3D),
    eqTrack: Color(0xFF333333),
    field: Color(0xFF2A2A2A),
    search: Color(0xFF0F0F0F),
    warn: Color(0xFF2A1A2A),
    menu: Color(0xFF232323),
    dialog: Color(0xFF1F1F1F),
    sheet: Color(0xFF181818),
    menuLine: Color(0xFF3A3A3A),
    sheetLine: Color(0xFF333333),
    rowLine: Color(0xFF222222),
    well: Color(0xFF111111),
    faint: Color(0xFF777777),
    fainter: Color(0xFF666666),
    faintest: Color(0xFF555555),
    soft: Color(0xFFBBBBBB),
    softer: Color(0xFFCCCCCC),
    body: Color(0xFFCFCFCF),
    strong: Color(0xFFEEEEEE),
    rowText: Color(0xFFDDDDDD),
    play: Color(0xFFFFFFFF),
    knobEdge: null,
    icon: Color(0xFFB0B0B0),
    shadow: Color(0xFF000000),
  );

  /// Valeurs de la maquette du mode clair de l'iPhone (`lafleurmusic-mobile/maquettes/5-mode-clair.png`).
  static const day = LafleurPalette(
    brightness: Brightness.light,
    bg: Color(0xFFFFFFFF),
    bar: Color(0xFFF3F3F3),
    panel: Color(0xFFF7F7F7),
    line: Color(0xFFE0E0E0),
    text: Color(0xFF111111),
    sub: Color(0xFF6E6E6E),
    outline: Color(0xFFCFCFCF),
    track: Color(0xFFE4E4E4),
    eqTrack: Color(0xFFE4E4E4),
    field: Color(0xFFEFEFEF),
    search: Color(0xFFFFFFFF),
    warn: Color(0xFFFDE6FD),
    menu: Color(0xFFFFFFFF),
    dialog: Color(0xFFFFFFFF),
    sheet: Color(0xFFFFFFFF),
    menuLine: Color(0xFFE2E2E2),
    sheetLine: Color(0xFFE2E2E2),
    rowLine: Color(0xFFEEEEEE),
    well: Color(0xFFFAFAFA),
    faint: Color(0xFF8A8A8A),
    fainter: Color(0xFF9A9A9A),
    faintest: Color(0xFFB8B8B8),
    soft: Color(0xFF444444),
    softer: Color(0xFF333333),
    body: Color(0xFF333333),
    strong: Color(0xFF111111),
    rowText: Color(0xFF111111),
    play: LafleurColors.pink,
    knobEdge: Color(0xFFCFCFCF),
    icon: Color(0xFF8A8A8A),
    shadow: Color(0x29000000),
  );

  static LafleurPalette of(Brightness b) => b == Brightness.light ? day : night;

  /// Le mode affiché : changé par [FollowSystemPalette] quand le Mac passe de clair à sombre.
  static LafleurPalette current = night;
}

/// Couleurs LAFLEURSTUDIO du mode affiché (nuit = les mêmes que sur la console).
abstract final class LafleurColors {
  static Color get bg => LafleurPalette.current.bg;
  static Color get bar => LafleurPalette.current.bar;
  static Color get panel => LafleurPalette.current.panel;
  static Color get line => LafleurPalette.current.line;
  static Color get text => LafleurPalette.current.text;
  static Color get sub => LafleurPalette.current.sub;
  static const pink = Color(0xFFF26EF2);
  static const ink = Color(0xFF1F1F1F);
  static LafleurPalette get p => LafleurPalette.current;
}
