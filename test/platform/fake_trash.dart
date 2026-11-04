import 'dart:io';

import 'package:lafleurmusic/platform/trash.dart';

/// Corbeille des tests : retient les chemins, échoue sur ceux de [failOn], retire vraiment le fichier sinon.
class FakeTrash implements Trash {
  final trashed = <String>[];
  final failOn = <String>{};

  @override
  Future<void> trash(String path) async {
    if (failOn.contains(path) || !File(path).existsSync()) {
      throw FileSystemException('trash failed', path);
    }
    File(path).deleteSync();
    trashed.add(path);
  }
}
