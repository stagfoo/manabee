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
  });

  /// The span of the text the word covers.
  final int start;
  final int end;

  /// Dictionary entries, exact matches first.
  final List<Entry> entries;

  /// How the span was taken back to a dictionary form, if it was
  /// conjugated.
  final Deinflection? form;

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
