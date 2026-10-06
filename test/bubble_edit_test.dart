import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:manabee/models.dart';

Bubble bubble({String source = '', String translation = '', Rect? region}) =>
    Bubble(
      id: 'b',
      chapterId: 'c',
      page: 0,
      position: const Offset(0.5, 0.5),
      source: source,
      translation: translation,
      region: region,
    );

void main() {
  group('joinText', () {
    test('Japanese runs straight on', () {
      expect(joinText('朝', '食'), '朝食');
      expect(joinText('朝食は', '自分で'), '朝食は自分で');
    });

    test('Japanese punctuation joins tight too', () {
      expect(joinText('おはよう、', 'スイ'), 'おはよう、スイ');
      expect(joinText('なに', '！？'), 'なに！？');
    });

    test('other text gets a space', () {
      expect(joinText('good morning', 'Sui'), 'good morning Sui');
    });

    test('empty and whitespace sides drop out', () {
      expect(joinText('', '朝'), '朝');
      expect(joinText('  朝 ', '  '), '朝');
      expect(joinText('', ''), '');
    });
  });

  test('appendSource adds the missing piece', () {
    final b = bubble(source: '朝');
    expect(b.appendSource('食'), isTrue);
    expect(b.source, '朝食');
  });

  test('appendSource fills an empty bubble, ignores blank input', () {
    final b = bubble(translation: 'breakfast');
    expect(b.appendSource('  '), isFalse);
    expect(b.source, '');
    expect(b.appendSource('朝食'), isTrue);
    expect(b.source, '朝食');
    expect(b.translation, 'breakfast');
  });

  group('mergeFrom', () {
    test('appends both sides and unions the regions', () {
      final a = bubble(
        source: '朝食は自分で',
        translation: 'Make your own',
        region: const Rect.fromLTRB(0.5, 0.1, 0.6, 0.4),
      );
      final b = bubble(
        source: '作って下さい',
        translation: 'breakfast, please',
        region: const Rect.fromLTRB(0.4, 0.1, 0.5, 0.5),
      );
      a.mergeFrom(b);
      expect(a.source, '朝食は自分で作って下さい');
      expect(a.translation, 'Make your own breakfast, please');
      expect(a.region, const Rect.fromLTRB(0.4, 0.1, 0.6, 0.5));
    });

    test('a hand-placed bubble takes the OCR region it merges in', () {
      final a = bubble(translation: 'morning');
      a.mergeFrom(
        bubble(source: '朝', region: const Rect.fromLTRB(0, 0, 0.1, 0.1)),
      );
      expect(a.source, '朝');
      expect(a.translation, 'morning');
      expect(a.region, const Rect.fromLTRB(0, 0, 0.1, 0.1));
    });

    test('two regionless bubbles stay regionless', () {
      final a = bubble(source: '朝');
      a.mergeFrom(bubble(source: '食'));
      expect(a.region, isNull);
      expect(a.source, '朝食');
    });
  });

  group('merging follows the page, not the tap order', () {
    // nichijou p1: 「ひーすっかり」 is the right column, 「忘れてたー」 the left.
    Bubble at(String source, Rect region) => Bubble(
      id: source,
      chapterId: 'c',
      page: 0,
      position: region.center,
      source: source,
      region: region,
    );
    final right = at('ひーすっかり', const Rect.fromLTRB(0.6, 0.2, 0.7, 0.5));
    final left = at('忘れてたー', const Rect.fromLTRB(0.5, 0.2, 0.6, 0.45));

    test('right column first, whichever is merged into which', () {
      final a = at(right.source, right.region!)
        ..mergeFrom(at(left.source, left.region!));
      final b = at(left.source, left.region!)
        ..mergeFrom(at(right.source, right.region!));
      expect(a.source, 'ひーすっかり忘れてたー');
      expect(b.source, 'ひーすっかり忘れてたー');
    });

    test('left-to-right books read left first', () {
      final a = at(right.source, right.region!)
        ..mergeFrom(at(left.source, left.region!), rightToLeft: false);
      expect(a.source, '忘れてたーひーすっかり');
    });

    test('stacked bubbles read top first', () {
      final top = at('上', const Rect.fromLTRB(0.4, 0.1, 0.6, 0.2));
      final bottom = at('下', const Rect.fromLTRB(0.42, 0.3, 0.58, 0.4));
      bottom.mergeFrom(top);
      expect(bottom.source, '上下');
    });
  });

  group('Japanese typed into the translation field', () {
    test('moves to the Japanese field when that is empty', () {
      final b = bubble(translation: 'わすれてたー');
      expect(b.refile(), isTrue);
      expect(b.source, 'わすれてたー');
      expect(b.translation, '');
    });

    test('a real translation, or a filled Japanese field, stays put', () {
      expect(bubble(translation: 'I forgot!').refile(), isFalse);
      expect(bubble(translation: 'OK です').refile(), isFalse);
      expect(bubble(source: '朝', translation: 'わすれた').refile(), isFalse);
    });

    test('merging refiles first — the bug from nichijou p1', () {
      final ocr = Bubble(
        id: 'ocr',
        chapterId: 'c',
        page: 0,
        position: const Offset(0.65, 0.5),
        region: const Rect.fromLTRB(0.6, 0.2, 0.7, 0.5),
        source: 'ひーすっかり',
      );
      final typed = Bubble(
        id: 'typed',
        chapterId: 'c',
        page: 0,
        position: const Offset(0.55, 0.3),
        translation: '忘れてたー',
      );
      ocr.mergeFrom(typed);
      expect(ocr.source, 'ひーすっかり忘れてたー');
      expect(ocr.translation, '');
    });
  });
}
