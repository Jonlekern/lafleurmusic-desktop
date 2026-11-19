import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lafleurmusic/ui/window_mode.dart';
import 'package:lafleurmusic/ui/window_steps.dart';
import 'package:window_manager/window_manager.dart';

/// Fenêtre macOS simulée : plein écran / agrandie comme le Mac de Johnny (1920×1080).
class FakeWm implements WindowManager {
  FakeWm({
    this.full = false,
    this.max = false,
    this.size = const Size(920, 690),
  });
  bool full, max;
  Size size;
  final calls = <String>[];

  @override
  Future<bool> isFullScreen() async => full;
  @override
  Future<void> setFullScreen(bool v) async {
    calls.add('fullscreen $v');
    full = v;
    if (!v) size = const Size(920, 690); // macOS rend la taille fenêtrée
  }

  @override
  Future<bool> isMaximized() async => max;
  @override
  Future<void> maximize({bool vertically = false}) async {
    calls.add('maximize');
    max = true;
  }

  @override
  Future<void> unmaximize() async {
    calls.add('unmaximize');
    max = false;
  }

  @override
  Future<Size> getSize() async => size;
  @override
  Future<void> setSize(Size s, {bool animate = false}) async {
    // en plein écran, macOS ignore la nouvelle taille
    calls.add(
      'size ${s.width.round()}x${s.height.round()}${full ? ' (ignorée)' : ''}',
    );
    if (!full) size = s;
  }

  Size? minimum;
  @override
  Future<void> setMinimumSize(Size s) async {
    calls.add('min ${s.width.round()}x${s.height.round()}');
    minimum = s;
  }

  @override
  dynamic noSuchMethod(Invocation i) => Future<void>.value();
}

void main() {
  const winamp = Size(550, 696);

  test('plein écran : on en sort avant de rétrécir, la fenêtre fait la taille du skin', () async {
    final wm = FakeWm(full: true, size: const Size(1920, 1080));
    final w = DesktopWindow(wm: wm);
    final previous = await w.enterWinamp(winamp);
    expect(wm.size, winamp);
    expect(
      wm.calls.indexOf('fullscreen false'),
      lessThan(wm.calls.indexOf('size 550x696')),
    );
    expect(previous, const Size(920, 690));
  });

  test(
    'plein écran : en quittant le skin, on retrouve le plein écran',
    () async {
      final wm = FakeWm(full: true, size: const Size(1920, 1080));
      final w = DesktopWindow(wm: wm);
      final previous = await w.enterWinamp(winamp);
      await w.leaveWinamp(previous);
      expect(wm.full, true);
      expect(wm.calls.last, 'fullscreen true');
    },
  );

  test(
    'fenêtre agrandie : on la réduit avant, on la ré-agrandit après',
    () async {
      final wm = FakeWm(max: true);
      final w = DesktopWindow(wm: wm);
      final previous = await w.enterWinamp(winamp);
      expect(
        wm.calls.indexOf('unmaximize'),
        lessThan(wm.calls.indexOf('size 550x696')),
      );
      await w.leaveWinamp(previous);
      expect(wm.calls.last, 'maximize');
    },
  );

  test('fenêtre normale : ni plein écran ni agrandissement touchés', () async {
    final wm = FakeWm();
    final w = DesktopWindow(wm: wm);
    final previous = await w.enterWinamp(winamp);
    await w.leaveWinamp(previous);
    expect(
      wm.calls.where((c) => c.contains('full') || c.contains('max')),
      isEmpty,
    );
    expect(wm.size, const Size(920, 690));
  });

  test(
    'sortie du skin Winamp : la taille minimale de la page revient',
    () async {
      final wm = FakeWm();
      final w = DesktopWindow(wm: wm);
      final previous = await w.enterWinamp(winamp);
      await w.leaveWinamp(previous);
      expect(wm.minimum, kMinPage);
    },
  );

  test('au démarrage : la fenêtre ne descend pas sous la page', () async {
    final wm = FakeWm();
    await DesktopWindow(wm: wm).setup();
    expect(wm.minimum, kMinPage);
  });

  group('aimant du mini-lecteur', () {
    late FakeWm wm;
    late List<Size?> saved;
    var paused = false;
    SnapController make({Size? restore}) {
      saved = [];
      return SnapController(
        wm,
        restore: restore,
        paused: () => paused,
        onRestore: saved.add,
      );
    }

    setUp(() {
      wm = FakeWm(size: const Size(920, 690));
      paused = false;
    });

    test('lâchée sous 300 : calée à 130, minimum 440 × 130, taille d\'avant gardée', () async {
      final c = make();
      await c.start();
      wm.size = const Size(900, 250);
      await c.resized();
      expect(wm.size, const Size(900, 130));
      expect(wm.minimum, kMinWindow);
      expect(saved.last, const Size(920, 690));
    });

    test('tirée au-delà de 200 : taille d\'avant, minimum de la page, plus rien de gardé', () async {
      final c = make();
      await c.start();
      wm.size = const Size(900, 250);
      await c.resized();
      wm.size = const Size(900, 260);
      await c.resized();
      expect(wm.size, const Size(920, 690));
      expect(wm.minimum, kMinPage);
      expect(saved.last, isNull);
    });

    test('pendant le skin Winamp : rien ne bouge', () async {
      final c = make();
      await c.start();
      paused = true;
      wm.size = const Size(275, 116);
      await c.resized();
      expect(wm.size, const Size(275, 116));
    });

    test('plein écran : rien ne bouge', () async {
      final c = make();
      await c.start();
      wm.full = true;
      wm.size = const Size(1920, 250);
      await c.resized();
      expect(wm.calls.where((x) => x.startsWith('size')), isEmpty);
    });

    test('quittée en mini-lecteur : rouverte en mini-lecteur', () async {
      final c = make(restore: const Size(1000, 700));
      await c.start();
      expect(wm.size, const Size(480, 130));
      expect(wm.minimum, kMinWindow);
      wm.size = const Size(480, 240);
      await c.resized();
      expect(wm.size, const Size(1000, 700));
    });
  });
}
