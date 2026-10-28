/// Mock JLPT vocabulary tests, made from native sentences.
///
/// The two question types of the test's first two parts:
///
/// * **漢字読み** — a sentence with a word underlined in kanji; pick its
///   reading. Wrong answers are the mistakes the real test sets as traps:
///   a long vowel dropped or added (とうきょう / ときょう), a small っ
///   lost or invented (がっこう / がこう), voicing changed (か / が), a
///   small ゃゅょ made big (きょう / きよう), and another reading of the
///   same kanji (山: やま / さん).
/// * **表記** — the word written in hiragana; pick how it's written.
///   Wrong answers swap in a kanji that shares a part with the right one
///   (休 for 体), move the okurigana (新い, 新らしい), or swap a
///   compound's kanji round.
///
/// No wrong answer is ever a real way of writing or saying the word: each
/// is checked against the dictionary, and a word the dictionary gives two
/// readings for (今日: きょう, こんにち) is never asked about at all,
/// because the sentence would have two right answers.
///
/// The sentences are Tatoeba's, by native speakers, graded by their
/// hardest word (see sentences.dart). Pure Dart apart from the lookups it
/// is handed, so it is tested with a fake dictionary.
library;

import 'dart:math';

import '../models.dart';
import 'kana.dart';
import 'kanji_chain.dart';
import 'scan.dart';
import 'sentences.dart';

enum MockSection {
  /// 漢字読み: kanji shown, pick the reading.
  reading,

  /// 表記: kana shown, pick the kanji.
  writing,
}

/// How many of each, as on the real test's first two parts at N5.
const kMockReadingQuestions = 12;
const kMockWritingQuestions = 8;

class MockQuestion {
  const MockQuestion({
    required this.section,
    required this.sentence,
    required this.start,
    required this.end,
    required this.written,
    required this.kana,
    required this.options,
    required this.answer,
    required this.entry,
  });

  final MockSection section;
  final Sentence sentence;

  /// Where the word sits in the sentence as Tatoeba has it.
  final int start;
  final int end;

  /// The word as written in the sentence (分かりません), and its reading
  /// (わかりません).
  final String written;
  final String kana;

  final List<String> options;

  /// Index of the right one in [options].
  final int answer;

  /// The word in dictionary form, for the review afterwards.
  final Entry entry;

  /// The sentence as the question shows it: as written for a reading
  /// question, with the word in kana for a writing one.
  String get shown => section == MockSection.reading
      ? sentence.japanese
      : sentence.japanese.replaceRange(start, end, kana);

  /// Where the underlined word is in [shown].
  (int, int) get underline => section == MockSection.reading
      ? (start, end)
      : (start, start + kana.length);
}

/// What the kanji data says about one kanji: its readings in hiragana
/// (on and kun, okurigana dropped) and the parts it's drawn from.
class KanjiFacts {
  const KanjiFacts({
    this.readings = const [],
    this.kun = const [],
    this.parts = const [],
    this.grade = 9,
  });

  final List<String> readings;

  /// The kun readings alone — the ones a word with okurigana uses.
  final List<String> kun;
  final List<String> parts;

  /// School grade, 1-6, or 8 for the rest of the jouyou set.
  final int grade;
}

/// The hardest school grade a lookalike may come from at each level. A
/// kanji the learner has never met is no trap: 崇 next to 出 is ruled out
/// at a glance, which makes the question easier than the real one.
const kLookalikeGrade = {'N5': 2, 'N4': 3, 'N3': 4};

/// Readings as KANJIDIC writes them — カ, した, なな.つ, -うえ — made into
/// the hiragana a word's reading would contain: か, した, なな, うえ.
List<String> kanjiReadings(List<String> on, List<String> kun) => {
  for (final r in on) katakanaToHiragana(r).replaceAll('-', ''),
  for (final r in kun) r.replaceAll('-', '').split('.').first,
}.where((r) => r.isNotEmpty).toList();

