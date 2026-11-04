import 'package:flutter/widgets.dart';

import 'dart:io';

import 'artists/artist_store.dart';
import 'l10n/strings.dart';
import 'library/covers.dart';
import 'library/db.dart';
import 'library/track_ops.dart';
import 'player/equalizer.dart';
import 'player/loudness.dart';
import 'player/player.dart';
import 'repair/musicbrainz.dart';
import 'settings.dart';
import 'skins/skins_folder.dart';
import 'tags/tag_writer.dart';
import 'ui/window_mode.dart';

/// Les services de l'appli, accessibles depuis tous les écrans.
class AppScope extends InheritedWidget {
  const AppScope({
    super.key,
    required this.db,
    required this.player,
    required this.covers,
    required this.strings,
    ValueNotifier<Equalizer>? equalizer,
    this.writer,
    this.musicbrainz,
    this.artists,
    this.artistGrid,
    this.skins,
    this.skinFiles,
    this.window,
    this.settings,
    this.saveSettings,
    this.ops,
    this.pickAudio,
    this.loudness,
    required super.child,
  }) : _eq = equalizer;
  final LibraryDb db;
  final PlayerController player;
  final Covers covers;
  final Strings strings;
  final ValueNotifier<Equalizer>? _eq;
  final TagWriter? writer; // écriture des tags (null : lecture seule)
  final MusicBrainz? musicbrainz; // « Réparer »
  final ArtistStore? artists; // photos et résumés d'artistes
  final ValueNotifier<bool>?
  artistGrid; // vue Artistes : grille (sinon liste), retenue
  final SkinsFolder? skins; // dossier des skins Winamp
  final ValueNotifier<List<File>>?
  skinFiles; // skins du dossier (bouton Skins visible s'il y en a)
  final WindowMode? window; // grande fenêtre ou petit Winamp
  final AppSettings? settings; // réglages Winamp (enregistrés par saveSettings)
  final VoidCallback? saveSettings;
  final TrackOps?
  ops; // supprimer / remplacer / modifier (null : lecture seule)
  final Future<File?> Function()?
  pickAudio; // choisir un fichier audio (Remplacer par…)
  final LoudnessService? loudness; // Volume égal
  static final _noEq = ValueNotifier(Equalizer.named('flat'));

  /// Réglage d'égaliseur en cours (l'appli l'applique au lecteur et l'enregistre à chaque changement).
  ValueNotifier<Equalizer> get equalizer => _eq ?? _noEq;

  static AppScope of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!;

  @override
  bool updateShouldNotify(AppScope old) => old.strings.fr != strings.fr;
}
