/// Finding the word that starts at a character — tap-to-look-up, the way
/// Yomichan reads a page.
///
/// Splitting a bubble into words up front fails on what manga is mostly
/// written in: hiragana has no boundaries to see, so ここいえがいっぱいある
/// was one "word". Instead the reader taps where a word starts and this
/// finds the longest stretch from there that the dictionary knows — as is,
/// or once conjugation and a trailing particle are undone (core/deinflect).
///
/// The dictionary is passed in, so this tests against a fake one.
library;

import 'deinflect.dart';
import 'kana.dart';
import 'ocr_text.dart';
import '../models.dart';

/// The longest a word is looked for. Long enough for いってきます or
/// 食べられなかった, short enough to keep the lookups few.
const int kMaxScan = 10;

class ScanResult {
  const ScanResult({
    required this.start,
    required this.end,
    required this.entries,
    this.form,
    this.corrected,
  });

  /// The span of the text the word covers.
  final int start;
  final int end;

  /// Dictionary entries, exact matches first.
  final List<Entry> entries;

  /// How the span was taken back to a dictionary form, if it was
  /// conjugated.
  final Deinflection? form;

  /// When the span only made a word with one character read differently
  /// (いっばい as いっぱい — OCR confusing ば and ぱ), the corrected text.
  final String? corrected;

  String surfaceOf(String text) => text.substring(start, end);
}

/// Whether [e] is exactly [q], not just a near match — allowing the same
/// spellings of ー the dictionary tries (とーちゃん is とうちゃん).
bool isExactEntry(Entry e, String q) {
  for (final form in [q, ...spellingVariants(q)]) {
    if (e.word == form ||
        e.reading == form ||
        e.reading == katakanaToHiragana(form)) {
      return true;
    }
  }
  return false;
}

/// Other spellings worth trying when [q] isn't in the dictionary as
/// written: ー after hiragana as the vowel it stands for (とーちゃん →
/// とうちゃん; え-row and お-row also as い / う, the usual long forms).
List<String> spellingVariants(String q) {
  final runes = q.runes.toList();
  final at = <int>[
    for (var i = 1; i < runes.length; i++)
      if (runes[i] == 0x30FC && isHiragana(runes[i - 1])) i,
  ];
  if (at.isEmpty) return const [];
  var variants = <List<int>>[runes];
  for (final i in at) {
    final vowels = _longVowels(runes[i - 1]);
    variants = [
      for (final v in variants)
        for (final vowel in vowels)
          [...v.sublist(0, i), vowel, ...v.sublist(i + 1)],
    ];
  }
  return [for (final v in variants) String.fromCharCodes(v)];
}

List<int> _longVowels(int kana) {
  final r = toRomaji(String.fromCharCode(kana));
  if (r.isEmpty) return const [];
  return switch (r[r.length - 1]) {
    'a' => [0x3042],
    'i' => [0x3044],
    'u' => [0x3046],
    'e' => [0x3044, 0x3048], // せんせい, ねえ
    'o' => [0x3046, 0x304A], // とうちゃん, おおきい
    _ => const [],
  };
}

bool _wordChar(int c) => isJapanese(c) || c == 0x30FC || c == 0x3005;

/// The stretch of word characters starting at [start], up to [kMaxScan]:
/// spaces, punctuation and Latin end it.
String scanWindow(String text, int start) {
  final runes = text.runes.toList();
  final out = <int>[];
  for (var i = start; i < runes.length && out.length < kMaxScan; i++) {
    if (!_wordChar(runes[i])) break;
    out.add(runes[i]);
  }
  return String.fromCharCodes(out);
}