/// Kanji too simple to be built from two parts, so the parts data says
/// nothing about what they're mistaken for. The pairs the real test leans
/// on, by eye.
const Map<String, String> _lookalikes = {
  '日': '目白田',
  '目': '日自月且',
  '白': '日百自',
  '田': '由申甲日',
  '人': '入八大',
  '入': '人八',
  '八': '人入',
  '大': '太犬天夫丈',
  '太': '大犬',
  '犬': '大太',
  '天': '夫大末',
  '夫': '天失大',
  '土': '士工王',
  '士': '土工',
  '工': '土士',
  '王': '玉主土',
  '千': '干午十',
  '午': '牛千干',
  '牛': '午半',
  '木': '本未末术',
  '本': '木未体',
  '未': '末木',
  '末': '未木',
  '力': '刀万方九',
  '刀': '力刃',
  '万': '方力',
  '方': '万力',
  '口': '日回',
  '子': '字学了',
  '右': '左石古',
  '左': '右在',
  '石': '右古',
  '古': '右舌',
  '円': '内用丹',
  '内': '円肉',
  '川': '州三',
  '小': '少水',
  '少': '小',
  '手': '毛半',
  '毛': '手',
  '生': '先午牛',
  '先': '生光',
  '上': '止土',
  '下': '不卜',
  '中': '申虫',
  '山': '出止',
  '水': '氷永木',
  '火': '大灭',
  '月': '用目丹',
  '金': '全会',
  '女': '安如',
  '男': '田思',
  '年': '午牛',
  '車': '東事',
  '東': '車束',
  '西': '酉四',
  '北': '比化',
  '南': '用',
  '母': '毎',
  '毎': '母海',
  '長': '辰',
  '高': '亭京',
  '名': '各右',
  '外': '夕',
  '間': '問聞門開',
  '門': '間問',
  '何': '可河',
  '前': '首',
  '後': '彼',
  '今': '令会',
  '半': '平羊',
  '百': '白',
};

/// The kanji facts the tests need, from the Kanji Chain data: each
/// kanji's readings and parts. Only kanji built from two parts are in it,
/// so the simplest ones (山, 日) rely on the hand-made lookalikes.
Map<String, KanjiFacts> mockKanjiFacts(Iterable<Combo> combos) => {
  for (final c in combos)
    c.kanji: KanjiFacts(
      readings: kanjiReadings(c.on, c.kun),
      kun: kanjiReadings(const [], c.kun),
      parts: {c.a, c.b}.toList(),
      grade: c.grade,
    ),
};

/// Kanji that look like [kanji]: those sharing one of its parts, then the
/// hand-made lookalikes. [facts] maps each kanji to its parts.
List<String> lookalikesOf(
  String kanji,
  Map<String, KanjiFacts> facts,
  Map<String, List<String>> byPart, {
  int maxGrade = 9,
}) {
  final out = <String>{};
  for (final p in facts[kanji]?.parts ?? const <String>[]) {
    out.addAll(
      (byPart[p] ?? const []).where((k) => (facts[k]?.grade ?? 9) <= maxGrade),
    );
  }
  out.addAll((_lookalikes[kanji] ?? '').split('').where((s) => s.isNotEmpty));
  out.remove(kanji);
  return out.toList();
}

// ------------------------------------------------------------- readings

const _voiced = {
  'か': 'が',
  'き': 'ぎ',
  'く': 'ぐ',
  'け': 'げ',
  'こ': 'ご',
  'さ': 'ざ',
  'し': 'じ',
  'す': 'ず',
  'せ': 'ぜ',
  'そ': 'ぞ',
  'た': 'だ',
  'ち': 'ぢ',
  'つ': 'づ',
  'て': 'で',
  'と': 'ど',
  'は': 'ば',
  'ひ': 'び',
  'ふ': 'ぶ',
  'へ': 'べ',
  'ほ': 'ぼ',
};
final _unvoiced = {for (final e in _voiced.entries) e.value: e.key};
const _halfVoiced = {'は': 'ぱ', 'ひ': 'ぴ', 'ふ': 'ぷ', 'へ': 'ぺ', 'ほ': 'ぽ'};
const _smallY = {'ゃ': 'や', 'ゅ': 'ゆ', 'ょ': 'よ'};
const _bigY = {'や': 'ゃ', 'ゆ': 'ゅ', 'よ': 'ょ'};

