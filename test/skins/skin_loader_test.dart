import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/painting.dart';
import 'package:lafleurmusic/skins/skin.dart';
import 'package:lafleurmusic/skins/skin_loader.dart';

final testSkin = File('test/fixtures/skins/lafleur-test.wsz');

/// Le skin d'essai, repaqueté : fichiers renommés / déplacés / retirés.
Uint8List repack({
  String prefix = '',
  bool upper = false,
  Set<String> drop = const {},
  Map<String, List<int>> add = const {},
}) {
  final src = ZipDecoder().decodeBytes(testSkin.readAsBytesSync());
  final out = Archive();
  for (final f in src.files) {
    if (!f.isFile || drop.contains(f.name.toLowerCase())) continue;
    final name = upper ? f.name.toUpperCase() : f.name;
    out.addFile(ArchiveFile('$prefix$name', f.size, f.content));
  }
  add.forEach((n, b) => out.addFile(ArchiveFile(n, b.length, b)));
  return Uint8List.fromList(ZipEncoder().encode(out));
}

void main() {
  skinImages();
  test('skin d’essai : sprites à la bonne taille, couleurs de la playlist', () {
    final s = parseSkin(testSkin.readAsBytesSync(), 'lafleur-test')!;
    expect(s.sprites['MAIN_PLAY_BUTTON']!.w, 23);
    expect(s.sprites['MAIN_PLAY_BUTTON']!.h, 18);
    expect(s.sprites['MAIN_PLAY_BUTTON']!.rgba.length, 23 * 18 * 4);
    expect(s.playlistColors['current'], 0xFFF26EF2);
    expect(s.visColors.length, 24);
  });

  test('fichiers dans un sous-dossier, noms en majuscules : chargé pareil', () {
    final s = parseSkin(repack(prefix: 'Jackie Chan Amp/', upper: true), 'x');
    expect(s, isNotNull);
    expect(s!.sprites['MAIN_WINDOW_BACKGROUND']!.w, 275);
    expect(s.missing, isEmpty);
  });

  test(
    'numbers.bmp absent, nums_ex.bmp présent : chiffres pris dans nums_ex',
    () {
      final s = parseSkin(repack(drop: {'numbers.bmp'}), 'x')!;
      expect(s.missing, isNot(contains('DIGIT_3')));
    },
  );

  test('image absente : sprite de secours, noté comme manquant', () {
    final s = parseSkin(repack(drop: {'shufrep.bmp'}), 'x')!;
    expect(s.sprites['MAIN_SHUFFLE_BUTTON']!.w, 47);
    expect(s.missing, contains('MAIN_SHUFFLE_BUTTON'));
  });

  test('viscolor.txt sans fins de ligne : 24 couleurs', () {
    // fins de ligne à l'ancienne (\r seul) et commentaires collés
    final vis = List.generate(
      24,
      (i) => '$i,${i * 2},${i * 3} // c$i',
    ).join('\r');
    final s = parseSkin(
      repack(drop: {'viscolor.txt'}, add: {'viscolor.txt': vis.codeUnits}),
      'x',
    )!;
    expect(s.visColors.length, 24);
    expect(s.visColors[1], 0xFF010203);
  });

  test('pas un zip, ou zip sans main.bmp : null', () {
    expect(parseSkin(Uint8List.fromList(List.filled(100, 7)), 'x'), isNull);
    expect(parseSkin(repack(drop: {'main.bmp'}), 'x'), isNull);
  });

  test('BMP abîmé : sprite de secours, pas de plantage', () {
    final s = parseSkin(
      repack(
        drop: {'cbuttons.bmp'},
        add: {
          'cbuttons.bmp': [66, 77, 1, 2, 3],
        },
      ),
      'x',
    )!;
    expect(s.missing, contains('MAIN_PLAY_BUTTON'));
  });

  test('fichier trop gros (> 20 Mo) : ignoré', () async {
    final f = File('${Directory.systemTemp.createTempSync('big').path}/big.wsz')
      ..writeAsBytesSync(Uint8List(21 * 1024 * 1024));
    expect(await loadSkinData(f), isNull);
  });

  final local = Directory('test/fixtures/skins-local');
  for (final f
      in local.existsSync()
          ? local.listSync().whereType<File>().where(
              (f) => f.path.endsWith('.wsz'),
            )
          : <File>[]) {
    test('skin de Johnny : ${f.uri.pathSegments.last}', () {
      final s = parseSkin(f.readAsBytesSync(), 'x');
      expect(s, isNotNull);
      expect(
        s!.missing.where(
          (m) =>
              m.startsWith('MAIN_') &&
              !m.contains('CLUTTER') &&
              !m.contains('EASTER'),
        ),
        isEmpty,
      );
    });
  }
}

void skinImages() {
  testWidgets('Skin : chaque sprite devient une image affichable', (
    tester,
  ) async {
    final s = await tester.runAsync(
      () async => Skin.fromData((await loadSkinData(testSkin))!),
    );
    expect(s!.image('MAIN_PLAY_BUTTON')!.width, 23);
    expect(s.image('INCONNU'), isNull);
    expect(s.playlistColor('current'), const Color(0xFFF26EF2));
  });
}