/// The word at [start] in [text] (a UTF-16 index; Japanese is all in the
/// basic plane, so characters and indices line up).
///
/// Every prefix of the window is looked up as is — in parallel, they're
/// independent — and the longest exact match wins. Then longer prefixes
/// are tried deinflected, longest first, so あるな finds ある (+ な) over
/// stopping at あ, and あそべるよ finds 遊ぶ. Deinflection lookups are
/// capped at [maxDeinflected]: each one is a request.
Future<ScanResult?> scanWord(
  String text,
  int start,
  Future<List<Entry>> Function(String) lookup, {
  int maxDeinflected = 20,
  int maxCorrections = 40,
}) async {
  final window = scanWindow(text, start);
  if (window.isEmpty) return null;

  final prefixes = [
    for (var n = window.length; n >= 1; n--) window.substring(0, n),
  ];
  final asIs = await Future.wait(
    prefixes.map((p) => lookup(p).catchError((_) => <Entry>[])),
  );

  var bestExact = -1;
  for (var k = 0; k < prefixes.length; k++) {
    if (asIs[k].any((e) => isExactEntry(e, prefixes[k]))) {
      bestExact = k;
      break;
    }
  }
  final exactLength = bestExact < 0 ? 0 : prefixes[bestExact].length;

  var budget = maxDeinflected;
  for (final p in prefixes) {
    if (p.length <= exactLength || p.length < 2) break;
    for (final d in deinflect(p)) {
      if (budget-- <= 0) break;
      final found = await lookup(d.term).catchError((_) => <Entry>[]);
      final exact = found.where((e) => isExactEntry(e, d.term)).toList();
      if (exact.isNotEmpty) {
        return ScanResult(
          start: start,
          end: start + d.wordOnPage(p).length,
          entries: [...exact, ...found.where((e) => !exact.contains(e))],
          form: d,
        );
      }
    }
    if (budget <= 0) break;
  }

  // Still nothing longer: a span that's a word once one character is read
  // as what OCR confuses it with — いっばい is いっぱい.
  var corrections = maxCorrections;
  for (final p in prefixes) {
    // Three characters at least: a two-character swap lands on some real
    // word far too easily (がが would become 加賀), hiding a real mistake.
    if (p.length <= exactLength || p.length < 3 || corrections <= 0) break;
    for (final v in ocrVariants(p)) {
      if (corrections-- <= 0) break;
      final found = await lookup(v).catchError((_) => <Entry>[]);
      final exact = found.where((e) => isExactEntry(e, v)).toList();
      if (exact.isNotEmpty) {
        return ScanResult(
          start: start,
          end: start + p.length,
          entries: [...exact, ...found.where((e) => !exact.contains(e))],
          corrected: v,
        );
      }
    }
  }

  if (bestExact >= 0) {
    final p = prefixes[bestExact];
    final found = asIs[bestExact];
    final exact = found.where((e) => isExactEntry(e, p)).toList();
    return ScanResult(
      start: start,
      end: start + p.length,
      entries: [...exact, ...found.where((e) => !exact.contains(e))],
    );
  }
  return null;
}

/// One word of a sentence, as [segmentSentence] splits it.
class WordSpan {
  const WordSpan(this.start, this.end, {this.particle = false, this.corrected});

  final int start;
  final int end;

  /// A grammatical particle (が, を, に…) — coloured apart from the words
  /// it joins, so the sentence's structure shows.
  final bool particle;

  /// Set when the span is only a word with one character corrected — see
  /// [ScanResult.corrected].
  final String? corrected;

  @override
  bool operator ==(Object other) =>
      other is WordSpan &&
      other.start == start &&
      other.end == end &&
      other.particle == particle;

  @override
  int get hashCode => Object.hash(start, end, particle);

  @override
  String toString() => '[$start,$end${particle ? ' p' : ''})';
}

/// Particles common enough in speech to split off ahead of a longer
/// dictionary match. Longest first.
const _particleForms = [
  'から',
  'まで',
  'より',
  'って',
  'けど',
  'ので',
  'のに',
  'でも',
  'しか',
  'が',
  'は',
  'を',
  'に',
  'で',
  'と',
  'の',
  'も',
  'へ',
  'や',
  'か',
  'ね',
  'よ',
  'な',
  'わ',
  'ぞ',
  'さ',
  'し',
];

/// The copula and its forms, which start like particles (で, じゃ) but
/// are words of their own: 学生です is 学生 + です, not 学生 + で + す.
const _copulas = ['です', 'でし', 'でしょ', 'だ', 'だっ', 'じゃ', 'では'];

bool _isParticle(Entry e) =>
    !containsKanji(e.word) &&
    e.senses.isNotEmpty &&
    e.senses.first.partsOfSpeech.any((p) => p.contains('particle'));