/// Kana a small っ can stand before: k, s, t and p sounds.
bool _geminable(String k) => 'かきくけこさしすせそたちつてとぱぴぷぺぽ'.contains(k);

/// The vowel a kana ends on, from its romaji.
String _vowel(String kana) {
  final r = toRomaji(kana);
  return r.isEmpty ? '' : r[r.length - 1];
}

/// Whether [s] could be a reading at all: nothing starts on a small kana
/// or ん, っ only before a k/s/t/p sound, and ゃゅょ only after an i-row
/// kana.
bool wellFormedKana(String s) {
  final k = s.split('');
  if (k.isEmpty) return false;
  if ('ゃゅょっんー'.contains(k.first)) return false;
  for (var i = 0; i < k.length; i++) {
    if (k[i] == 'っ' && (i + 1 >= k.length || !_geminable(k[i + 1]))) {
      return false;
    }
    if (_smallY.containsKey(k[i]) &&
        (i == 0 || _vowel(k[i - 1]) != 'i' || _smallY.containsKey(k[i - 1]))) {
      return false;
    }
  }
  return true;
}

/// The trap readings for a word whose kanji part reads [kanjiKana] and
/// whose kana tail is [tail], each tagged with the kind of mistake it is.
/// Only the kanji part is changed: the okurigana is printed on the page.
List<(String, String)> readingTraps(String kanjiKana, String tail) {
  final k = kanjiKana.split('');
  final out = <(String, String)>[];
  void add(List<String> next, String why) => out.add((next.join() + tail, why));

  for (var i = 0; i < k.length; i++) {
    final c = k[i];
    final next = i + 1 < k.length ? k[i + 1] : null;
    final v = _vowel(c);
    // A long vowel dropped: とう → と, せい → せ, くう → く.
    if (next != null &&
        ((next == 'う' && (v == 'o' || v == 'u')) ||
            (next == 'い' && v == 'e'))) {
      add([...k.sublist(0, i + 1), ...k.sublist(i + 2)], 'long');
    }
    // A long vowel added: こ → こう, せ → せい. Not after a bare vowel
    // (りょこうう), before ん or っ (でいんしゃ), or an い on the end
    // (なまえい) — none of those is a mistake anyone makes.
    if (next != 'う' &&
        next != 'い' &&
        next != 'ん' &&
        next != 'っ' &&
        !'あいうえおっんー'.contains(c)) {
      if (v == 'o' || (v == 'u' && next != null)) {
        add([...k.sublist(0, i + 1), 'う', ...k.sublist(i + 1)], 'long');
      } else if (v == 'e' && next != null) {
        add([...k.sublist(0, i + 1), 'い', ...k.sublist(i + 1)], 'long');
      }
    }
    // A small っ dropped, or one invented.
    if (c == 'っ') add([...k.sublist(0, i), ...k.sublist(i + 1)], 'tsu');
    if (i > 0 && _geminable(c) && !'っん'.contains(k[i - 1])) {
      add([...k.sublist(0, i), 'っ', ...k.sublist(i)], 'tsu');
    }
    // Voicing changed: か ↔ が, は → ば / ぱ.
    final flipped = _voiced[c] ?? _unvoiced[c] ?? _halfVoiced[c];
    if (flipped != null) {
      add([...k.sublist(0, i), flipped, ...k.sublist(i + 1)], 'voice');
    }
    // A small ゃゅょ made big, or a big one small.
    final size = _smallY[c] ?? (i > 0 ? _bigY[c] : null);
    if (size != null) {
      add([...k.sublist(0, i), size, ...k.sublist(i + 1)], 'small');
    }
  }
  return out;
}

