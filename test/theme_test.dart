import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lafleurmusic/theme/colors.dart';
import 'package:lafleurmusic/theme/lafleur_theme.dart';

void main() {
  tearDown(() => LafleurPalette.current = LafleurPalette.night);

  test('couleurs LAFLEURSTUDIO (nuit, comme la console)', () {
    expect(LafleurColors.pink, const Color(0xFFF26EF2));
    expect(LafleurColors.bg, const Color(0xFF0D0D0D));
    expect(LafleurColors.bar, const Color(0xFF1C1C1C));
  });

  test('jour : fond blanc, texte noir, rose identique (maquette iPhone)', () {
    const d = LafleurPalette.day;
    expect(d.bg, const Color(0xFFFFFFFF));
    expect(d.bar, const Color(0xFFF3F3F3));
    expect(d.text, const Color(0xFF111111));
    expect(d.sub, const Color(0xFF6E6E6E));
    expect(d.line, const Color(0xFFE0E0E0));
    expect(d.pink, LafleurPalette.night.pink);
    expect(d.ink, LafleurPalette.night.ink); // texte posé sur le rose
  });

  test('LafleurColors suit la palette du moment', () {
    LafleurPalette.current = LafleurPalette.day;
    expect(LafleurColors.bg, const Color(0xFFFFFFFF));
    LafleurPalette.current = LafleurPalette.night;
    expect(LafleurColors.bg, const Color(0xFF0D0D0D));
  });

  test('palette choisie selon le réglage du Mac', () {
    expect(LafleurPalette.of(Brightness.light), LafleurPalette.day);
    expect(LafleurPalette.of(Brightness.dark), LafleurPalette.night);
  });

  test('thème sombre en Inter', () {
    final t = lafleurTheme();
    expect(t.brightness, Brightness.dark);
    expect(t.scaffoldBackgroundColor, LafleurColors.bg);
    expect(t.textTheme.bodyMedium?.fontFamily, 'Inter');
  });

  test('thème clair en Inter', () {
    final t = lafleurTheme(LafleurPalette.day);
    expect(t.brightness, Brightness.light);
    expect(t.scaffoldBackgroundColor, const Color(0xFFFFFFFF));
    expect(t.colorScheme.onSurface, const Color(0xFF111111));
    expect(t.textTheme.bodyMedium?.fontFamily, 'Inter');
  });

  testWidgets('le Mac passe en clair : toute l\'appli se redessine en jour', (
    tester,
  ) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    await tester.pumpWidget(
      FollowSystemPalette(
        builder: (context) => MaterialApp(
          theme: lafleurTheme(LafleurPalette.current),
          home: const _Swatch(),
        ),
      ),
    );
    expect(_color(tester), LafleurPalette.night.bg);

    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    await tester.pumpAndSettle();
    expect(LafleurPalette.current, LafleurPalette.day);
    expect(_color(tester), LafleurPalette.day.bg);
  });
}

Color? _color(WidgetTester t) =>
    t.widget<ColoredBox>(find.byKey(const ValueKey('swatch'))).color;

/// Lit la couleur directement (pas par le thème) : comme la plupart des écrans de l'appli.
class _Swatch extends StatelessWidget {
  const _Swatch();
  @override
  Widget build(BuildContext context) =>
      ColoredBox(key: const ValueKey('swatch'), color: LafleurColors.bg);
}
