/// Mock JLPT tests: the trap answers, and that no trap is ever right.
library;

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:manabee/core/mock_test.dart';
import 'package:manabee/core/sentences.dart';
import 'package:manabee/models.dart';

Entry e(String w, String r, {String? jlpt = 'N5'}) => Entry(
  word: w,
  reading: r,
  jlpt: jlpt,
  senses: const [
    Sense(glosses: ['x']),
  ],
);

/// A dictionary of a handful of words, looked up by spelling or reading.
Lookup fakeLookup(List<Entry> entries) =>
    (q) async => [
      for (final x in entries)
        if (x.word == q || x.reading == q) x,
    ];

void main() {
  group('reading traps', () {
    List<String> traps(String kana, [String tail = '']) => [
      for (final (s, _) in readingTraps(kana, tail)) s,
    ];

    test('the long vowel, dropped and added', () {
      expect(traps('とうきょう'), contains('ときょう'));
      expect(traps('とうきょう'), contains('とうきょ'));
      expect(traps('こども'), contains('こうども'));
    });

    test('the small っ, dropped and invented', () {
      expect(traps('がっこう'), contains('がこう'));
      expect(traps('さかな'), contains('さっかな'));
    });

    test('voicing and the size of ゃゅょ', () {
      expect(traps('てがみ'), contains('てかみ'));
      expect(traps('じしょ'), contains('じしよ'));
    });

    test('only the kanji part changes; the okurigana is on the page', () {
      for (final t in traps('つか', 'って')) {
        expect(t, endsWith('って'));
      }
    });

    test(
      'no lengthening after a bare vowel, before ん, or with い at the end',
      () {
        expect(traps('りょこう'), isNot(contains('りょこうう')));
        expect(traps('でんしゃ'), isNot(contains('でいんしゃ')));
        expect(traps('なまえ'), isNot(contains('なまえい')));
      },
    );

    test('nothing that could not be a reading at all', () {
      expect(wellFormedKana('っか'), isFalse);
      expect(wellFormedKana('かっ'), isFalse);
      expect(wellFormedKana('かっな'), isFalse);
      expect(wellFormedKana('かゃ'), isFalse);
      expect(wellFormedKana('きゃく'), isTrue);
    });
  });

  group('another reading of the kanji', () {
    const facts = {
      '名': KanjiFacts(readings: ['めい', 'みょう', 'な'], kun: ['な']),
      '前': KanjiFacts(readings: ['ぜん', 'まえ'], kun: ['まえ']),
      '聞': KanjiFacts(readings: ['ぶん', 'もん', 'き'], kun: ['き']),
      '山': KanjiFacts(readings: ['さん', 'やま'], kun: ['やま']),
    };

    test(
      'swaps the first or last kanji\'s reading where the split is sure',
      () {
        expect(
          otherReadingTraps('名前', 'なまえ', facts),
          containsAll(['めいまえ', 'みょうまえ', 'なぜん']),
        );
        expect(otherReadingTraps('山', 'やま', facts), ['さん']);
      },
    );

    test('a word with okurigana only gets kun readings', () {
      expect(otherReadingTraps('聞', 'き', facts, okurigana: true), isEmpty);
    });
  });

  group('writing traps', () {
    const facts = {
      '休': KanjiFacts(parts: ['亻', '木'], grade: 1),
      '体': KanjiFacts(parts: ['亻', '本'], grade: 2),
      '崇': KanjiFacts(parts: ['山', '宗'], grade: 8),
      '出': KanjiFacts(parts: ['山', '凵'], grade: 1),
    };
    final byPart = <String, List<String>>{};
    for (final MapEntry(key: k, value: f) in facts.entries) {
      for (final p in f.parts) {
        byPart.putIfAbsent(p, () => []).add(k);
      }
    }

    test('kanji sharing a part, but none above the level', () {
      expect(lookalikesOf('休', facts, byPart, maxGrade: 2), contains('体'));
      expect(
        lookalikesOf('出', facts, byPart, maxGrade: 2),
        isNot(contains('崇')),
      );
    });

    test('the okurigana cut short and written out', () {
      final shown = [
        for (final t in writingTraps('新', 'あたら', 'しい', {}, {})) t.apply('しい'),
      ];
      expect(shown, containsAll(['新い', '新らしい']));
    });

    test('a compound swapped round', () {
      final shown = [
        for (final t in writingTraps('手紙', 'てがみ', '', {}, {})) t.kanji,
      ];
      expect(shown, contains('紙手'));
    });
  });

  test('a word splits into its kanji and its okurigana', () {
    expect(splitWritten('分かる'), ('分', 'かる'));
    expect(splitWritten('学生'), ('学生', ''));
    expect(splitWritten('お茶'), isNull);
    expect(splitWritten('取り消す'), isNull);
  });

  group('a whole test', () {
    final sentences = parseSentences('''
1\tN5\t私は毎日学校へ行きます。\tI go to school every day.\t私|わたし,毎日|まいにち,学校|がっこう,行く|いく\tamy
2\tN5\t今日は寒いです。\tIt is cold today.\t今日|きょう,寒い|さむい\tamy
3\tN5\t新しい靴を買いました。\tI bought new shoes.\t新しい|あたらしい,靴|くつ,買う|かう\tken
''');
    final entries = [
      e('私', 'わたし'),
      e('毎日', 'まいにち'),
      e('学校', 'がっこう'),
      e('行く', 'いく'),
      e('今日', 'きょう'),
      e('今日', 'こんにち'),
      e('寒い', 'さむい'),
      e('新しい', 'あたらしい'),
      e('靴', 'くつ'),
      e('買う', 'かう'),
      // A real alternative spelling, which must never be a wrong answer.
      e('新い', 'あたらしい', jlpt: null),
    ];
    final words = {for (final x in entries) '${x.word}|${x.reading}': x};

    Future<List<MockQuestion>> build(int seed) => buildMockTest(
      level: 'N5',
      sentences: sentences,
      words: words,
      facts: const {},
      lookup: fakeLookup(entries),
      random: Random(seed),
    );

    test(
      'every question has four options, one right, the word underlined',
      () async {
        for (var seed = 0; seed < 20; seed++) {
          for (final q in await build(seed)) {
            expect(q.options, hasLength(4));
            expect(q.options.toSet(), hasLength(4));
            final right = q.options[q.answer];
            expect(
              right,
              q.section == MockSection.reading ? q.kana : q.written,
            );
            final (a, b) = q.underline;
            expect(
              q.shown.substring(a, b),
              q.section == MockSection.reading ? q.written : q.kana,
            );
          }
        }
      },
    );

    test('a spelling with two readings is never asked about', () async {
      for (var seed = 0; seed < 20; seed++) {
        for (final q in await build(seed)) {
          expect(q.entry.word, isNot('今日'));
        }
      }
    });

    test('a real way of writing the word is never a wrong answer', () async {
      for (var seed = 0; seed < 30; seed++) {
        for (final q in await build(seed)) {
          if (q.entry.word == '新しい' && q.section == MockSection.writing) {
            expect(q.options, isNot(contains('新い')));
          }
        }
      }
    });

    test('the word is underlined as conjugated in the sentence', () async {
      for (var seed = 0; seed < 30; seed++) {
        for (final q in await build(seed)) {
          if (q.entry.word == '行く') {
            expect(q.written, '行きます');
            expect(q.kana, 'いきます');
          }
        }
      }
    });
  });
}