/// [kanjiKana] with one kanji's reading swapped for another of its
/// readings — 山 read さん, 生 read なま — for a word written [kanji].
/// Only where the split is certain: the first kanji's reading at the
/// start, or the last kanji's at the end.
///
/// A word with okurigana (聞く, 取る) gets only kun readings: an on
/// reading in front of okurigana — ぶんく — is ruled out at a glance.
List<String> otherReadingTraps(
  String kanji,
  String kanjiKana,
  Map<String, KanjiFacts> facts, {
  bool okurigana = false,
}) {
  final chars = kanji.split('');
  final out = <String>{};
  List<String> of(String k) =>
      (okurigana ? facts[k]?.kun : facts[k]?.readings) ?? const <String>[];
  final first = of(chars.first);
  for (final r in first) {
    if (!kanjiKana.startsWith(r)) continue;
    final rest = kanjiKana.substring(r.length);
    if (chars.length == 1 && rest.isNotEmpty) continue;
    for (final other in first) {
      if (other != r && _near(other, r)) out.add(other + rest);
    }
  }
  if (chars.length > 1) {
    final last = of(chars.last);
    for (final r in last) {
      if (!kanjiKana.endsWith(r)) continue;
      final head = kanjiKana.substring(0, kanjiKana.length - r.length);
      if (head.isEmpty) continue;
      for (final other in last) {
        if (other != r && _near(other, r)) out.add(head + other);
      }
    }
  }
  out.remove(kanjiKana);
  return out.toList();
}

/// A swapped-in reading about as long as the one it replaces: みょう for
/// な (名前 → みょうまえ) passes, ことわり for り (料理 → りょうことわり)
/// is a reading of 理 nobody would pick.
bool _near(String other, String original) =>
    (other.length - original.length).abs() <= 2;

// -------------------------------------------------------------- writing

/// One way of mis-writing a word: the kanji part replaced with [kanji],
/// [add] kana put before the okurigana and [drop] of its kana taken off.
class WritingTrap {
  const WritingTrap(this.kanji, this.why, {this.add = '', this.drop = 0});

  final String kanji;
  final String add;
  final int drop;
  final String why;

  String apply(String tail) =>
      kanji + add + (drop <= tail.length ? tail.substring(drop) : '');
}

/// Wrong ways to write a word whose kanji part is [kanji], reading
/// [kanjiKana], with okurigana [okurigana] in dictionary form.
List<WritingTrap> writingTraps(
  String kanji,
  String kanjiKana,
  String okurigana,
  Map<String, KanjiFacts> facts,
  Map<String, List<String>> byPart, {
  int maxGrade = 9,
}) {
  final chars = kanji.split('');
  final out = <WritingTrap>[];
  for (var i = 0; i < chars.length; i++) {
    for (final look in lookalikesOf(
      chars[i],
      facts,
      byPart,
      maxGrade: maxGrade,
    )) {
      final next = [...chars]..[i] = look;
      out.add(WritingTrap(next.join(), 'lookalike'));
    }
  }
  if (okurigana.isNotEmpty) {
    // 新しい → 新い: the okurigana cut short.
    if (okurigana.length > 1) {
      out.add(WritingTrap(kanji, 'okurigana', drop: 1));
    }
    // 新しい → 新らしい: the kanji's last kana written out as well.
    if (kanjiKana.length > 1) {
      out.add(
        WritingTrap(kanji, 'okurigana', add: kanjiKana[kanjiKana.length - 1]),
      );
    }
  }
  if (chars.length == 2 && chars[0] != chars[1]) {
    out.add(WritingTrap(chars.reversed.join(), 'order'));
  }
  return out;
}

// ------------------------------------------------------------- building

/// A word written as kanji followed by kana only (学生, 分かる, 新しい) —
/// the shape both question types can be made from — split into the two.
(String, String)? splitWritten(String word) {
  final runes = word.runes.toList();
  var i = 0;
  while (i < runes.length && isKanji(runes[i])) {
    i++;
  }
  if (i == 0) return null;
  if (runes.sublist(i).any((c) => !isHiragana(c))) return null;
  return (
    String.fromCharCodes(runes.sublist(0, i)),
    String.fromCharCodes(runes.sublist(i)),
  );
}

