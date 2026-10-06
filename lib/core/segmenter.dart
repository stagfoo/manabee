/// Splitting a bubble's Japanese into pieces worth looking up.
///
/// Japanese has no spaces, and a real morphological analyser (MeCab and
/// its dictionaries) is tens of megabytes. This is a heuristic instead,
/// built on the one signal the script gives for free: where kanji, kana
/// and punctuation change. A kanji run keeps the hiragana that follows it
/// (its okurigana — 若い, 食べる) until something that looks like a particle
/// starts. It is wrong sometimes; the reader lets you edit the lookup, so
/// it only has to be a good first guess.
library;

import 'kana.dart';

enum SegmentKind { word, kana, punctuation }

class Segment {
  const Segment(this.text, this.kind);

  final String text;
  final SegmentKind kind;

  /// Worth a dictionary lookup. Punctuation isn't; a lone hiragana particle
  /// (の, は) usually isn't either, and offering it as a chip next to the
  /// real words just buries them.
  bool get lookupWorthy =>
      kind == SegmentKind.word ||
      (kind == SegmentKind.kana && text.runes.length >= 2);

  @override
  bool operator ==(Object other) =>
      other is Segment && other.text == text && other.kind == kind;

  @override
  int get hashCode => Object.hash(text, kind);

  @override
  String toString() => 'Segment($text, $kind)';
}

/// Particles that end a kanji word's okurigana. Deliberately narrow: で
/// and the sentence-enders (か, よ, ね, な) turn up inside conjugations
/// (読んで, 少ない) far too often to treat as boundaries there.
const Set<String> _okuriganaStops = {'の', 'は', 'が', 'を', 'に', 'へ', 'も', 'と'};

/// Particles that may start the hiragana run right after a word. Here the
/// wider set is right: directly after 学生 or ラーメン, a で or か is
/// almost always the particle.
const Set<String> _particles = {
  'の',
  'は',
  'が',
  'を',
  'に',
  'へ',
  'も',
  'と',
  'で',
  'か',
  'よ',
  'ね',
  'な',
  'や',
};

/// The copula, which follows a noun directly and must not be swallowed as
/// okurigana (学生です) or split as a particle (で + す).
const List<String> _copulas = ['です', 'でし', 'だ', 'じゃ'];

bool _startsWithAny(List<String> chars, int i, List<String> prefixes) {
  for (final p in prefixes) {
    final n = p.length;
    if (i + n <= chars.length && chars.sublist(i, i + n).join() == p) {
      return true;
    }
  }
  return false;
}

/// The longest okurigana worth absorbing. Longer hiragana tails are almost
/// always a conjugation plus something else (食べられなかったのに), and
/// the dictionary does better with a shorter stem.
const int _maxOkurigana = 4;

enum _Class { kanji, hiragana, katakana, latin, other }

_Class _classOf(int c) {
  if (isKanji(c)) return _Class.kanji;
  if (isHiragana(c)) return _Class.hiragana;
  if (isKatakana(c)) return _Class.katakana;
  if ((c >= 0x30 && c <= 0x39) ||
      (c >= 0x41 && c <= 0x5A) ||
      (c >= 0x61 && c <= 0x7A) ||
      (c >= 0xFF10 && c <= 0xFF19) ||
      (c >= 0xFF21 && c <= 0xFF3A) ||
      (c >= 0xFF41 && c <= 0xFF5A)) {
    return _Class.latin;
  }
  return _Class.other;
}

