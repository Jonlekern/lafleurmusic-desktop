import 'dart:async';

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

class FakeRoute implements AudioRoute {
  FakeRoute(this.virtual);
  bool virtual;
  final ctrl = StreamController<bool>();
  @override
  Future<bool> isVirtual() async => virtual;
  @override
  Stream<bool> get changes => ctrl.stream;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'format fixe ; AVFoundation tant qu\'on ne connaît pas la sortie',
    () async {
      final mpv = FakeMpv();
      await fixedOutput(mpv);
      expect(mpv.calls.first, 'ao avfoundation');
      expect(
        mpv.calls,
        containsAll(['rate 48000', 'format float32', 'channels stereo']),
      );
    },
  );

  test('haut-parleurs : CoreAudio (le spectre marche) ; sortie virtuelle (Jump Desktop) : AVFoundation', () {
    expect(audioDriverFor(virtualOutput: false), 'coreaudio');
    expect(audioDriverFor(virtualOutput: true), 'avfoundation');
  });

  test('suit la sortie du Mac : au départ, puis à chaque changement', () async {
    final route = FakeRoute(false);
    final seen = <String>[];
    final sub = await followAudioRoute(route, (d) async => seen.add(d));
    expect(seen, ['coreaudio']);
    route.ctrl.add(true);
    await pumpEventQueue();
    route.ctrl.add(false);
    await pumpEventQueue();
    expect(seen, ['coreaudio', 'avfoundation', 'coreaudio']);
    await sub.cancel();
  });

  test('sortie inconnue (canal absent) : on reste sur AVFoundation', () async {
    final seen = <String>[];
    await followAudioRoute(const MacAudioRoute(), (d) async => seen.add(d));
    expect(seen, ['avfoundation']);
  });
}
