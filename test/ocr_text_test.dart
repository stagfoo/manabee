import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:manabee/core/ocr_text.dart';

void main() {
  test('vertical columns read right to left', () {
    final pieces = [
      const OcrPiece('いる', Rect.fromLTWH(10, 0, 20, 80)),
      const OcrPiece('虫が', Rect.fromLTWH(40, 0, 20, 80)),
    ];
    expect(isVerticalLayout(pieces), isTrue);
    expect(joinPieces(pieces), '虫がいる');
  });

  test('horizontal lines read top to bottom, left to right', () {
    final pieces = [
      const OcrPiece('world', Rect.fromLTWH(0, 40, 80, 20)),
      const OcrPiece('there', Rect.fromLTWH(90, 0, 80, 20)),
      const OcrPiece('hello', Rect.fromLTWH(0, 0, 80, 20)),
    ];
    expect(isVerticalLayout(pieces), isFalse);
    expect(joinPieces(pieces), 'hello there world');
  });

  test('single characters do not decide the layout', () {
    final pieces = [
      const OcrPiece('あ', Rect.fromLTWH(0, 0, 10, 40)),
      const OcrPiece('おはよう', Rect.fromLTWH(0, 50, 80, 20)),
    ];
    expect(isVerticalLayout(pieces), isFalse);
  });

  test('spaces between Japanese are removed, Latin spaces kept', () {
    expect(cleanOcrText('おはよう \n スイ 。'), 'おはようスイ。');
    expect(cleanOcrText('good   morning'), 'good morning');
    expect(cleanOcrText('OK です'), 'OKです');
  });

  group('per-character ordering', () {
    test('いってきまーす: two vertical columns read right to left', () {
      // いって is the right-hand column, きまーす the left — the order ML
      // Kit got backwards on nichijou page 1.
      final glyphs = [...column('きまーす', 0), ...column('いって', 30)]..shuffle();
      expect(joinGlyphs(glyphs), 'いってきまーす');
    });

    test('a vertical ー read as a bar comes back as ー', () {
      final glyphs = [...column('きま|す', 0), ...column('いって', 30)];
      expect(joinGlyphs(glyphs), 'いってきまーす');
    });

    test('furigana beside kanji is dropped', () {
      final glyphs = [
        ...column('朝食は', 40),
        // ちょうしょく, half-size, in a thin column to the right of 朝食.
        ...column('ちょうしょく', 62, size: 8),
        ...column('作って', 0),
      ];
      expect(joinGlyphs(glyphs), '朝食は作って');
    });

    test('small kana are not mistaken for furigana', () {
      final glyphs = [
        Glyph('い', const Rect.fromLTWH(0, 0, 20, 20)),
        Glyph('っ', const Rect.fromLTWH(4, 26, 12, 12)),
        Glyph('て', const Rect.fromLTWH(0, 44, 20, 20)),
        Glyph('き', const Rect.fromLTWH(0, 66, 20, 20)),
      ];
      expect(joinGlyphs(glyphs), 'いってき');
    });

    test('horizontal Japanese reads in rows', () {
      final glyphs = [...row('おはよう', 0), ...row('スイ', 30)];
      expect(joinGlyphs(glyphs), 'おはようスイ');
    });

    test('horizontal Latin keeps its word gaps', () {
      final glyphs = row('good morning', 0);
      expect(joinGlyphs(glyphs), 'good morning');
    });

    test('empty', () {
      expect(joinGlyphs(const []), '');
    });
  });

  test('empty', () {
    expect(joinPieces(const []), '');
    expect(cleanOcrText('  \n '), '');
  });
}

/// A vertical column of [text] at [x], one 20px glyph per character from
/// the top, as ML Kit's per-character symbols would come back.
List<Glyph> column(String text, double x, {double size = 20, double top = 0}) {
  final chars = text.runes.map(String.fromCharCode).toList();
  return [
    for (var i = 0; i < chars.length; i++)
      Glyph(chars[i], Rect.fromLTWH(x, top + i * size * 1.1, size, size)),
  ];
}

List<Glyph> row(String text, double y, {double size = 20, double left = 0}) {
  final chars = text.runes.map(String.fromCharCode).toList();
  return [
    for (var i = 0; i < chars.length; i++)
      if (chars[i] != ' ')
        Glyph(
          chars[i],
          Rect.fromLTWH(left + i * size * 0.6, y, size * 0.5, size),
        ),
  ];
}
