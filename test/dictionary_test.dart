import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
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
      expect(await split('本を読んだ'), '本 を* 読んだ');
      expect(await split('学校に行く'), '学校 に* 行く');
      expect(await split('東京から大阪まで'), '東京 から* 大阪 まで*');
    });

    test('particles are only particles after a word', () async {
      // は starting a sentence is read as a word (はい, yes), not a topic.
      expect(await split('はい'), 'はい');
    });
  });
}
