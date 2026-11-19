import 'package:mpv_audio_kit/mpv_audio_kit.dart';

/// Sortie son d'un lecteur mpv qui joue (lecteur principal et 2e lecteur du fondu).
///
/// AVFoundation d'abord : la sortie CoreAudio de mpv 0.41 laisse un écouteur d'appareils branché
/// quand elle n'arrive pas à s'ouvrir (ex. la sortie de Jump Desktop), et l'appli plante
/// au changement d'appareil suivant. CoreAudio reste en secours.
///
/// Format fixe (48 kHz, float, stéréo) : mpv ne rouvre pas la sortie à chaque changement de format,
/// ce qui faisait planter mpv_audio_kit sur le Mac (44,1 kHz → 48 kHz).
Future<void> fixedOutput(Player mpv) async {
  await mpv.setAudioDriver('avfoundation,coreaudio');
  await mpv.setAudioSampleRate(48000);
  await mpv.setAudioFormat(Format.float32);
  await mpv.setAudioChannels(Channels.stereo);
}
