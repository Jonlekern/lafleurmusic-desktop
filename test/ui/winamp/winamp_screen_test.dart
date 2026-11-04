import 'dart:io';

import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lafleurmusic/app_scope.dart';
import 'package:lafleurmusic/l10n/strings.dart';
import 'package:lafleurmusic/library/covers.dart';
import 'package:lafleurmusic/library/db.dart';
import 'package:lafleurmusic/settings.dart';
import 'package:lafleurmusic/skins/skin.dart';
import 'package:lafleurmusic/skins/skins_folder.dart';
import 'package:lafleurmusic/theme/lafleur_theme.dart';
import 'package:lafleurmusic/ui/player_bar.dart';
import 'package:lafleurmusic/ui/window_mode.dart';
import 'package:lafleurmusic/ui/winamp/winamp_screen.dart';

import '../fake_player.dart';

class FakeWindow implements WindowMode {
  final calls = <String>[];
  @override
  Future<Size> enterWinamp(Size s) async {
    calls.add('enter ${s.width.toInt()}x${s.height.toInt()}');
    return const Size(920, 690);
  }

  @override
  Future<void> resize(Size s) async =>
      calls.add('resize ${s.width.toInt()}x${s.height.toInt()}');
  @override
  Future<void> leaveWinamp(Size? s) async =>
      calls.add('leave ${s?.width.toInt()}x${s?.height.toInt()}');
  @override
  Future<void> startDrag() async => calls.add('drag');
}

class Env {
  Env(this.player, this.window, this.settings, this.folder, this.files);
  final FakePlayer player;
  final FakeWindow window;
  final AppSettings settings;
  final SkinsFolder folder;
  final ValueNotifier<List<File>> files;
}

Future<void> settle(WidgetTester tester, [int n = 8]) async {
  for (var i = 0; i < n; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 40)),
    );
    await tester.pump(
      const Duration(milliseconds: 60),
    ); // laisse finir les animations (menu)
  }
}

Future<Env> pump(
  WidgetTester tester, {
  List<String> skins = const ['A.wsz', 'B.wsz'],
  List<int>? broken,
  Set<String> brokenNames = const {'B.wsz'},
  AppSettings? settings,
}) async {
  tester.view.physicalSize = const Size(1440, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final db = LibraryDb(
    DatabaseConnection(
      NativeDatabase.memory(),
      closeStreamsSynchronously: true,
    ),
  );
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(db.close);
  });
  final dir = Directory.systemTemp.createTempSync('ws');
  final folder = SkinsFolder(Directory('${dir.path}/Skins'));
  await tester.runAsync(() async {
    await folder.ensure();
    for (final n in skins) {
      final f = File('${folder.dir.path}/$n');
      if (broken != null && brokenNames.contains(n)) {
        f.writeAsBytesSync(broken);
      } else {
        File('test/fixtures/skins/lafleur-test.wsz').copySync(f.path);
      }
    }
  });
  final files = ValueNotifier<List<File>>(
    (await tester.runAsync(folder.list))!,
  );
  // skins lus d'avance, hors de l'horloge simulée (le cache de Skin.load les resservira)
  await tester.runAsync(() async {
    for (final f in files.value) {
      await Skin.load(f);
    }
  });
  final env = Env(
    FakePlayer(),
    FakeWindow(),
    settings ?? AppSettings(),
    folder,
    files,
  );
  await tester.pumpWidget(
    AppScope(
      db: db,
      player: env.player,
      covers: Covers(
        cacheDir: Directory.systemTemp.createTempSync('wc'),
        embedded: (_) async => null,
      ),
      strings: Strings.of(const Locale('fr')),
      skins: folder,
      skinFiles: files,
      window: env.window,
      settings: env.settings,
      saveSettings: () {},
      child: MaterialApp(
        theme: lafleurTheme(),
        home: const Scaffold(
          body: Align(alignment: Alignment.bottomCenter, child: PlayerBar()),
        ),
      ),
    ),
  );
  await tester.pump();
  return env;
}

Future<void> openIt(WidgetTester tester) async {
  await tester.tap(find.text('Skins'));
  await settle(tester);
}

