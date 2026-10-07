import 'package:flutter_test/flutter_test.dart';
import 'package:manabee/core/scan.dart';
import 'package:manabee/models.dart';

/// A tiny dictionary, answering like jisho.org: exact entries for words
/// it has, a near match (the first character's entry) for anything else.
final _words = {
  'ここ': 'here',
  '家': 'house',
  'いえ': 'house',
  'が': '(subject particle)',
  'いっぱい': 'lots of',
  'ある': 'to be (things)',
  'とーちゃん': 'dad',
  'お店': 'shop',
  '遊ぶ': 'to play',
  'あそぶ': 'to play',
  'また': 'again',
  'あと': 'after',
  'あとで': 'later',
};

final asked = <String>[];

Future<List<Entry>> fakeLookup(String q) async {
  asked.add(q);
  if (q == 'あそぶ' || q == '遊ぶ') {
    // As jisho.org has it: written 遊ぶ, read あそぶ.
    return [
      const Entry(
        word: '遊ぶ',
        reading: 'あそぶ',
        senses: [
          Sense(glosses: ['to play']),
        ],
      ),
    ];
  }
  final gloss = _words[q];
  if (gloss != null) {
    return [
      Entry(
        word: q,
        reading: q,
        senses: [
          Sense(glosses: [gloss]),
        ],
      ),
    ];
  }
  final first = q.isEmpty ? '' : q.substring(0, 1);
  return [
    Entry(
      word: '$first?',
      reading: '$first?',
      senses: const [
        Sense(glosses: ['near match']),
      ],
    ),
  ];
}

void main() {
  setUp(asked.clear);

  // The yotsuba bubble, corrected: とーちゃん ここ家がいっぱいあるな！
  const text = 'とーちゃん ここ家がいっぱいあるな！';

  Future<(String, String?)> at(int i) async {
    final r = await scanWord(text, i, fakeLookup);
    return (r!.surfaceOf(text), r.form?.label);
  }

  test('each tap finds the word starting there', () async {
    expect(await at(0), ('とーちゃん', null));
    expect(await at(6), ('ここ', null));
    expect(await at(8), ('家', null));
    expect(await at(9), ('が', null));
    expect(await at(10), ('いっぱい', null));
  });

  test(
    'a trailing particle is undone, and only the word highlighted',
    () async {
      expect(await at(14), ('ある', 'with な'));
    },
  );

  test('conjugated words are found by their dictionary form', () async {
    final r = (await scanWord('また あとで あそべるよ', 7, fakeLookup))!;
    expect(r.entries.first.word, '遊ぶ');
    expect(r.form!.label, 'potential');
    expect(r.surfaceOf('また あとで あそべるよ'), 'あそべる');
  });

  test('the window stops at spaces and punctuation', () {
    expect(scanWindow(text, 0), 'とーちゃん');
    expect(scanWindow(text, 14), 'あるな');
    expect(scanWindow(text, 17), '');
  });

  test('longest exact match wins over a shorter one', () async {
    final r = (await scanWord('あとで', 0, fakeLookup))!;
    expect(r.surfaceOf('あとで'), 'あとで');
  });

  test('nothing to scan on punctuation, nothing known gives null', () async {
    expect(await scanWord(text, 17, fakeLookup), isNull);
    expect(await scanWord('ぬぬぬ', 0, fakeLookup), isNull);
  });

  test('deinflection lookups are capped', () async {
    await scanWord('ぬぬぬぬぬぬぬぬぬぬ', 0, fakeLookup, maxDeinflected: 5);
    // 10 prefixes as-is, then at most 5 deinflected.
    expect(asked.length, lessThanOrEqualTo(15));
  });
}
