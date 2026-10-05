/// Kana handling: script detection, katakana folding, and Hepburn romaji.
///
/// Plain Dart with no Flutter imports, so all of it is tested with
/// `flutter test` alone. Romaji is derived here rather than stored, because
/// the dictionary only ever gives a kana reading and a second copy of the
/// same fact is a second thing to drift.
library;

bool isHiragana(int c) => c >= 0x3041 && c <= 0x3096;

bool isKatakana(int c) =>
    (c >= 0x30A1 && c <= 0x30FA) || c == 0x30FC || (c >= 0x31F0 && c <= 0x31FF);

/// CJK ideographs, plus 々 (the repetition mark, which only ever stands for
/// a kanji) and 〆.
bool isKanji(int c) =>
    (c >= 0x4E00 && c <= 0x9FFF) ||
    (c >= 0x3400 && c <= 0x4DBF) ||
    (c >= 0xF900 && c <= 0xFAFF) ||
    c == 0x3005 ||
    c == 0x3006;

bool isKana(int c) => isHiragana(c) || isKatakana(c);

bool isJapanese(int c) => isKana(c) || isKanji(c);

bool containsKanji(String s) => s.runes.any(isKanji);

bool containsJapanese(String s) => s.runes.any(isJapanese);

/// Katakana folded onto hiragana, so one romaji table serves both. ー is
/// left alone: it means "lengthen the vowel before me", which the romaji
/// pass handles.
String katakanaToHiragana(String s) {
  final out = StringBuffer();
  for (final c in s.runes) {
    if (c >= 0x30A1 && c <= 0x30F6) {
      out.writeCharCode(c - 0x60);
    } else {
      out.writeCharCode(c);
    }
  }
  return out.toString();
}

const Map<String, String> _digraphs = {
  'きゃ': 'kya', 'きゅ': 'kyu', 'きょ': 'kyo',
  'ぎゃ': 'gya', 'ぎゅ': 'gyu', 'ぎょ': 'gyo',
  'しゃ': 'sha', 'しゅ': 'shu', 'しょ': 'sho', 'しぇ': 'she',
  'じゃ': 'ja', 'じゅ': 'ju', 'じょ': 'jo', 'じぇ': 'je',
  'ちゃ': 'cha', 'ちゅ': 'chu', 'ちょ': 'cho', 'ちぇ': 'che',
  'ぢゃ': 'ja', 'ぢゅ': 'ju', 'ぢょ': 'jo',
  'にゃ': 'nya', 'にゅ': 'nyu', 'にょ': 'nyo',
  'ひゃ': 'hya', 'ひゅ': 'hyu', 'ひょ': 'hyo',
  'びゃ': 'bya', 'びゅ': 'byu', 'びょ': 'byo',
  'ぴゃ': 'pya', 'ぴゅ': 'pyu', 'ぴょ': 'pyo',
  'みゃ': 'mya', 'みゅ': 'myu', 'みょ': 'myo',
  'りゃ': 'rya', 'りゅ': 'ryu', 'りょ': 'ryo',
  // Loanword combinations, which only appear in katakana but arrive here
  // already folded to hiragana.
  'ふぁ': 'fa', 'ふぃ': 'fi', 'ふぇ': 'fe', 'ふぉ': 'fo', 'ふゅ': 'fyu',
  'てぃ': 'ti', 'でぃ': 'di', 'とぅ': 'tu', 'どぅ': 'du', 'でゅ': 'dyu',
  'うぃ': 'wi', 'うぇ': 'we', 'うぉ': 'wo',
  'ゔぁ': 'va', 'ゔぃ': 'vi', 'ゔぇ': 've', 'ゔぉ': 'vo',
  'つぁ': 'tsa', 'つぃ': 'tsi', 'つぇ': 'tse', 'つぉ': 'tso',
  'いぇ': 'ye',
};