typedef Lookup = Future<List<Entry>> Function(String);

/// Makes a test at [level] from [sentences].
///
/// [words] holds the JLPT words, keyed "word|reading", that may be asked
/// about — the level's own first, then easier ones once those run out.
/// Sentences come from [level] and easier, so the sentence is never
/// harder than the word.
Future<List<MockQuestion>> buildMockTest({
  required String level,
  required List<Sentence> sentences,
  required Map<String, Entry> words,
  required Map<String, KanjiFacts> facts,
  required Lookup lookup,
  Random? random,
  int readingCount = kMockReadingQuestions,
  int writingCount = kMockWritingQuestions,
}) async {
  final rnd = random ?? Random();
  final levelIndex = kSentenceLevels.indexOf(level);
  final pool = sentences.where((s) {
    final i = kSentenceLevels.indexOf(s.level);
    return i >= 0 && i <= levelIndex;
  }).toList()..shuffle(rnd);
  // The level's own sentences first: an N4 test is mostly N4 words.
  pool.sort(
    (a, b) => (b.level == level ? 1 : 0).compareTo(a.level == level ? 1 : 0),
  );

  final byPart = <String, List<String>>{};
  for (final MapEntry(key: k, value: f) in facts.entries) {
    for (final p in f.parts) {
      byPart.putIfAbsent(p, () => []).add(k);
    }
  }

  final reading = <MockQuestion>[];
  final writing = <MockQuestion>[];
  final used = <String>{};

  for (final s in pool) {
    if (reading.length >= readingCount && writing.length >= writingCount) {
      break;
    }
    final wantReading = reading.length < readingCount;
    final section =
        wantReading && (rnd.nextBool() || writing.length >= writingCount)
        ? MockSection.reading
        : MockSection.writing;
    final candidates =
        [
          for (final key in s.words)
            if (words[key] case final e? when !used.contains(key)) e,
        ]..sort(
          (a, b) =>
              (b.jlpt == level ? 1 : 0).compareTo(a.jlpt == level ? 1 : 0),
        );
    for (final e in candidates) {
      final q = await _question(
        s,
        e,
        section,
        facts,
        byPart,
        lookup,
        rnd,
        kLookalikeGrade[level] ?? 9,
      );
      if (q == null) continue;
      used.add('${e.word}|${e.reading}');
      (section == MockSection.reading ? reading : writing).add(q);
      break;
    }
  }
  return [...reading, ...writing];
}

Future<MockQuestion?> _question(
  Sentence s,
  Entry e,
  MockSection section,
  Map<String, KanjiFacts> facts,
  Map<String, List<String>> byPart,
  Lookup lookup,
  Random rnd,
  int maxGrade,
) async {
  final split = splitWritten(e.word);
  if (split == null) return null;
  final (kanji, okurigana) = split;
  final reading = katakanaToHiragana(e.reading);
  if (!reading.endsWith(okurigana)) return null;
  final kanjiKana = reading.substring(0, reading.length - okurigana.length);
  if (kanjiKana.isEmpty) return null;

  // The word as the sentence writes it, conjugation and all. The kanji
  // must stand alone — 山 inside 富士山 is a different word.
  final text = s.japanese;
  final start = text.indexOf(kanji);
  if (start < 0) return null;
  final runes = text.split('');
  if (start > 0 && isKanji(runes[start - 1].runes.first)) return null;
  final hit = await scanWord(text, start, lookup);
  if (hit == null ||
      !hit.entries.any((x) => x.word == e.word && x.reading == e.reading)) {
    return null;
  }
  final written = text.substring(start, hit.end);
  final tail = written.substring(kanji.length);
  if (tail.runes.any((c) => !isHiragana(c))) return null;

  // Two readings for one spelling (今日, 一日, 上手) means two right
  // answers: not asked.
  final spellings = await lookup(e.word);
  final validReadings = {
    for (final x in spellings)
      if (x.word == e.word) katakanaToHiragana(x.reading),
  };
  if (validReadings.length > 1) return null;

  final kana = kanjiKana + tail;
  final List<String> wrong;
  final String right;
  if (section == MockSection.reading) {
    right = kana;
    wrong = _pickReadingTraps(
      kanji,
      kanjiKana,
      tail,
      facts,
      validReadings,
      okurigana,
      rnd,
    );
  } else {
    right = written;
    wrong = await _pickWritingTraps(
      kanji,
      kanjiKana,
      okurigana,
      tail,
      reading,
      facts,
      byPart,
      lookup,
      rnd,
      maxGrade,
    );
  }
  if (wrong.length < 3) return null;
  final options = [right, ...wrong.take(3)]..shuffle(rnd);
  return MockQuestion(
    section: section,
    sentence: s,
    start: start,
    end: start + written.length,
    written: written,
    kana: kana,
    options: options,
    answer: options.indexOf(right),
    entry: e,
  );
}

