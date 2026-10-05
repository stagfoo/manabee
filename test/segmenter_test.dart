import 'package:flutter_test/flutter_test.dart';
import 'package:manabee/core/segmenter.dart';

List<String> texts(String s) => segment(s).map((e) => e.text).toList();

void main() {
  test('kanji keep their okurigana up to a particle', () {
    expect(texts('若い頃の記憶'), ['若い', '頃', 'の', '記憶']);
    expect(texts('食べる'), ['食べる']);
  });

  test('okurigana is capped', () {
    // 食べられなかった: the stem gets 4 kana, the rest is its own piece.
    final s = texts('食べられなかった');
    expect(s.first, '食べられな');
    expect(s.length, 2);
    expect(s.join(), '食べられなかった');
  });

  test('a particle after kanji splits', () {
    expect(texts('私は学生です'), ['私', 'は', '学生', 'です']);
  });

  test('katakana runs stay whole, including ー', () {
    expect(texts('ラーメンを食べた'), ['ラーメン', 'を', '食べた']);
  });

  test('punctuation is its own segment and not lookup-worthy', () {
    final s = segment('おはよう、スイ！');
    expect(s.map((e) => e.text), ['おはよう', '、', 'スイ', '！']);
    expect(s[1].lookupWorthy, isFalse);
    expect(s[3].lookupWorthy, isFalse);
  });

  test('whitespace is dropped', () {
    expect(texts('  虫 が  いる '), ['虫', 'が', 'いる']);
  });

  test('a lone particle is not lookup-worthy, longer kana is', () {
    final s = segment('本のこと');
    expect(s.map((e) => e.text), ['本', 'の', 'こと']);
    expect(s[1].lookupWorthy, isFalse);
    expect(s[2].lookupWorthy, isTrue);
  });

  test('hiragana words are not split on particle-like characters', () {
    expect(texts('おはよう'), ['おはよう']);
    expect(texts('こんにちは'), ['こんにちは']);
  });

  test('the copula is neither okurigana nor a particle', () {
    expect(texts('学生だ'), ['学生', 'だ']);
    expect(texts('ラーメンです'), ['ラーメン', 'です']);
  });

  test('te-form and negative conjugations stay attached', () {
    expect(texts('読んで'), ['読んで']);
    expect(texts('少ない'), ['少ない']);
  });

  test('か after kanji stays as okurigana, as in 静か', () {
    expect(texts('静かな'), ['静かな']);
  });

  test('latin and digits group together', () {
    expect(texts('OK100回'), ['OK100', '回']);
  });

  test('lookupCandidates dedupes, keeps order, skips particles', () {
    expect(lookupCandidates('虫が虫を見た。'), ['虫', '見た']);
  });

  test('empty input', () {
    expect(segment(''), isEmpty);
    expect(lookupCandidates(''), isEmpty);
  });

  test('ー after hiragana stays in the word', () {
    expect(texts('いってきまーす'), ['いってきまーす']);
    expect(texts('行きまーす'), ['行きまーす']);
  });

  test('ー in katakana is still a real long vowel', () {
    expect(texts('ラーメンだ'), ['ラーメン', 'だ']);
  });

  test('chips are offered in the dictionary form', () {
    expect(lookupCandidates('いってきまーす'), ['いってきます']);
    expect(lookupCandidates('ばかっ！'), ['ばか']);
    expect(lookupCandidates('ラーメン'), ['ラーメン']);
  });
}
