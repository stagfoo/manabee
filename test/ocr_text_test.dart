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

  test('empty', () {
    expect(joinPieces(const []), '');
    expect(cleanOcrText('  \n '), '');
  });
}
