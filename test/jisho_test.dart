import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:manabee/services/jisho.dart';

void main() {
  // Captured from https://jisho.org/api/v1/search/words?keyword=若い
  final body = File('test/fixtures/jisho_wakai.json').readAsStringSync();

  test('parses the first entry fully', () {
    final entries = parseJisho(body);
    expect(entries, isNotEmpty);
    final e = entries.first;
    expect(e.word, '若い');
    expect(e.reading, 'わかい');
    expect(e.romaji, 'wakai');
    expect(e.common, isTrue);
    expect(e.jlpt, 'N5');
    expect(e.wanikani, 19);
    expect(e.senses.first.glosses, ['young', 'youthful']);
    expect(e.senses.first.partsOfSpeech, isNotEmpty);
    expect(e.shortMeaning, 'young; youthful');
  });

  test('entries without a JLPT level have none', () {
    final e = parseJisho(body).firstWhere((e) => e.word == '若い者');
    expect(e.jlpt, isNull);
    expect(e.common, isFalse);
  });

  test('kana-only entries use the reading as the word', () {
    final e = parseJisho(
      jsonEncode({
        'data': [
          {
            'japanese': [
              {'reading': 'これ'},
            ],
            'senses': [
              {
                'english_definitions': ['this'],
                'parts_of_speech': ['Pronoun'],
              },
            ],
            'jlpt': ['jlpt-n5', 'jlpt-n4'],
          },
        ],
      }),
    ).single;
    expect(e.word, 'これ');
    expect(e.hasKanji, isFalse);
    // The easiest level wins.
    expect(e.jlpt, 'N5');
  });

  test('wikipedia senses and empty entries are dropped', () {
    final entries = parseJisho(
      jsonEncode({
        'data': [
          {
            'japanese': [
              {'word': '虫', 'reading': 'むし'},
            ],
            'senses': [
              {
                'english_definitions': ['insect'],
                'parts_of_speech': ['Noun'],
              },
              {
                'english_definitions': ['Mushi (film)'],
                'parts_of_speech': ['Wikipedia definition'],
              },
            ],
          },
          {
            'japanese': [
              {'word': 'ウィキ'},
            ],
            'senses': [
              {
                'english_definitions': ['Wiki'],
                'parts_of_speech': ['Wikipedia definition'],
              },
            ],
          },
          {'japanese': [], 'senses': []},
        ],
      }),
    );
    expect(entries.single.senses.single.glosses, ['insect']);
  });

  test('malformed bodies give nothing rather than throwing', () {
    expect(parseJisho('{}'), isEmpty);
    expect(parseJisho('{"data": "x"}'), isEmpty);
    expect(parseJisho('{"data": [1, null, "x"]}'), isEmpty);
  });
}
