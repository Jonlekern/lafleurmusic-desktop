import 'dart:async';

import 'package:flutter/services.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';

/// Sortie son des lecteurs mpv qui jouent (lecteur principal et 2e lecteur du fondu).
///
/// CoreAudio sur une vraie sortie (haut-parleurs, casque…) : c'est lui qui nourrit le spectre
/// (le visualiseur, le rond rose qui bat).
/// AVFoundation sur une sortie virtuelle (Jump Desktop…) : CoreAudio n'arrive pas à l'ouvrir
/// (« unable to set the input channel layout »), et mpv 0.41 laisse alors un écouteur d'appareils
/// branché sur une mémoire libérée : l'appli plante au changement d'appareil suivant.
String audioDriverFor({required bool virtualOutput}) =>
    virtualOutput ? 'avfoundation' : 'coreaudio';

/// Format fixe (48 kHz, float, stéréo) : mpv ne rouvre pas la sortie à chaque changement de format,
/// ce qui faisait planter mpv_audio_kit sur le Mac (44,1 kHz → 48 kHz).
/// AVFoundation tant que la sortie du Mac n'est pas connue (voir [followAudioRoute]).
Future<void> fixedOutput(Player mpv) async {
  await mpv.setAudioDriver(audioDriverFor(virtualOutput: true));
  await mpv.setAudioSampleRate(48000);
  await mpv.setAudioFormat(Format.float32);
  await mpv.setAudioChannels(Channels.stereo);
}

/// La sortie son par défaut du Mac.
abstract interface class AudioRoute {
  /// Vrai si c'est un appareil virtuel ; vrai aussi quand on ne sait pas.
  Future<bool> isVirtual();

  /// Une valeur à chaque changement de sortie par défaut.
  Stream<bool> get changes;
}

/// Canal « lafleur/audio » (macos/Runner/MainFlutterWindow.swift).
class MacAudioRoute implements AudioRoute {
  const MacAudioRoute();
  static const _channel = MethodChannel('lafleur/audio');
  static StreamController<bool>? _ctrl;

  @override
  Future<bool> isVirtual() async {
    try {
      return await _channel.invokeMethod<bool>('isVirtual') ?? true;
    } on MissingPluginException {
      return true;
    } on PlatformException {
      return true;
    }
  }

  @override
  Stream<bool> get changes {
    final ctrl = _ctrl ??= StreamController<bool>.broadcast();
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'changed') ctrl.add(call.arguments as bool? ?? true);
    });
    return ctrl.stream;
  }
}

/// Applique le pilote qui va avec la sortie du Mac, tout de suite puis à chaque changement.
Future<StreamSubscription<bool>> followAudioRoute(
  AudioRoute route,
  Future<void> Function(String driver) apply,
) async {
  final sub = route.changes.listen(
    (v) => apply(audioDriverFor(virtualOutput: v)),
  );
  await apply(audioDriverFor(virtualOutput: await route.isVirtual()));
  return sub;
}
