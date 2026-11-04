import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lafleurmusic/skins/skin.dart';
import 'package:lafleurmusic/ui/winamp/winamp_scope.dart';

Skin? _skin;

/// Le skin d'essai, chargé une fois (hors de l'horloge simulée).
Future<Skin> testSkin(WidgetTester tester) async {
  final loaded =
      _skin ??
      await tester.runAsync<Skin?>(
        () => Skin.load(File('test/fixtures/skins/lafleur-test.wsz')),
      );
  return _skin = loaded!;
}

Widget inSkin(Skin skin, Widget child, {double scale = 1}) => MaterialApp(
  home: Scaffold(
    body: WinampScope(skin: skin, scale: scale, child: child),
  ),
);
