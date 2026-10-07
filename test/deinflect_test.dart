import 'package:flutter_test/flutter_test.dart';
import 'package:manabee/core/deinflect.dart';

/// The first candidate that is in [dictionary] — what the reader does
/// against jisho.org.
Deinflection? resolve(String surface, Set<String> dictionary) {
  for (final d in deinflect(surface)) {
    if (dictionary.contains(d.term)) return d;
  }
  return null;
}

void main() {
  test('あそべるよ → あそぶ, potential (the nichijou bubble)', () {
    final d = resolve('あそべるよ', {'あそぶ'})!;
    expect(d.term, 'あそぶ');
    expect(d.label, 'potential');
    expect(d.wordOnPage('あそべるよ'), 'あそべる');
    expect(const Deinflection('食べる', ['past']).wordOnPage('食べた'), '食べた');
  });

  test('the particle comes off first, as its own candidate', () {
    expect(deinflect('あそべるよ').first, const Deinflection('あそべる', ['+ よ']));
    expect(deinflect('あそべるよ').first.label, 'with よ');
  });

  final dictionary = {
    '遊ぶ',
    'あそぶ',
    '食べる',
    '書く',
    '行く',
    '買う',
    '待つ',
    '読む',
    '話す',
    '泳ぐ',
    '死ぬ',
    '帰る',
    'する',
    'くる',
    '高い',
    '忘れる',
    'いる',
  };

  for (final (surface, term, label) in [
    ('遊べる', '遊ぶ', 'potential'),
    ('遊んで', '遊ぶ', 'te-form'),
    ('遊んでる', '遊ぶ', 'te-form · progressive'),
    ('遊んだ', '遊ぶ', 'past'),
    ('遊ばない', '遊ぶ', 'negative'),
    ('遊びます', '遊ぶ', 'polite'),
    ('遊びたい', '遊ぶ', 'want to'),
    ('遊ぼう', '遊ぶ', 'volitional'),
    ('食べました', '食べる', 'polite past'),
    ('食べない', '食べる', 'negative'),
    ('食べられる', '食べる', 'potential / passive'),
    ('食べてる', '食べる', 'te-form · progressive'),
    ('書いて', '書く', 'te-form'),
    ('書いた', '書く', 'past'),
    ('行って', '行く', 'te-form'),
    ('買わない', '買う', 'negative'),
    ('待って', '待つ', 'te-form'),
    ('読んでいる', '読む', 'te-form · progressive'),
    ('話した', '話す', 'past'),
    ('泳いだ', '泳ぐ', 'past'),
    ('帰れば', '帰る', 'conditional'),
    ('忘れてた', '忘れる', 'te-form · was …ing'),
    ('忘れちゃった', '忘れる', 'te-form · completely / regrettably'),
    ('しました', 'する', 'polite past'),
    ('きた', 'くる', 'past'),
    ('高かった', '高い', 'past'),
    ('高くない', '高い', 'negative'),
  ]) {
    test('$surface → $term ($label)', () {
      final d = resolve(surface, dictionary);
      expect(d?.term, term, reason: '${deinflect(surface)}');
      expect(d?.label, label);
    });
  }

  test('a word that is already a dictionary form gives nothing odd first', () {
    // 帰る is a dictionary form; the surface itself is never a candidate.
    expect(deinflect('帰る').map((d) => d.term), isNot(contains('帰る')));
  });

  test('nothing for empty or one-character input', () {
    expect(deinflect(''), isEmpty);
    expect(resolve('よ', dictionary), isNull);
  });
}
