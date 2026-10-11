/// Offline checks for Japanese you've written.
///
/// Not a grammar checker — no good offline one exists for Japanese — but
/// the mistakes that can be caught for certain without one, using the
/// dictionary already in the app:
///
/// - **Not a word**: a run of kana or kanji no dictionary word covers,
///   even with conjugation undone. Usually a typo (たべまた for たべました),
///   sometimes a name.
/// - **Doubled particle**: the same particle twice in a row (私がが).
/// - **Mixed style**: some sentences polite (です/ます), others plain
///   (だ/る/た). Either is fine; mixing them in one entry usually isn't.
///
/// Everything else — whether it sounds natural — is beyond what can be
/// checked offline, and this doesn't pretend otherwise.
library;

import '../models.dart';
import 'kana.dart';
import 'scan.dart';

enum FindingKind { notAWord, doubledParticle, mixedStyle }

class Finding {
  const Finding(this.kind, this.start, this.end, this.message);

  final FindingKind kind;

  /// The span of the text it's about.
  final int start;
  final int end;
  final String message;

  @override
  String toString() => '${kind.name}[$start,$end) $message';
}

enum Style { polite, plain, neither }

/// The polite and plain endings a sentence is judged by, longest first.
const _politeEndings = [
  'ませんでした',
  'ましょう',
  'ました',
  'ません',
  'ます',
  'でしょう',
  'でした',
  'です',
  'ください',
];
const _plainEndings = [
  'なかった', 'だろう', 'だった', 'かった', 'ない', 'だ', 'た',
  // Dictionary-form verbs end in any u-row kana (行く, 泳ぐ, 話す, 待つ,
  // 死ぬ, 遊ぶ, 読む, 帰る, 買う) and adjectives in い. Polite endings are
  // checked first, so です/ます never reach the す here.
  'う', 'く', 'ぐ', 'す', 'つ', 'ぬ', 'ぶ', 'む', 'る', 'い',
];

/// Sentence-final particles, peeled off before a sentence's style is
/// judged: 行きますよ is polite, 行くね is plain.
const _finalParticles = ['よね', 'ねえ', 'よ', 'ね', 'な', 'か', 'わ', 'ぞ', 'さ', 'の'];

/// Whether [sentence] ends polite, plain, or in neither (a noun, a
/// fragment, a question word).
Style styleOf(String sentence) {
  var s = sentence.trim();
  var stripped = true;
  while (stripped) {
    stripped = false;
    for (final p in _finalParticles) {
      if (s.length > p.length && s.endsWith(p)) {
        s = s.substring(0, s.length - p.length);
        stripped = true;
        break;
      }
    }
  }
  if (_politeEndings.any(s.endsWith)) return Style.polite;
  // Plain only when the ending is kana after a word: 寒い, 行く, 見た —
  // not a bare noun that happens to end in る or い.
  if (s.length >= 2 && _plainEndings.any(s.endsWith)) {
    final before = s.runes.elementAt(s.runes.length - 2);
    if (isKanji(before) || isHiragana(before)) return Style.plain;
  }
  return Style.neither;
}

final RegExp _sentenceEnd = RegExp(r'[。！？!?\n]');

/// The sentences of [text], as spans.
List<(int, int)> sentences(String text) {
  final out = <(int, int)>[];
  var start = 0;
  for (final m in _sentenceEnd.allMatches(text)) {
    if (text.substring(start, m.start).trim().isNotEmpty) {
      out.add((start, m.start));
    }
    start = m.end;
  }
  if (text.substring(start).trim().isNotEmpty) out.add((start, text.length));
  return out;
}

Future<List<Finding>> checkJapanese(
  String text,
  Future<List<Entry>> Function(String) lookup,
) async {
  final findings = <Finding>[];
  final words = await segmentSentence(text, lookup);

  // Not a word: Japanese characters no word covers — or covered only by
  // one-kana "words" in a row. Nearly every kana is some dictionary entry
  // on its own (た is 田, ま is 間), so a typo like たべまた gets explained
  // away as four of them; real writing almost never strings single-kana
  // words together outside particles.
  final suspect = List.filled(text.length, false);
  for (var i = 0; i < text.length; i++) {
    suspect[i] = isJapanese(text.codeUnitAt(i));
  }
  for (final w in words) {
    final oneKana =
        w.end - w.start == 1 && isHiragana(text.codeUnitAt(w.start));
    if (w.particle || !oneKana) {
      for (var i = w.start; i < w.end; i++) {
        suspect[i] = false;
      }
    }
  }
  var i = 0;
  while (i < text.length) {
    if (!suspect[i]) {
      i++;
      continue;
    }
    var j = i + 1;
    while (j < text.length && suspect[j]) {
      j++;
    }
    // A lone one-kana word can be real (を written as お, a name); two or
    // more in a row is the pattern a typo leaves.
    final covered = words.any((w) => w.start == i && w.end == j);
    if (j - i >= 2 || !covered) {
      findings.add(
        Finding(
          FindingKind.notAWord,
          i,
          j,
          '「${text.substring(i, j)}」 isn\'t a word the dictionary knows — '
          'a typo, or a name?',
        ),
      );
    }
    i = j;
  }

  // Doubled particle.
  for (var k = 1; k < words.length; k++) {
    final a = words[k - 1];
    final b = words[k];
    if (a.particle &&
        b.particle &&
        a.end == b.start &&
        text.substring(a.start, a.end) == text.substring(b.start, b.end)) {
      findings.add(
        Finding(
          FindingKind.doubledParticle,
          a.start,
          b.end,
          '「${text.substring(a.start, a.end)}」 twice in a row.',
        ),
      );
    }
  }

  // Mixed style: flag whichever style is in the minority.
  final styled = [
    for (final (s, e) in sentences(text)) (s, e, styleOf(text.substring(s, e))),
  ];
  final polite = styled.where((x) => x.$3 == Style.polite).length;
  final plain = styled.where((x) => x.$3 == Style.plain).length;
  if (polite > 0 && plain > 0) {
    final odd = polite >= plain ? Style.plain : Style.polite;
    for (final (s, e, st) in styled) {
      if (st != odd) continue;
      findings.add(
        Finding(
          FindingKind.mixedStyle,
          s,
          e,
          odd == Style.plain
              ? 'Plain style here, but the entry is mostly polite (です/ます).'
              : 'Polite style here, but the entry is mostly plain (だ/る).',
        ),
      );
    }
  }

  findings.sort((a, b) => a.start.compareTo(b.start));
  return findings;
}
