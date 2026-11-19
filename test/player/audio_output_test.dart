import 'package:flutter_test/flutter_test.dart';
import 'package:lafleurmusic/player/audio_output.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart' hide Track;

/// Ne retient que les réglages de sortie (le reste de Player n'est pas utilisé).
class FakeMpv implements Player {
  final calls = <String>[];
  @override
  Future<void> setAudioDriver(String d) async => calls.add('ao $d');
  @override
  Future<void> setAudioSampleRate(int r) async => calls.add('rate $r');
  @override
  Future<void> setAudioFormat(Format f) async => calls.add('format ${f.name}');
  @override
  Future<void> setAudioChannels(Channels c) async =>
      calls.add('channels ${c == Channels.stereo ? 'stereo' : c}');
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

void main() {
  test('sortie son : AVFoundation d\'abord (le CoreAudio de mpv plante quand un appareil change), CoreAudio en secours', () async {
    final mpv = FakeMpv();
    await fixedOutput(mpv);
    expect(mpv.calls.first, 'ao avfoundation,coreaudio');
    expect(
      mpv.calls,
      containsAll(['rate 48000', 'format float32', 'channels stereo']),
    );
  });
}
