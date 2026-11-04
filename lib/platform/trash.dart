import 'dart:io';

import 'package:flutter/services.dart';

/// Met un fichier à la Corbeille (jamais d'effacement définitif).
abstract interface class Trash {
  /// Lève [FileSystemException] si le fichier n'a pas pu être mis à la Corbeille.
  Future<void> trash(String path);
}

/// Corbeille du Mac : `NSFileManager.trashItem` par le canal `lafleur/trash` (macos/Runner/TrashChannel.swift).
class MacTrash implements Trash {
  static const _channel = MethodChannel('lafleur/trash');

  @override
  Future<void> trash(String path) async {
    try {
      await _channel.invokeMethod<void>('trash', path);
    } on PlatformException catch (e) {
      throw FileSystemException(e.message ?? 'trash failed', path);
    } on MissingPluginException {
      throw FileSystemException('trash unavailable', path);
    }
  }
}
