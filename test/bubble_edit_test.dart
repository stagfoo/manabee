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
}