void main() {
  testWidgets('bouton Skins : absent si le dossier est vide', (tester) async {
    await pump(tester, skins: const []);
    expect(find.text('Skins'), findsNothing);
  });

  testWidgets(
    'clic sur Skins : le petit Winamp, fenêtre en 550 × 696, réglage retenu',
    (tester) async {
      final e = await pump(tester);
      await openIt(tester);
      expect(find.byType(WinampScreen), findsOneWidget);
      expect(e.window.calls, ['enter 550x696']);
      expect(e.settings.winampMode, isTrue);
      expect(e.settings.lafleurSize, const Size(920, 690));
      expect(e.settings.skin, 'A.wsz');
    },
  );

  testWidgets('Cmd + D : taille d’origine 275 × 348, retenue', (tester) async {
    final e = await pump(tester);
    await openIt(tester);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyD);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    await tester.pump();
    expect(e.window.calls.last, 'resize 275x348');
    expect(e.settings.winampDouble, isFalse);
  });

  testWidgets('EQ : cache la fenêtre égaliseur, la fenêtre rapetisse', (
    tester,
  ) async {
    final e = await pump(tester);
    await openIt(tester);
    await tester.tap(find.byKey(const Key('wa-eqbutton')));
    await tester.pump();
    expect(e.window.calls.last, 'resize 550x464');
    expect(e.settings.winampEq, isFalse);
  });

  testWidgets(
    'clic droit : menu avec tous les skins ; choisir B l’applique et le retient',
    (tester) async {
      final e = await pump(tester);
      await openIt(tester);
      await tester.tapAt(
        tester.getCenter(find.byType(WinampScreen)),
        buttons: kSecondaryButton,
        kind: PointerDeviceKind.mouse,
      );
      await settle(tester);
      expect(find.text('A'), findsOneWidget);
      expect(find.text('B'), findsOneWidget);
      await tester.tap(find.text('B'));
      await settle(tester);
      expect(e.settings.skin, 'B.wsz');
    },
  );

  testWidgets('X : retour à LAFLEUR, taille d’avant, la musique continue', (
    tester,
  ) async {
    final e = await pump(tester);
    await openIt(tester);
    await tester.tap(find.byKey(const Key('wa-close')));
    await settle(tester);
    expect(find.byType(WinampScreen), findsNothing);
    expect(e.window.calls.last, 'leave 920x690');
    expect(e.settings.winampMode, isFalse);
    expect(e.player.calls.where((c) => c == 'toggle'), isEmpty);
  });

  testWidgets('skin illisible : absent du menu', (tester) async {
    await pump(tester, broken: [1, 2, 3]);
    await openIt(tester);
    await tester.tapAt(
      tester.getCenter(find.byType(WinampScreen)),
      buttons: kSecondaryButton,
      kind: PointerDeviceKind.mouse,
    );
    await settle(tester);
    expect(find.text('A'), findsOneWidget);
    expect(find.text('B'), findsNothing);
  });

  testWidgets('premier skin illisible : on prend le suivant qui se lit', (
    tester,
  ) async {
    final e = await pump(tester, broken: [1, 2, 3], brokenNames: {'A.wsz'});
    await openIt(tester);
    expect(find.byType(WinampScreen), findsOneWidget);
    expect(e.settings.skin, 'B.wsz');
  });

  testWidgets('aucun skin lisible : message « Skin illisible »', (
    tester,
  ) async {
    await pump(tester, broken: [1, 2, 3], brokenNames: {'A.wsz', 'B.wsz'});
    await openIt(tester);
    expect(find.byType(WinampScreen), findsNothing);
    expect(find.text('Skin illisible : A'), findsOneWidget);
  });

  testWidgets(
    'relancée en mode Winamp : la taille de la grande fenêtre n’est pas écrasée',
    (tester) async {
      final st = AppSettings()
        ..winampMode = true
        ..lafleurSize = const Size(1200, 800);
      final e = await pump(tester, settings: st);
      await openIt(tester);
      expect(e.settings.lafleurSize, const Size(1200, 800));
    },
  );

  testWidgets('double-clic sur Skins : un seul Winamp', (tester) async {
    final e = await pump(tester);
    await tester.tap(find.text('Skins'));
    await tester.tap(find.text('Skins'));
    await settle(tester);
    expect(e.window.calls.where((c) => c.startsWith('enter')).length, 1);
    expect(find.byType(WinampScreen), findsOneWidget);
  });

  testWidgets(
    'dossier vidé pendant le Winamp : on reste affiché ; au retour, plus de bouton',
    (tester) async {
      final e = await pump(tester);
      await openIt(tester);
      await tester.runAsync(() async {
        for (final f in e.folder.dir.listSync()) {
          f.deleteSync();
        }
      });
      await tester.pump();
      expect(find.byType(WinampScreen), findsOneWidget);
      await tester.tap(find.byKey(const Key('wa-close')));
      await settle(tester);
      expect(find.text('Skins'), findsNothing);
    },
  );

  testWidgets(
    '.wsz glissé sur la fenêtre : copié dans le dossier, bouton visible',
    (tester) async {
      final e = await pump(tester, skins: const []);
      final ctx = tester.element(find.byType(PlayerBar));
      final src = File(
        '${Directory.systemTemp.createTempSync('dr').path}/Trinity.wsz',
      );
      await tester.runAsync(() async {
        File('test/fixtures/skins/lafleur-test.wsz').copySync(src.path);
        await addDroppedSkins(ctx, [src.path, '/tmp/photo.jpg']);
      });
      await tester.pump();
      expect(e.files.value.map((f) => f.uri.pathSegments.last), [
        'Trinity.wsz',
      ]);
      expect(find.text('Skins'), findsOneWidget);
    },
  );
}
