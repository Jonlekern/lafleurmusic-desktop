import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lafleurmusic/l10n/strings.dart';
import 'package:lafleurmusic/theme/lafleur_theme.dart';
import 'package:lafleurmusic/ui/welcome_screen.dart';

import 'fonts.dart';

void main() {
  setUpAll(loadFonts);

  testWidgets('premier lancement comme la maquette 1', (tester) async {
    desktopSize(tester);
    await tester.pumpWidget(
      MaterialApp(
        theme: lafleurTheme(),
        home: WelcomeScreen(
          strings: Strings.of(const Locale('fr')),
          onFolder: (_) {},
        ),
      ),
    );
    await precacheAssets(tester, [
      'assets/fleur.png',
      'assets/logo-texte-grand.png',
    ]);
    await expectLater(
      find.byType(WelcomeScreen),
      matchesGoldenFile('goldens/1-premier-lancement.png'),
    );
  });

  testWidgets('« Utiliser mon dossier Musique » envoie le dossier Musique', (
    tester,
  ) async {
    desktopSize(tester);
    String? chosen;
    await tester.pumpWidget(
      MaterialApp(
        theme: lafleurTheme(),
        home: WelcomeScreen(
          strings: Strings.of(const Locale('fr')),
          onFolder: (p) => chosen = p,
          home: '/Users/test',
        ),
      ),
    );
    await tester.tap(find.text('Utiliser mon dossier Musique'));
    expect(chosen, '/Users/test/Music');
  });

  testWidgets('pendant le scan : progression affichée', (tester) async {
    desktopSize(tester);
    await tester.pumpWidget(
      MaterialApp(
        theme: lafleurTheme(),
        home: WelcomeScreen(
          strings: Strings.of(const Locale('fr')),
          onFolder: (_) {},
          progress: (120, 450),
        ),
      ),
    );
    expect(find.text('Je range ta musique… 120 / 450'), findsOneWidget);
  });

  testWidgets(
    'petite fenêtre : rien ne déborde, on peut faire défiler jusqu’en bas',
    (tester) async {
      tester.view.physicalSize = const Size(900, 560);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: lafleurTheme(),
          home: WelcomeScreen(
            strings: Strings.of(const Locale('fr')),
            onFolder: (_) {},
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      final hint = find.textContaining('Un NAS ?');
      await tester.scrollUntilVisible(
        hint,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(tester.getBottomLeft(hint).dy, lessThanOrEqualTo(560));
    },
  );

  testWidgets(
    'dossier sans musique : message, et on peut en choisir un autre',
    (tester) async {
      desktopSize(tester);
      String? chosen;
      await tester.pumpWidget(
        MaterialApp(
          theme: lafleurTheme(),
          home: WelcomeScreen(
            strings: Strings.of(const Locale('fr')),
            onFolder: (p) => chosen = p,
            home: '/Users/test',
            emptyFolder: '/Users/test/Music',
          ),
        ),
      );
      expect(find.textContaining('Aucune musique trouvée'), findsOneWidget);
      await tester.tap(find.text('Utiliser mon dossier Musique'));
      expect(chosen, '/Users/test/Music');
    },
  );
}
