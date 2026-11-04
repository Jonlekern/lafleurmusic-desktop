import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:drift/native.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:mpv_audio_kit/mpv_audio_kit.dart' show MpvAudioKit;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:window_manager/window_manager.dart';

import 'app_exit.dart';
import 'app_scope.dart';
import 'l10n/strings.dart';
import 'artists/artist_lookup.dart';
import 'artists/artist_store.dart';
import 'library/covers.dart';
import 'library/db.dart';
import 'library/play_counter.dart';
import 'library/track_ops.dart';
import 'platform/trash.dart';
import 'library/folders.dart';
import 'library/scanner.dart';
import 'player/equalizer.dart';
import 'player/loudness.dart';
import 'repair/musicbrainz.dart';
import 'player/player.dart';
import 'settings.dart';
import 'tags/tag_reader.dart';
import 'tags/tag_writer.dart';
import 'theme/lafleur_theme.dart';
import 'skins/skins_folder.dart';
import 'ui/library_screen.dart';
import 'ui/window_mode.dart';
import 'ui/winamp/winamp_screen.dart';
import 'ui/welcome_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MpvAudioKit.ensureInitialized();
  await windowManager.ensureInitialized();
  // LAFLEURMUSIC_SUPPORT_DIR : dossier de bibliothèque à part, pour essayer une copie sans toucher à la vraie
  final override = Platform.environment['LAFLEURMUSIC_SUPPORT_DIR'];
  final support = override != null && override.isNotEmpty
      ? Directory(override)
      : await getApplicationSupportDirectory();
  // réglages (égaliseur) : rechargés, appliqués tout de suite, enregistrés à chaque changement
  final settingsFile = File(p.join(support.path, 'settings.json'));
  final settings = await AppSettings.load(settingsFile);
  final player = LafleurPlayer();
  await player.setEqualizer(settings.equalizer);
  await player.setCrossfade(
    settings.crossfade ? settings.crossfadeSeconds : null,
  );
  final equalizer = ValueNotifier<Equalizer>(settings.equalizer);
  final applyEq = Latest();
  equalizer.addListener(() {
    applyEq.run(() => player.setEqualizer(equalizer.value));
    settings.equalizer = equalizer.value;
    settings.save(settingsFile);
  });
  // vue Artistes (grille ou liste) : retenue
  final artistGrid = ValueNotifier<bool>(settings.artistGrid);
  artistGrid.addListener(() {
    settings.artistGrid = artistGrid.value;
    settings.save(settingsFile);
  });
  // skins Winamp : Musique › LAFLEURMUSIC › Skins, créé dès le premier lancement
  final skins = SkinsFolder(SkinsFolder.defaultDir());
  try {
    await skins.ensure();
  } on FileSystemException {
    // dossier Musique inaccessible : pas de bouton Skins
  }
  final skinFiles = ValueNotifier<List<File>>(await skins.list());
  final db = LibraryDb(
    NativeDatabase.createInBackground(
      File(p.join(support.path, 'library.sqlite')),
    ),
  );
  // Volume égal : mesures gardées dans la base, allumé si on l'avait laissé allumé
  final loudness = LoudnessService(db, player)..enabled = settings.equalVolume;
  player.gainOf =
      loudness.gainOf; // le 2e lecteur du fondu démarre au bon niveau
  runApp(
    LafleurApp(
      db: db,
      loudness: loudness,
      folders: MusicFolders(File(p.join(support.path, 'folders.json'))),
      covers: Covers(cacheDir: Directory(p.join(support.path, 'covers'))),
      player: player,
      equalizer: equalizer,
      artistGrid: artistGrid,
      artistsDir: Directory(p.join(support.path, 'artists')),
      skins: skins,
      skinFiles: skinFiles,
      settings: settings,
      saveSettings: () => settings.save(settingsFile),
      strings: Strings.of(PlatformDispatcher.instance.locale),
    ),
  );
}

class LafleurApp extends StatefulWidget {
  const LafleurApp({
    super.key,
    required this.db,
    required this.folders,
    required this.covers,
    required this.player,
    required this.strings,
    required this.equalizer,
    required this.artistGrid,
    required this.artistsDir,
    required this.skins,
    required this.skinFiles,
    required this.settings,
    required this.saveSettings,
    required this.loudness,
  });
  final LoudnessService loudness;
  final SkinsFolder skins;
  final ValueNotifier<List<File>> skinFiles;
  final AppSettings settings;
  final VoidCallback saveSettings;
  final ValueNotifier<bool> artistGrid;
  final Directory artistsDir;
  final LibraryDb db;
  final MusicFolders folders;
  final Covers covers;
  final LafleurPlayer player;
  final Strings strings;
  final ValueNotifier<Equalizer> equalizer;

  @override
  State<LafleurApp> createState() => _LafleurAppState();
}

