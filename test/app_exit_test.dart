import 'dart:async';
import 'dart:ui' show AppExitResponse;

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lafleurmusic/app_exit.dart';
import 'package:lafleurmusic/library/db.dart';

void main() {
  test('avant de quitter : chaque étape dans l’ordre, la base fermée, puis on quitte', () async {
    final db = LibraryDb(NativeDatabase.memory());
    await db.watchTop(1).first; // base ouverte
    final done = <String>[];
    final r = await closeBeforeExit([
      () async => done.add('timer'),
      () async {
        await db.close();
        done.add('db');
      },
    ]);
    expect(r, AppExitResponse.exit);
    expect(done, ['timer', 'db']);
    expect(() => db.watchTop(1).first, throwsA(anything)); // vraiment fermée
  });

  test('une étape qui plante ou qui traîne n’empêche pas de quitter', () async {
    final done = <String>[];
    final r = await closeBeforeExit([
      () async => throw StateError('oups'),
      () => Completer<void>().future, // ne finit jamais
      () async => done.add('db'),
    ], timeout: const Duration(milliseconds: 50));
    expect(r, AppExitResponse.exit);
    expect(done, ['db']);
  });
}