/// The sentence as words, left to right, each the longest dictionary match
/// from where the last ended (see [scanWord]) — except that right after a
/// word, a particle is taken as a particle: in 人がいっぱい the が is the
/// subject marker, though がい (害, "harm") is a longer match.
///
/// Characters no word covers (punctuation, a misread character) are left
/// out; spans don't overlap and come in order.
Future<List<WordSpan>> segmentSentence(
  String text,
  Future<List<Entry>> Function(String) lookup,
) async {
  final out = <WordSpan>[];
  var i = 0;
  var afterWord = false;
  while (i < text.length) {
    if (scanWindow(text, i).isEmpty) {
      i++;
      afterWord = false;
      continue;
    }
    if (afterWord && !_copulas.any((c) => text.startsWith(c, i))) {
      final p = await _particleAt(text, i, lookup);
      if (p != null) {
        out.add(WordSpan(i, i + p, particle: true));
        i += p;
        // A word can follow a particle directly (がいっぱい).
        afterWord = false;
        continue;
      }
    }
    final r = await scanWord(text, i, lookup);
    if (r == null) {
      i++;
      afterWord = false;
      continue;
    }
    // 今日は and 今晩は are greetings in the dictionary (こんにちは,
    // こんばんは), so the longest match swallows the topic particle; in
    // running text they're nearly always 今日 + は. Split when what's
    // before the は is a word by itself.
    final surface = r.surfaceOf(text);
    if (r.form == null && surface.length > 1 && surface.endsWith('は')) {
      final head = surface.substring(0, surface.length - 1);
      final entries = await lookup(head);
      if (entries.any((e) => isExactEntry(e, head))) {
        out.add(WordSpan(r.start, r.end - 1));
        i = r.end - 1;
        afterWord = true;
        continue;
      }
    }
    final particle =
        r.form == null &&
        _particleForms.contains(r.surfaceOf(text)) &&
        r.entries.isNotEmpty &&
        _isParticle(r.entries.first);
    out.add(
      WordSpan(r.start, r.end, particle: particle, corrected: r.corrected),
    );
    i = r.end;
    afterWord = !particle;
  }
  return out;
}

/// The length of a particle starting at [i], if one does.
Future<int?> _particleAt(
  String text,
  int i,
  Future<List<Entry>> Function(String) lookup,
) async {
  for (final p in _particleForms) {
    if (!text.startsWith(p, i)) continue;
    final entries = await lookup(p);
    if (entries.any((e) => isExactEntry(e, p) && _isParticle(e))) {
      return p.length;
    }
  }
  return null;
}

/// Particles that can follow a sentence's last word: 行くよ, 居るな, 何か.
const _sentenceEndParticles = [
  'よね',
  'ねえ',
  'かな',
  'よ',
  'ね',
  'な',
  'か',
  'わ',
  'ぞ',
  'ぜ',
  'さ',
  'の',
];

final RegExp _sentenceBreak = RegExp(r'[。！？!?\n]');

/// Whether a word ending at [end] is the last in its sentence: only
/// sentence-ending particles, punctuation or spaces follow it before the
/// sentence ends.
bool endsSentence(String text, int end) {
  if (end > text.length) return false;
  var rest = text.substring(end);
  final stop = rest.indexOf(_sentenceBreak);
  if (stop >= 0) rest = rest.substring(0, stop);
  rest = rest.replaceAll(RegExp(r'[\s、,…・〜～ー!！?？」』)）]'), '');
  var stripped = true;
  while (stripped && rest.isNotEmpty) {
    stripped = false;
    for (final p in _sentenceEndParticles) {
      if (rest.startsWith(p)) {
        rest = rest.substring(p.length);
        stripped = true;
        break;
      }
    }
  }
  return rest.isEmpty;
}

/// [entries] with verbs first, then い-adjectives, then the rest, each
/// group in its original order — for the last word of a sentence, which
/// in Japanese is nearly always the verb (or an adjective): かえる at the
/// end of a sentence is 帰る before 蛙. Sorted, not filtered: nothing is
/// lost if the guess is wrong.
List<Entry> predicatesFirst(List<Entry> entries) {
  int rank(Entry e) {
    final pos = e.senses.isEmpty
        ? const <String>[]
        : e.senses.first.partsOfSpeech;
    // Auxiliaries (the はる of 行きはる) are tagged as verbs too, but are
    // never the word someone tapped.
    if (pos.any((p) => p.contains('auxiliary'))) return 2;
    if (pos.any((p) => p.contains('verb') && !p.contains('adverb'))) return 0;
    if (pos.any((p) => p.contains('adjective (keiyoushi)'))) return 1;
    return 2;
  }

  final indexed = [for (var i = 0; i < entries.length; i++) (i, entries[i])];
  indexed.sort((a, b) {
    final r = rank(a.$2).compareTo(rank(b.$2));
    return r != 0 ? r : a.$1.compareTo(b.$1);
  });
  return [for (final e in indexed) e.$2];
}
