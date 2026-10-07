/// Pronunciation from the device's own text-to-speech voices — Japanese
/// for the words, English for their meanings in Listen mode.
///
/// Can fail on a real device for reasons the app can't fix — no Japanese
/// voice installed is the usual one — so [say] reports rather than throws,
/// and callers say why nothing was heard.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

class Speech {
  Speech._();
  static final Speech instance = Speech._();

  final FlutterTts _tts = FlutterTts();
  bool _ready = false;
  bool _hasJapanese = false;
  bool _hasEnglish = false;
  String? _language;
  double rate = 0.45;

  Future<void> _init() async {
    if (_ready) return;
    _ready = true;
    try {
      final languages = await _tts.getLanguages;
      bool has(String prefix) =>
          languages is List &&
          languages.any((l) => '$l'.toLowerCase().startsWith(prefix));
      _hasJapanese = has('ja');
      _hasEnglish = has('en');
      // speak() returns when the sentence has been said, not when it was
      // queued — what lets Listen mode time its pauses.
      await _tts.awaitSpeakCompletion(true);
      await _tts.setSpeechRate(rate);
    } catch (_) {
      _hasJapanese = false;
    }
  }

  Future<void> setRate(double value) async {
    rate = value;
    try {
      await _tts.setSpeechRate(value);
    } catch (_) {}
  }

  Future<void> _use(String language) async {
    if (_language == language) return;
    await _tts.setLanguage(language);
    _language = language;
  }

  /// Says Japanese [text], returning once it has been said. Null on
  /// success, otherwise a reason fit to show.
  Future<String?> say(String text) async {
    await _init();
    if (!_hasJapanese) {
      return 'No Japanese voice installed — add one in Android\'s '
          'text-to-speech settings.';
    }
    try {
      await _tts.stop();
      await _use('ja-JP');
      await _tts.speak(text);
      return null;
    } catch (_) {
      return 'Text-to-speech failed.';
    }
  }

  /// Says English [text] (a meaning, in Listen mode). Null on success.
  Future<String?> sayEnglish(String text) async {
    await _init();
    if (!_hasEnglish) {
      return 'No English voice installed — meanings are shown, not spoken.';
    }
    try {
      await _tts.stop();
      await _use('en-US');
      await _tts.speak(text);
      return null;
    } catch (_) {
      return 'Text-to-speech failed.';
    }
  }

  /// Forgets which voices exist, so the next call asks again. Tests only:
  /// on a phone the installed voices don't change under a running app.
  @visibleForTesting
  void reset() {
    _ready = false;
    _language = null;
  }

  Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (_) {}
  }
}
