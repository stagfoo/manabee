import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:manabee/core/diary_check.dart';
import 'package:manabee/core/scan.dart';
import 'package:manabee/services/dictionary.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late LocalDictionary dict;

  setUpAll(() async {
    sqfliteFfiInit();
    // The very file that ships in the APK.
    final db = await databaseFactoryFfi.openDatabase(
      File('assets/dict/jmdict.db').absolute.path,
      options: OpenDatabaseOptions(readOnly: true),
    );
    dict = await LocalDictionary.fromDatabase(db);
  });

  Future<String> top(String q) async {
    final r = await dict.lookup(q);
    return r.isEmpty ? '' : '${r.first.word}[${r.first.reading}]';
  }

  test('words from the screenshots, exactly', () async {
    expect(await top('若い'), '若い[わかい]');
    expect(await top('あそぶ'), '遊ぶ[あそぶ]');
    expect(await top('いってきます'), '行ってきます[いってきます]');
    expect(await top('すっかり'), 'すっかり[すっかり]');
    expect(await top('いっぱい'), 'いっぱい[いっぱい]');
  });

  test('a kanji query shows the spelling that was asked for', () async {
    final r = await dict.lookup('家');
    expect(r.first.word, '家');
    expect(r.map((e) => e.reading), containsAll(['いえ', 'うち']));
  });

  test('entries carry JLPT, common and readable parts of speech', () async {
    final e = (await dict.lookup('若い')).first;
    expect(e.jlpt, 'N5');
    expect(e.common, isTrue);
    expect(e.senses.first.glosses, contains('young'));
    expect(e.senses.first.partsOfSpeech.first, contains('adjective'));
  });

  test('ー spelled out: とーちゃん is とうちゃん', () async {
    expect(await top('とーちゃん'), isNot(''));
    expect(spellingVariants('とーちゃん'), contains('とうちゃん'));
    expect(spellingVariants('ラーメン'), isEmpty);
  });

  test(
    'conjugations are not entries — the deinflector handles those',
    () async {
      expect(await dict.lookup('あそべる'), isEmpty);
      final r = (await scanWord('また あとで あそべるよ', 7, dict.lookup))!;
      expect(r.entries.first.word, '遊ぶ');
      expect(r.form?.label, 'potential');
    },
  );

  test('an OCR mix-up is read as the word it should be', () async {
    // The bubble as OCR read it: ば where the page has ぱ.
    const text = '人がいっばい居る';
    final r = (await scanWord(text, 2, dict.lookup))!;
    expect(r.surfaceOf(text), 'いっばい');
    expect(r.corrected, 'いっぱい');
    expect(r.entries.first.word, 'いっぱい');
    // Correct text is never "corrected".
    final ok = (await scanWord('人がいっぱい居る', 2, dict.lookup))!;
    expect(ok.corrected, isNull);
    expect(ok.surfaceOf('人がいっぱい居る'), 'いっぱい');
  });

  test('the last word of a sentence: verbs first', () async {
    // Out of context, かえる is a frog first and はる is spring.
    expect((await dict.lookup('かえる')).first.shortMeaning, 'frog');
    expect((await dict.lookup('はる')).first.word, '春');
    // At the end of a sentence, the verbs come first — nothing is dropped.
    final kaeru = predicatesFirst(await dict.lookup('かえる'));
    expect(kaeru.first.word, '帰る');
    expect(kaeru.map((e) => e.shortMeaning), contains('frog'));
    expect(predicatesFirst(await dict.lookup('はる')).first.word, '張る');
  });

  test('what counts as the end of a sentence', () {
    const text = 'いえにかえるよ！またあした。';
    expect(endsSentence(text, 6), isTrue); // かえる, then よ！
    expect(endsSentence(text, 3), isFalse); // いえに — more follows
    expect(endsSentence('人がいっぱい居るな！', 9), isTrue);
    expect(endsSentence('居るのは', 2), isFalse); // の then は: not the end
    expect(endsSentence('はる', 2), isTrue);
  });

  test('tapping through the yotsuba bubble', () async {
    const text = 'とーちゃん ここ家がいっぱいあるな！';
    Future<String> at(int i) async {
      final r = await scanWord(text, i, dict.lookup);
      return r == null ? '' : '${r.surfaceOf(text)}=${r.entries.first.word}';
    }

    expect(await at(0), 'とーちゃん=父ちゃん');
    // Usually written in kana, so shown as met — not 此処, 一杯, 有る.
    expect(await at(6), 'ここ=ここ');
    expect(await at(8), '家=家');
    expect(await at(10), 'いっぱい=いっぱい');
    expect((await at(14)).split('=').last, 'ある');
  });

  test('the build recorded its version and size', () {
    expect(dict.meta['jmdict'], isNotEmpty);
    expect(int.parse(dict.meta['entries']!), greaterThan(200000));
  });

  group('sentences split into words, particles marked', () {
    Future<String> split(String text) async {
      final spans = await segmentSentence(text, dict.lookup);
      return spans
          .map(
            (s) => '${text.substring(s.start, s.end)}${s.particle ? '*' : ''}',
          )
          .join(' ');
    }

    test('人がいっぱいいる: が is the particle, not がい (harm)', () async {
      expect(await split('人がいっぱいいる！'), '人 が* いっぱい いる');
    });

    test('the yotsuba bubble', () async {
      expect(
        await split('とーちゃん ここ家がいっぱいあるな！'),
        'とーちゃん ここ 家 が* いっぱい ある な*',
      ); // な ends the sentence
    });

    test('a few common shapes', () async {
      expect(await split('私は学生です'), '私 は* 学生 です');
      // A greeting in the dictionary (こんにちは), but here: today + は.
      expect(await split('今日は学校に行きました'), '今日 は* 学校 に* 行きました');
      expect(await split('本を読んだ'), '本 を* 読んだ');
      expect(await split('学校に行く'), '学校 に* 行く');
      expect(await split('東京から大阪まで'), '東京 から* 大阪 まで*');
    });

    test('particles are only particles after a word', () async {
      // は starting a sentence is read as a word (はい, yes), not a topic.
      expect(await split('はい'), 'はい');
    });
  });

  group('diary checks, on the real dictionary', () {
    Future<List<String>> check(String text) async => [
      for (final f in await checkJapanese(text, dict.lookup))
        '${f.kind.name}:${text.substring(f.start, f.end)}',
    ];

    test('clean writing passes', () async {
      expect(await check('今日は学校に行きました。とても楽しかったです。'), isEmpty);
      expect(await check('今日は学校に行った。楽しかった。'), isEmpty);
    });

    test('a typo is flagged', () async {
      expect(await check('きのう、ごはんをたべまたです。'), contains(startsWith('notAWord:')));
    });

    test('a one-character typo gets a suggestion', () async {
      final findings = await checkJapanese('人がいっばいいる。', dict.lookup);
      expect(findings.map((f) => f.message), contains(contains('「いっぱい」')));
    });

    test('a doubled particle', () async {
      expect(await check('私がが学生です。'), contains('doubledParticle:がが'));
    });

    test('mixed polite and plain: the odd one out is flagged', () async {
      expect(await check('今日は学校に行った。楽しかったです。明日も行きます。'), [
        'mixedStyle:今日は学校に行った',
      ]);
    });

    test('sentence style', () {
      expect(styleOf('行きますよ'), Style.polite);
      expect(styleOf('学生です'), Style.polite);
      expect(styleOf('行くね'), Style.plain);
      expect(styleOf('寒い'), Style.plain);
      expect(styleOf('見た'), Style.plain);
      expect(styleOf('東京'), Style.neither);
    });
  });
}
