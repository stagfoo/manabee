// How often each dictionary word is used in everyday Japanese, counted
// over every Tatoeba sentence written by a native speaker (CC BY 2.0 FR)
// — mostly conversation: what people say, more than what newspapers
// print.
//
//     python3 tool/build_sentences.py      # writes build/sentences/native.txt
//     flutter test tool/count_frequency.dart
//
// Each sentence is segmented with the reader's own segmenter, so 食べました
// counts for 食べる. Writes tool/data/spoken_frequency.tsv — word,
// reading, count, most used first — which tool/build_dictionary.py turns
// into each entry's spoken rank.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:manabee/core/kana.dart';
import 'package:manabee/core/scan.dart';
import 'package:manabee/models.dart';
import 'package:manabee/services/dictionary.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Tatoeba's stock characters and places — トム and メアリー are in
/// thousands of its sentences, which says how Tatoeba is written, not how
/// Japanese is spoken.
const _names = {'トム', 'メアリー', 'メアリ', 'ミアリー', 'ジョン', 'ボストン', 'ケン'};

void main() {
  test('count spoken frequency', () async {
    sqfliteFfiInit();
    final db = await databaseFactoryFfi.openDatabase(
      // DICT: a dictionary built without spoken frequency, so the count
      // never feeds on itself. Defaults to the app's.
      File(Platform.environment['DICT'] ?? 'assets/dict/jmdict.db')
          .absolute
          .path,
      options: OpenDatabaseOptions(readOnly: true),
    );
    final dict = await LocalDictionary.fromDatabase(db);
    // The same few thousand lookups over and over: remember them.
    final cache = <String, Future<List<Entry>>>{};
    Future<List<Entry>> lookup(String q) => cache[q] ??= dict.lookup(q);

    final lines = File('build/sentences/native.txt').readAsLinesSync();
    final counts = <String, int>{};
    var seen = 0;
    for (final text in lines) {
      if (++seen % 10000 == 0) stderr.writeln('  $seen / ${lines.length}');
      final spans = await segmentSentence(text, lookup);
      for (final s in spans) {
        if (s.corrected != null) continue;
        final surface = text.substring(s.start, s.end);
        if (!surface.runes.any(isJapanese)) continue;
        // A lone katakana (ト, ン) or a long-vowel mark is a piece of a
        // name the segmenter split, not a word.
        if (surface.runes.length == 1 &&
            (isKatakana(surface.runes.first) || surface == 'ー')) {
          continue;
        }
        if (_names.contains(surface)) continue;
        final r = await scanWord(text, s.start, lookup);
        if (r == null || r.entries.isEmpty || r.end != s.end) continue;
        // Written in hiragana, the word can't be told from its homophones
        // here (きる: 着る, 切る, 斬る…) — counted as the kana, and
        // tool/build_dictionary.py gives it to the likeliest entry.
        final dictionaryForm = r.form?.term ?? surface;
        final e = r.entries.first;
        final key = surface.runes.every(isHiragana)
            ? '$dictionaryForm\t$dictionaryForm'
            : '${e.word}\t${e.reading}';
        counts[key] = (counts[key] ?? 0) + 1;
      }
    }
    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    Directory('tool/data').createSync(recursive: true);
    File('tool/data/spoken_frequency.tsv').writeAsStringSync(
      '# Word use across ${lines.length} native-speaker Tatoeba sentences '
      '(tatoeba.org, CC BY 2.0 FR), by tool/count_frequency.dart.\n'
      '${sorted.map((e) => '${e.key}\t${e.value}').join('\n')}\n',
    );
    stderr.writeln('  ${sorted.length} words counted');
  }, timeout: Timeout.none);
}
