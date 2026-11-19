import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lafleurmusic/theme/widgets.dart';

/// Le logo n'est jamais coupé par la recherche : centré si la place le permet,
/// sinon décalé à gauche, puis rétréci.
void main() {
  Future<(Rect, Rect)> layout(
    WidgetTester tester,
    double width,
    double search,
  ) async {
    tester.view.physicalSize = Size(width, 400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              TitleBar(
                trailing: SizedBox(
                  key: const Key('search'),
                  width: search,
                  height: 30,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return (
      tester.getRect(find.byKey(const Key('logo'))),
      tester.getRect(find.byKey(const Key('search'))),
    );
  }

  testWidgets('fenêtre large : logo au milieu de la fenêtre', (tester) async {
    final (logo, _) = await layout(tester, 1400, 260);
    expect(logo.center.dx, closeTo(700, 0.5));
    expect(logo.width, closeTo(400, 0.5));
  });

  for (final (w, search) in [
    (940.0, 260.0),
    (900.0, 260.0),
    (700.0, 180.0),
    (560.0, 180.0),
  ]) {
    testWidgets('fenêtre de $w : logo entier, jamais sous la recherche', (
      tester,
    ) async {
      final (logo, s) = await layout(tester, w, search);
      expect(logo.right, lessThanOrEqualTo(s.left - 12 + 0.5));
      expect(logo.left, greaterThanOrEqualTo(18 - 0.5));
      expect(logo.width, greaterThan(100));
      // toujours les proportions du logo (900 × 45)
      expect(logo.width / logo.height, closeTo(20, 0.1));
    });
  }
}
