// Step 2 of building assets/sentences/: grade the candidates by JLPT level.
//
// Run as a test, for the dictionary over sqflite_common_ffi:
//
//     flutter test tool/grade_sentences.dart
//
// Each sentence is segmented with the reader's own segmenter — so 食べました
// counts as 食べる — and its level is that of its hardest word. A sentence
// is kept only if every word is a dictionary word on a JLPT list, N5 to N3
// (katakana loanwords and names aside), with no word explained only as a
// misprint and no Latin letters. Its words are recorded by dictionary form,
// so the app can find sentences for a focus word.
//
// Output: assets/sentences/sentences.tsv — id, level, Japanese, English,
// words (word|reading, joined by ,), author — and version.txt.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:manabee/core/kana.dart';
import 'package:manabee/core/scan.dart';
import 'package:manabee/services/dictionary.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const _levels = ['N5', 'N4', 'N3'];

void main() {
  test('grade sentences', () async {
    sqfliteFfiInit();
    final db = await databaseFactoryFfi.openDatabase(
      File('assets/dict/jmdict.db').absolute.path,
      options: OpenDatabaseOptions(readOnly: true),
    );
    final dict = await LocalDictionary.fromDatabase(db);
    final limit = int.tryParse(Platform.environment['LIMIT'] ?? '');
    final all = File('build/sentences/candidates.tsv').readAsLinesSync();
    final lines = limit == null ? all : all.take(limit).toList();
    final out = StringBuffer();
    final counts = {for (final l in _levels) l: 0};
    var seen = 0;
    for (final line in lines) {
      seen++;
      if (seen % 5000 == 0) stderr.writeln('  $seen / ${lines.length}');
      final [id, jp, en, author] = line.split('\t');
      final graded = await _grade(jp, dict);
      if (graded == null) continue;
      final (level, words) = graded;
      counts[level] = counts[level]! + 1;
      out.writeln([id, level, jp, en, words.join(','), author].join('\t'));
    }
    Directory('assets/sentences').createSync(recursive: true);
    File('assets/sentences/sentences.tsv').writeAsStringSync(out.toString());
    File('assets/sentences/version.txt').writeAsStringSync(
      'tatoeba ${DateTime.now().toIso8601String().substring(0, 10)} '
      '${counts.entries.map((e) => '${e.key}:${e.value}').join(' ')}\n',
    );
    stderr.writeln('  kept $counts of ${lines.length}');
  }, timeout: Timeout.none);
}

final _latin = RegExp('[A-Za-zＡ-Ｚａ-ｚ]');

Future<(String, List<String>)?> _grade(
  String text,
  LocalDictionary dict,
) async {
  if (_latin.hasMatch(text)) return null;
  final spans = await segmentSentence(text, dict.lookup);
  var hardest = 0;
  final words = <String>{};
  for (final s in spans) {
    if (s.particle) continue;
    if (s.corrected != null) return null;
    final surface = text.substring(s.start, s.end);
    // One hiragana that isn't a particle is how a mis-split shows (は of
    // ではない read as 春's は): don't trust the sentence's word list.
    if (surface.length == 1 && isHiragana(surface.codeUnitAt(0))) return null;
    // Katakana: a loanword or a name (トム, パン) — readable by anyone who
    // reads katakana, so it doesn't make a sentence harder.
    if (surface.runes.every(isKatakana)) continue;
    final r = await scanWord(text, s.start, dict.lookup);
    final e = r?.entries.firstOrNull;
    if (r == null || e == null || r.end != s.end) return null;
    final level = _levels.indexOf(e.jlpt ?? '');
    if (level < 0) return null;
    if (level > hardest) hardest = level;
    words.add('${e.word}|${e.reading}');
  }
  if (words.length < 2) return null;
  return (_levels[hardest], words.toList());
}