class _LafleurAppState extends State<LafleurApp> with WidgetsBindingObserver {
  final _nav = GlobalKey<NavigatorState>();
  late final PlayCounter _plays;
  late final AppLifecycleListener _exit;
  final _window = DesktopWindow();
  bool _winampTried = false;
  late final Scanner _scanner = Scanner(widget.db, TagLibReader());
  late final TagWriter _writer = TagWriter(
    widget.db,
    null,
    widget.covers.forget,
  );
  final _mb = MusicBrainz(http.Client());
  // photos et résumés d'artistes : cherchés tout seuls (Wikipédia dans la langue de l'ordi, sinon anglais)
  late final ArtistStore _artists = ArtistStore(
    dir: widget.artistsDir,
    find: ArtistLookup(
      _mb,
      http.Client(),
      lang: widget.strings.fr ? 'fr' : 'en',
    ).find,
  );
  final _busy = <int>{}; // dossiers en cours de scan
  bool? _hasFolders;
  (int, int)? _firstScan;
  String? _emptyFolder;
  Timer? _retry;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Cmd + Q : tout arrêter et fermer la base avant que Dart s'arrête (voir app_exit.dart)
    _exit = AppLifecycleListener(
      onExitRequested: () => closeBeforeExit([
        () async => _retry?.cancel(),
        _plays.dispose,
        () async => widget.loudness.dispose(),
        widget.db.close,
      ]),
    );
    _plays = PlayCounter(widget.player.state, widget.db); // Top 100
    widget.folders.load().then((list) {
      setState(() => _hasFolders = list.isNotEmpty);
      // quitté en mode Winamp : on y revient (si le skin se lit encore)
      if (list.isNotEmpty && widget.settings.winampMode && !_winampTried) {
        _winampTried = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final ctx = _nav.currentContext;
          if (ctx != null) openWinamp(ctx);
        });
      }
      for (final f in list) {
        _scan(f); // nouveaux fichiers depuis la dernière fois, en fond
      }
    });
    // NAS absent : on réessaie toutes les 30 s, les morceaux reviennent tout seuls
    _retry = Timer.periodic(const Duration(seconds: 30), (_) async {
      for (final f in await widget.folders.load()) {
        if ((await widget.db.folderTracks(f.id)).any((t) => t.missing)) {
          _scan(f);
        }
      }
    });
  }

  // retour au premier plan : le dossier Skins a peut-être changé
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      widget.skins.list().then((l) => widget.skinFiles.value = l);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _retry?.cancel();
    _plays.dispose();
    _exit.dispose();
    super.dispose();
  }

  Future<void> _scan(MusicFolder f) async {
    if (!_busy.add(f.id)) return;
    try {
      await _scanner.scan(f).drain<void>();
    } finally {
      _busy.remove(f.id);
    }
  }

  Future<void> _addFolder(String path) async {
    if (_firstScan != null) return; // un scan est déjà en cours
    final folder = await widget.folders.add(path);
    setState(() {
      _firstScan = (0, 0);
      _emptyFolder = null;
    });
    _busy.add(folder.id);
    var total = 0;
    try {
      await for (final pr in _scanner.scan(folder)) {
        total = pr.total;
        if (!mounted) return;
        // la bibliothèque s'affiche dès la liste des fichiers faite et se remplit pendant le scan
        setState(() {
          _firstScan = (pr.done, pr.total);
          if (pr.total > 0) _hasFolders = true;
        });
      }
    } finally {
      _busy.remove(folder.id);
    }
    if (total == 0) {
      await widget.folders.remove(
        folder.id,
      ); // dossier sans musique : on en redemande un
      if (mounted) {
        setState(() {
          _emptyFolder = path;
          _hasFolders = false;
        });
      }
    }
    if (mounted) setState(() => _firstScan = null);
  }

  @override
  Widget build(BuildContext context) => AppScope(
    db: widget.db,
    player: widget.player,
    covers: widget.covers,
    strings: widget.strings,
    equalizer: widget.equalizer,
    writer: _writer,
    musicbrainz: _mb,
    artists: _artists,
    artistGrid: widget.artistGrid,
    skins: widget.skins,
    skinFiles: widget.skinFiles,
    window: _window,
    settings: widget.settings,
    saveSettings: widget.saveSettings,
    // Supprimer / Remplacer : Corbeille du Mac seulement pour l'instant (Windows plus tard)
    loudness: widget.loudness,
    ops: Platform.isMacOS
        ? TrackOps(widget.db, _writer, MacTrash(), widget.player)
        : null,
    child: MaterialApp(
      navigatorKey: _nav,
      // un .wsz glissé n'importe où sur la fenêtre va dans le dossier Skins
      builder: (context, child) => DropTarget(
        onDragDone: (d) =>
            addDroppedSkins(context, [for (final f in d.files) f.path]),
        child: child ?? const SizedBox.shrink(),
      ),
      title: 'LAFLEURMUSIC',
      debugShowCheckedModeBanner: false,
      theme: lafleurTheme(),
      home: switch (_hasFolders) {
        null => const Scaffold(),
        false => WelcomeScreen(
          strings: widget.strings,
          onFolder: _addFolder,
          progress: _firstScan,
          emptyFolder: _emptyFolder,
        ),
        true => const LibraryScreen(),
      },
    ),
  );
}