const Map<String, String> _monographs = {
  'あ': 'a', 'い': 'i', 'う': 'u', 'え': 'e', 'お': 'o',
  'か': 'ka', 'き': 'ki', 'く': 'ku', 'け': 'ke', 'こ': 'ko',
  'が': 'ga', 'ぎ': 'gi', 'ぐ': 'gu', 'げ': 'ge', 'ご': 'go',
  'さ': 'sa', 'し': 'shi', 'す': 'su', 'せ': 'se', 'そ': 'so',
  'ざ': 'za', 'じ': 'ji', 'ず': 'zu', 'ぜ': 'ze', 'ぞ': 'zo',
  'た': 'ta', 'ち': 'chi', 'つ': 'tsu', 'て': 'te', 'と': 'to',
  'だ': 'da', 'ぢ': 'ji', 'づ': 'zu', 'で': 'de', 'ど': 'do',
  'な': 'na', 'に': 'ni', 'ぬ': 'nu', 'ね': 'ne', 'の': 'no',
  'は': 'ha', 'ひ': 'hi', 'ふ': 'fu', 'へ': 'he', 'ほ': 'ho',
  'ば': 'ba', 'び': 'bi', 'ぶ': 'bu', 'べ': 'be', 'ぼ': 'bo',
  'ぱ': 'pa', 'ぴ': 'pi', 'ぷ': 'pu', 'ぺ': 'pe', 'ぽ': 'po',
  'ま': 'ma', 'み': 'mi', 'む': 'mu', 'め': 'me', 'も': 'mo',
  'や': 'ya', 'ゆ': 'yu', 'よ': 'yo',
  'ら': 'ra', 'り': 'ri', 'る': 'ru', 'れ': 're', 'ろ': 'ro',
  'わ': 'wa', 'ゐ': 'i', 'ゑ': 'e', 'を': 'o', 'ん': 'n',
  'ゔ': 'vu',
  // Small vowels on their own (outside a digraph), as in ぁ for emphasis.
  'ぁ': 'a', 'ぃ': 'i', 'ぅ': 'u', 'ぇ': 'e', 'ぉ': 'o',
  'ゃ': 'ya', 'ゅ': 'yu', 'ょ': 'yo', 'ゎ': 'wa',
  'ゕ': 'ka', 'ゖ': 'ke',
};

/// Hepburn romaji for [kana]. Anything that isn't kana passes through, so
/// a reading with a stray kanji or Latin letter in it degrades rather than
/// disappearing.
///
/// - っ doubles the next consonant (ch becomes tch, as in まっちゃ → matcha).
/// - ー repeats the previous vowel (ラーメン → raamen). Doubled vowels rather
///   than macrons: they type on any keyboard and read unambiguously.
/// - ん before a vowel or y is written n' (きんえん → kin'en), so it can't be
///   misread as the start of the next syllable.
String toRomaji(String kana) {
  final s = katakanaToHiragana(kana);
  final chars = s.split('');
  final out = StringBuffer();
  var geminate = false;
  var i = 0;
  while (i < chars.length) {
    final c = chars[i];

    if (c == 'っ') {
      geminate = true;
      i++;
      continue;
    }

    if (c == 'ー') {
      final written = out.toString();
      final vowel = _lastVowel(written);
      if (vowel != null) out.write(vowel);
      i++;
      continue;
    }

    String? syllable;
    var width = 1;
    if (i + 1 < chars.length) {
      syllable = _digraphs[c + chars[i + 1]];
      if (syllable != null) width = 2;
    }
    syllable ??= _monographs[c];

    if (syllable == null) {
      // Not kana. A pending っ before punctuation (ばかっ!) has nothing to
      // double, and is dropped rather than doubling the "!".
      geminate = false;
      out.write(c);
      i++;
      continue;
    }

    if (c == 'ん') {
      final next = i + 1 < chars.length ? _monographs[chars[i + 1]] : null;
      if (next != null && (_isVowel(next[0]) || next[0] == 'y')) {
        syllable = "n'";
      }
    }

    if (geminate) {
      out.write(syllable.startsWith('ch') ? 't' : syllable[0]);
      geminate = false;
    }
    out.write(syllable);
    i += width;
  }
  return out.toString();
}

bool _isVowel(String c) => 'aeiou'.contains(c);

String? _lastVowel(String written) {
  for (var i = written.length - 1; i >= 0; i--) {
    final c = written[i];
    if (_isVowel(c)) return c;
    if (c == "'") continue;
    return null;
  }
  return null;
}
