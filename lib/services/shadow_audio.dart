/// The audio side of shadowing: record yourself, play it back, play the
/// native reference. Behind an interface so the screen tests without a
/// microphone.
///
/// Nothing here scores pronunciation. No honest scoring is possible on a
/// phone, and a number that pretended would be worse than none — so it
/// records the attempt and plays it beside the reference, and you judge.
library;

import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import 'speech.dart';

abstract class ShadowAudio {
  /// Starts recording; false if the microphone isn't available (refused
  /// permission, or in use).
  Future<bool> startRecording();

  /// Stops; true if there's now a recording to play.
  Future<bool> stopRecording();

  Future<void> playYours();

  /// The reference, from the phone's Japanese voice. Null on success,
  /// otherwise why it couldn't be played.
  Future<String?> playNative(String text);

  Future<void> stopAll();

  void dispose();
}

class DeviceShadowAudio implements ShadowAudio {
  final AudioRecorder _recorder = AudioRecorder();
  AudioPlayer? _player;
  String? _path;

  @override
  Future<bool> startRecording() async {
    try {
      if (!await _recorder.hasPermission()) return false;
      await stopAll();
      final dir = await getTemporaryDirectory();
      // One file, overwritten each card: only the attempt in front of you
      // is worth keeping.
      _path = '${dir.path}/shadow.m4a';
      await _recorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc, numChannels: 1),
        path: _path!,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> stopRecording() async {
    try {
      return await _recorder.stop() != null;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> playYours() async {
    final path = _path;
    if (path == null) return;
    await Speech.instance.stop();
    final player = _player ??= AudioPlayer();
    // Mixes with the voice rather than taking audio focus — the same fix
    // the Listen chime needed.
    await player.setAudioContext(
      AudioContextConfig(focus: AudioContextConfigFocus.mixWithOthers).build(),
    );
    await player.stop();
    await player.play(DeviceFileSource(path));
  }

  @override
  Future<String?> playNative(String text) async {
    await _player?.stop();
    return Speech.instance.say(text);
  }

  @override
  Future<void> stopAll() async {
    await Speech.instance.stop();
    await _player?.stop();
  }

  @override
  void dispose() {
    _recorder.dispose();
    _player?.dispose();
  }
}