List<String> _pickReadingTraps(
  String kanji,
  String kanjiKana,
  String tail,
  Map<String, KanjiFacts> facts,
  Set<String> validReadings,
  String okurigana,
  Random rnd,
) {
  final right = kanjiKana + tail;
  bool ok(String s) =>
      s != right &&
      wellFormedKana(s) &&
      // Not any real reading of the word, in any form.
      !validReadings.any((v) {
        final stem = v.endsWith(okurigana)
            ? v.substring(0, v.length - okurigana.length)
            : v;
        return stem + tail == s;
      });

  final byKind = <String, List<String>>{};
  for (final r in otherReadingTraps(
    kanji,
    kanjiKana,
    facts,
    okurigana: okurigana.isNotEmpty,
  )) {
    if (ok(r + tail)) byKind.putIfAbsent('other', () => []).add(r + tail);
  }
  for (final (s, why) in readingTraps(kanjiKana, tail)) {
    if (ok(s)) byKind.putIfAbsent(why, () => []).add(s);
  }
  return _spread(byKind, rnd, first: 'other');
}

Future<List<String>> _pickWritingTraps(
  String kanji,
  String kanjiKana,
  String okurigana,
  String tail,
  String reading,
  Map<String, KanjiFacts> facts,
  Map<String, List<String>> byPart,
  Lookup lookup,
  Random rnd,
  int maxGrade,
) async {
  final byKind = <String, List<String>>{};
  final traps = writingTraps(
    kanji,
    kanjiKana,
    okurigana,
    facts,
    byPart,
    maxGrade: maxGrade,
  )..shuffle(rnd);
  final seen = <String>{kanji + tail};
  var checked = 0;
  for (final t in traps) {
    final shown = t.apply(tail);
    if (!seen.add(shown)) continue;
    if ((byKind[t.why]?.length ?? 0) >= 3) continue;
    // A real way of writing this word is never offered as a wrong one:
    // 分る is in the dictionary as 分かる, read わかる.
    final asWord = t.apply(okurigana);
    if (checked++ > 24) break;
    final hits = await lookup(asWord);
    if (hits.any((x) => katakanaToHiragana(x.reading) == reading)) continue;
    byKind.putIfAbsent(t.why, () => []).add(shown);
  }
  return _spread(byKind, rnd, first: 'lookalike');
}

/// Three wrong answers, as varied as possible: one of [first]'s kind when
/// there is one, then a different kind of mistake each time round.
List<String> _spread(
  Map<String, List<String>> byKind,
  Random rnd, {
  required String first,
}) {
  final pools = {
    for (final e in byKind.entries) e.key: ([...e.value]..shuffle(rnd)),
  };
  final out = <String>[];
  final f = pools[first];
  if (f != null && f.isNotEmpty) out.add(f.removeAt(0));
  final kinds = pools.keys.toList()..shuffle(rnd);
  var added = true;
  while (out.length < 3 && added) {
    added = false;
    for (final k in kinds) {
      final p = pools[k]!;
      while (p.isNotEmpty && out.contains(p.first)) {
        p.removeAt(0);
      }
      if (p.isEmpty || out.length >= 3) continue;
      out.add(p.removeAt(0));
      added = true;
    }
  }
  return out;
}
