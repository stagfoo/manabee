/// Sentences to shadow, from Tatoeba.
///
/// Only sentences written by native speakers, graded at build time
/// (tool/grade_sentences.dart) by the JLPT level of their hardest word,
/// N5 to N3, with the dictionary form of every word recorded — so the
/// sentences for a focus word can be found: 食べる is in 朝ご飯を食べました.
///
/// Tatoeba sentences are CC BY 2.0 FR: each keeps its id and author, and
/// both are shown beside it.
///
/// Pure Dart: tested without Flutter.
library;

import '../models.dart';
import 'kana.dart';

const kSentenceLevels = ['N5', 'N4', 'N3'];

class Sentence {
  const Sentence({
    required this.id,
    required this.level,
    required this.japanese,
    required this.english,
    required this.words,
    required this.author,
  });

  /// Tatoeba's sentence id.
  final String id;
  final String level;
  final String japanese;
  final String english;

  /// Its words by dictionary form, "word|reading".
  final List<String> words;
  final String author;

  /// The id its speaking schedule is kept under.
  String get key => 'tatoeba:$id';

  String get source => 'tatoeba.org #$id · $author · CC BY 2.0 FR';
}

/// The bundled sentences file: id, level, Japanese, English, words, author.
List<Sentence> parseSentences(String tsv) => [
  for (final line in tsv.split('\n'))
    if (line.trim().isNotEmpty)
      if (line.split('\t') case [
        final id,
        final level,
        final jp,
        final en,
        final words,
        final author,
      ])
        Sentence(
          id: id,
          level: level,
          japanese: jp,
          english: en,
          words: words.isEmpty ? const [] : words.split(','),
          author: author,
        ),
];

/// What of [e] must be visible in a sentence that uses it: the kanji of a
/// kanji word (食 of 食べる, 勉強), the unchanging start of a kana word
/// (あそ of あそぶ). A recorded word whose spelling isn't on the page is a
/// segmenter's guess (いって as 言う rather than 行く), not to be trusted.
String _visible(Entry e) {
  final w = e.word;
  if (containsKanji(w)) {
    final end = w.runes.toList().lastIndexWhere(isKanji);
    return String.fromCharCodes(w.runes.take(end + 1));
  }
  final r = e.reading.isEmpty ? w : e.reading;
  return r.length > 2 ? r.substring(0, r.length - 1) : r;
}

/// Whether [s] uses the word [e].
bool usesWord(Sentence s, Entry e) {
  final reading = e.reading.isEmpty ? e.word : e.reading;
  final listed = s.words.any((k) {
    final [word, r] = k.split('|');
    return r == reading &&
        (word == e.word || !containsKanji(word) || !e.hasKanji);
  });
  return listed && s.japanese.contains(_visible(e));
}

/// Sentences for [focus]: up to [perWord] for each word, easiest first
/// (lowest level, then shortest), each sentence once.
List<Sentence> sentencesFor(
  List<Sentence> all,
  List<Entry> focus, {
  int perWord = 3,
}) {
  int rank(Sentence s) =>
      kSentenceLevels.indexOf(s.level) * 100 + s.japanese.length;
  final out = <Sentence>[];
  final seen = <String>{};
  for (final e in focus) {
    final found = all.where((s) => usesWord(s, e)).toList()
      ..sort((a, b) => rank(a).compareTo(rank(b)));
    for (final s in found.take(perWord)) {
      if (seen.add(s.id)) out.add(s);
    }
  }
  return out;
}

/// The sentences at [level], shortest first: a level starts with what can
/// be said in one breath.
List<Sentence> sentencesAt(List<Sentence> all, String level) =>
    all.where((s) => s.level == level).toList()
      ..sort((a, b) => a.japanese.length.compareTo(b.japanese.length));

/// Where in [s] the word [e] appears, for highlighting: the visible part.
(int, int)? wordSpanIn(Sentence s, Entry e) {
  final v = _visible(e);
  final i = s.japanese.indexOf(v);
  return i < 0 ? null : (i, i + v.length);
}
