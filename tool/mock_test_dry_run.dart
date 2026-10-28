// Builds mock JLPT tests against the real dictionary and sentences, and
// prints them — the check that the wrong answers look like the test's,
// and that none of them is secretly right.
//
//     LEVEL=N5 COUNT=2 flutter test tool/mock_test_dry_run.dart
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:manabee/core/kanji_chain.dart';
import 'package:manabee/core/mock_test.dart';
import 'package:manabee/core/sentences.dart';
import 'package:manabee/models.dart';
import 'package:manabee/services/dictionary.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  test('mock tests', () async {
    sqfliteFfiInit();
    final db = await databaseFactoryFfi.openDatabase(
      File('assets/dict/jmdict.db').absolute.path,
      options: OpenDatabaseOptions(readOnly: true),
    );
    final dict = await LocalDictionary.fromDatabase(db);
    final level = Platform.environment['LEVEL'] ?? 'N5';
    final count = int.tryParse(Platform.environment['COUNT'] ?? '') ?? 1;
    final sentences = parseSentences(
      File('assets/sentences/sentences.tsv').readAsStringSync(),
    );
    final combos = [
      for (final j in (jsonDecode(
            File('assets/kanji/combos.json').readAsStringSync(),
          ) as Map)['combos'] as List)
        Combo.fromJson(j as Map<String, dynamic>),
    ];
    final facts = mockKanjiFacts(combos);
    final words = <String, Entry>{};
    for (final l in kSentenceLevels.sublist(0, kSentenceLevels.indexOf(level) + 1)) {
      for (final e in await dict.jlptWords(l)) {
        words.putIfAbsent('${e.word}|${e.reading}', () => e);
      }
    }
    stderr.writeln('${words.length} words, ${facts.length} kanji with facts');
    for (var n = 0; n < count; n++) {
      final sw = Stopwatch()..start();
      final qs = await buildMockTest(
        level: level,
        sentences: sentences,
        words: words,
        facts: facts,
        lookup: dict.lookup,
        random: Random(n),
      );
      stderr.writeln('\n== $level test ${n + 1}: ${qs.length} questions '
          'in ${sw.elapsedMilliseconds}ms ==');
      for (final q in qs) {
        final (a, b) = q.underline;
        final s = q.shown;
        stderr.writeln(
          '[${q.section.name.padRight(7)}] ${s.substring(0, a)}【${s.substring(a, b)}】${s.substring(b)}'
          '   ${q.entry.jlpt}',
        );
        stderr.writeln('          ${[
          for (final (i, o) in q.options.indexed) i == q.answer ? '*$o' : o,
        ].join('   ')}');
      }
    }
  }, timeout: Timeout.none);
}
