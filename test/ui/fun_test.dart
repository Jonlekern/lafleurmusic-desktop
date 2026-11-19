import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lafleurmusic/ui/fun.dart';

List<double> bars(double bass) => [bass, bass, bass, 0.1, 0.1, 0.1];

void main() {
  group('le rond qui bat', () {
    test('basses régulières : il ne bat pas', () {
      final b = BeatPulse();
      var p = 0.0;
      for (var i = 0; i < 60; i++) {
        p = b.feed(bars(0.3), 0.03);
      }
      expect(p, 0);
    });

    test('un coup de basse : il bat, puis revient', () {
      final b = BeatPulse();
      for (var i = 0; i < 30; i++) {
        b.feed(bars(0.3), 0.03);
      }
      expect(b.feed(bars(0.8), 0.03), 1);
      var p = 1.0;
      for (var i = 0; i < 10; i++) {
        p = b.feed(bars(0.3), 0.03);
      }
      expect(p, 0);
    });

    test('volume bas (basses faibles) : il bat quand même', () {
      final b = BeatPulse();
      for (var i = 0; i < 30; i++) {
        b.feed(bars(0.05), 0.03);
      }
      expect(b.feed(bars(0.09), 0.03), 1);
    });

    test('coup modéré (20 % au-dessus de la moyenne) : il bat', () {
      final b = BeatPulse();
      for (var i = 0; i < 30; i++) {
        b.feed(bars(0.3), 0.03);
      }
      expect(b.feed(bars(0.36), 0.03), 1);
    });

    test('volume fort (basses presque au maximum) : il bat quand même', () {
      final b = BeatPulse();
      for (var i = 0; i < 30; i++) {
        b.feed(bars(0.9), 0.03);
      }
      expect(b.feed(bars(0.97), 0.03), 1);
    });

    test('volume fort, basses qui tremblent un peu : il ne bat pas', () {
      final b = BeatPulse();
      var p = 0.0;
      for (var i = 0; i < 60; i++) {
        p = b.feed(bars(i.isEven ? 0.9 : 0.92), 0.03);
      }
      expect(p, 0);
    });

    test('basses qui tremblent un peu (±5 %) : il ne bat pas', () {
      final b = BeatPulse();
      var p = 0.0;
      for (var i = 0; i < 60; i++) {
        p = b.feed(bars(i.isEven ? 0.3 : 0.315), 0.03);
      }
      expect(p, 0);
    });

    test('silence : il ne bat pas', () {
      final b = BeatPulse();
      for (var i = 0; i < 30; i++) {
        expect(b.feed(bars(0), 0.03), 0);
      }
    });
  });

  group('le mot secret', () {
    test('« lafleur » tapé : déclenché une fois', () {
      final w = SecretWord('lafleur');
      final hits = [for (final c in 'xxlafleur'.split('')) w.feed(c)];
      expect(hits.where((h) => h).length, 1);
      expect(hits.last, true);
    });

    test('majuscules acceptées, faute de frappe : rien', () {
      final w = SecretWord('lafleur');
      expect([for (final c in 'LaFleur'.split('')) w.feed(c)].last, true);
      expect([for (final c in 'lafleuur'.split('')) w.feed(c)].last, false);
    });
  });

  group('secouer pour changer', () {
    Duration ms(int v) => Duration(milliseconds: v);

    test('simple déplacement : rien', () {
      final s = ShakeDetector();
      var hit = false;
      for (var i = 0; i <= 30; i++) {
        hit |= s.feed(i * 10.0, ms(i * 16));
      }
      expect(hit, false);
    });

    test('trois allers-retours rapides : morceau suivant, une seule fois', () {
      final s = ShakeDetector();
      final xs = [0.0, 40, 0, 40, 0, 40, 0, 40, 0, 40, 0];
      final hits = [
        for (var i = 0; i < xs.length; i++)
          s.feed(xs[i].toDouble(), ms(i * 80)),
      ];
      expect(hits.where((h) => h).length, 1);
    });

    test('allers-retours lents : rien', () {
      final s = ShakeDetector();
      final xs = [0.0, 40, 0, 40, 0, 40, 0];
      var hit = false;
      for (var i = 0; i < xs.length; i++) {
        hit |= s.feed(xs[i].toDouble(), ms(i * 600));
      }
      expect(hit, false);
    });

    test('petits tremblements de la main : rien', () {
      final s = ShakeDetector();
      var hit = false;
      for (var i = 0; i < 20; i++) {
        hit |= s.feed(i.isEven ? 0 : 6, ms(i * 50));
      }
      expect(hit, false);
    });
  });

  group('la pluie de fleurs', () {
    Future<void> pump(WidgetTester tester, Widget page) => tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => SecretRain(child: child!),
        home: Scaffold(body: page),
      ),
    );

    Future<void> type(WidgetTester tester, String s) async {
      for (final c in s.split('')) {
        await tester.sendKeyEvent(
          LogicalKeyboardKey(c.codeUnitAt(0)),
          character: c,
        );
      }
    }

    testWidgets('« lafleur » tapé : des fleurs tombent, puis disparaissent', (
      tester,
    ) async {
      await pump(tester, const Text('page'));
      await type(tester, 'lafleur');
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byKey(const Key('fleur')), findsNWidgets(22));
      await tester.pump(const Duration(seconds: 2));
      await tester.pump(const Duration(seconds: 2));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump();
      expect(find.byKey(const Key('fleur')), findsNothing);
    });

    testWidgets('dans un champ de texte : pas de pluie', (tester) async {
      await pump(tester, const TextField(autofocus: true));
      await tester.pump();
      await type(tester, 'lafleur');
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byKey(const Key('fleur')), findsNothing);
    });
  });
}