List<Segment> segment(String text) {
  final chars = text.runes.map(String.fromCharCode).toList();
  final classes = text.runes.map(_classOf).toList();
  // ー after hiragana is manga stretching (きまーす), part of the word —
  // not a katakana word of its own.
  for (var k = 1; k < chars.length; k++) {
    if (chars[k] == 'ー' && classes[k - 1] == _Class.hiragana) {
      classes[k] = _Class.hiragana;
    }
  }
  final out = <Segment>[];
  var i = 0;

  // Whether the previous segment was a word, which is what makes a
  // following hiragana character read as a particle.
  var afterWord = false;

  while (i < chars.length) {
    final cls = classes[i];
    var j = i + 1;

    switch (cls) {
      case _Class.kanji:
        while (j < chars.length && classes[j] == _Class.kanji) {
          j++;
        }
        var capped = false;
        if (!_startsWithAny(chars, j, _copulas)) {
          var tail = 0;
          while (j < chars.length &&
              classes[j] == _Class.hiragana &&
              tail < _maxOkurigana &&
              !_okuriganaStops.contains(chars[j])) {
            j++;
            tail++;
          }
          capped = tail == _maxOkurigana;
        }
        out.add(Segment(chars.sublist(i, j).join(), SegmentKind.word));
        // Hiragana straight after a capped tail is more conjugation
        // (食べられな|かった), not a particle.
        afterWord = !capped;
      case _Class.katakana:
      case _Class.latin:
        while (j < chars.length && classes[j] == cls) {
          j++;
        }
        out.add(Segment(chars.sublist(i, j).join(), SegmentKind.word));
        afterWord = true;
      case _Class.hiragana:
        if (afterWord &&
            _particles.contains(chars[i]) &&
            !_startsWithAny(chars, i, _copulas)) {
          // "のこと" after a word: の stands alone, こと is the next piece.
          out.add(Segment(chars[i], SegmentKind.kana));
          afterWord = false;
          break;
        }
        while (j < chars.length && classes[j] == _Class.hiragana) {
          j++;
        }
        out.add(Segment(chars.sublist(i, j).join(), SegmentKind.kana));
        afterWord = false;
      case _Class.other:
        while (j < chars.length && classes[j] == _Class.other) {
          j++;
        }
        final s = chars.sublist(i, j).join();
        if (s.trim().isNotEmpty) {
          out.add(Segment(s.trim(), SegmentKind.punctuation));
        }
        afterWord = false;
    }
    i = j;
  }
  return out;
}

/// The distinct lookup-worthy pieces of [text], in reading order, in the
/// form the dictionary knows (see normalizeForLookup).
List<String> lookupCandidates(String text) {
  final seen = <String>{};
  final out = <String>[];
  for (final s in segment(text)) {
    if (!s.lookupWorthy) continue;
    final q = normalizeForLookup(s.text);
    if (q.isNotEmpty && seen.add(q)) out.add(q);
  }
  return out;
}

/// Index of the first stretch ー inside a hiragana word — after hiragana,
/// with more text after it — or -1. A ー at the very end (ひー) is a plain
/// stretch and needs no decision.
int _innerStretch(List<int> runes) {
  for (var i = 1; i < runes.length - 1; i++) {
    if (runes[i] == 0x30FC && isHiragana(runes[i - 1])) return i;
  }
  return -1;
}

/// The lookups [text] stands for, with any inner ー settled by the
/// dictionary.
///
/// A ー inside a hiragana run is either stretching within one word
/// (いってきまーす = いってきます) or the end of a drawn-out word followed
/// by the next (ひーすっかり = ひー + すっかり). The script can't tell those
/// apart; the dictionary can: if the run with its ー removed is a word
/// [isWord] knows, it's one word. Otherwise it splits at the ー, and a
/// one-kana exclamation before it (ひー, あー) is dropped — the dictionary
/// has nothing for those but a misleading near-match.
Future<List<String>> resolveStretches(
  String text,
  Future<bool> Function(String) isWord,
) async {
  final runes = text.runes.toList();
  final i = _innerStretch(runes);
  final joined = normalizeForLookup(text);
  // One drawn-out kana (ひー, あー) is an exclamation; its one-kana
  // "lookup" only ever finds 火 or 亜.
  if (joined.runes.length == 1 && text.runes.length > 1) return const [];
  if (i < 0 || await isWord(joined)) return [if (joined.isNotEmpty) joined];
  final left = String.fromCharCodes(runes.sublist(0, i));
  final right = String.fromCharCodes(runes.sublist(i + 1));
  return [
    if (left.runes.length >= 2) normalizeForLookup(left),
    // A lone kana left over after the split is a particle or a fragment,
    // never worth a lookup of its own.
    for (final q in await resolveStretches(right, isWord))
      if (!(q.runes.length == 1 && isKana(q.runes.first))) q,
  ];
}

/// [lookupCandidates], with inner ー settled by the dictionary (see
/// [resolveStretches]).
Future<List<String>> resolvedCandidates(
  String text,
  Future<bool> Function(String) isWord,
) async {
  final seen = <String>{};
  final out = <String>[];
  for (final s in segment(text)) {
    if (!s.lookupWorthy) continue;
    for (final q in await resolveStretches(s.text, isWord)) {
      if (q.isNotEmpty && seen.add(q)) out.add(q);
    }
  }
  return out;
}
