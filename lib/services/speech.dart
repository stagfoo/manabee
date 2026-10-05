/// Japanese pronunciation from the device's own text-to-speech voice.
///
/// Can fail on a real device for reasons the app can't fix — no Japanese
/// voice installed is the usual one — so [say] reports rather than throws,
/// and callers say why nothing was heard.
library;

import 'package:flutter_tts/flutter_tts.dart';

class Speech {
  Speech._();
  static final Speech instance = Speech._();

  final FlutterTts _tts = FlutterTts();
  bool _ready = false;
  bool _hasJapanese = false;
  double rate = 0.45;

  Future<void> _init() async {
    if (_ready) return;
    _ready = true;
    try {
      final languages = await _tts.getLanguages;
      _hasJapanese =
          languages is List &&
          languages.any((l) => '$l'.toLowerCase().startsWith('ja'));
      if (_hasJapanese) {
        await _tts.setLanguage('ja-JP');
        await _tts.setSpeechRate(rate);
      }
    } catch (_) {
      _hasJapanese = false;
    }
  }

  Future<void> setRate(double value) async {
    rate = value;
    if (_hasJapanese) {
      try {
        await _tts.setSpeechRate(value);
      } catch (_) {}
    }
  }

  /// Null on success, otherwise a reason fit to show.
  Future<String?> say(String text) async {
    await _init();
    if (!_hasJapanese) {
      return 'No Japanese voice installed — add one in Android\'s '
          'text-to-speech settings.';
    }
    try {
      await _tts.stop();
      await _tts.speak(text);
      return null;
    } catch (_) {
      return 'Text-to-speech failed.';
    }
  }
}
