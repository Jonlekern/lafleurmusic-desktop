import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lafleurmusic/skins/skins_folder.dart';

void main() {
  late Directory root;
  late SkinsFolder folder;
  setUp(() {
    root = Directory.systemTemp.createTempSync('sk');
    folder = SkinsFolder(Directory('${root.path}/LAFLEURMUSIC/Skins'));
  });
  tearDown(() => root.deleteSync(recursive: true));

  test('ensure crée le dossier', () async {
    await folder.ensure();
    expect(folder.dir.existsSync(), isTrue);
  });

  test('list : seulement les .wsz, triés par nom sans casse', () async {
    await folder.ensure();
    for (final n in ['b.wsz', 'A.WSZ', 'c.wal', 'readme.txt']) {
      File('${folder.dir.path}/$n').writeAsStringSync('x');
    }
    Directory('${folder.dir.path}/dossier.wsz').createSync();
    expect((await folder.list()).map((f) => f.uri.pathSegments.last), [
      'A.WSZ',
      'b.wsz',
    ]);
  });

  test('dossier absent : liste vide', () async {
    expect(await folder.list(), isEmpty);
  });

  test('add copie le skin glissé ; même nom → « nom (2).wsz »', () async {
    final src = File('${root.path}/Trinity.wsz')..writeAsStringSync('x');
    final a = await folder.add(src);
    final b = await folder.add(src);
    expect(a!.uri.pathSegments.last, 'Trinity.wsz');
    expect(b!.uri.pathSegments.last, 'Trinity (2).wsz');
    expect(src.existsSync(), isTrue);
  });

  test('add refuse ce qui n’est pas un .wsz', () async {
    final src = File('${root.path}/photo.jpg')..writeAsStringSync('x');
    expect(await folder.add(src), isNull);
  });

  test('dossier par défaut : Musique/LAFLEURMUSIC/Skins', () {
    expect(
      SkinsFolder.defaultDir(home: '/Users/j').path,
      '/Users/j/Music/LAFLEURMUSIC/Skins',
    );
  });
}
