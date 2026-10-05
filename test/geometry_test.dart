import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:manabee/core/geometry.dart';

void main() {
  group('containRect', () {
    test('tall image in a wide box is pillarboxed', () {
      final r = containRect(const Size(1000, 1500), const Size(400, 300));
      expect(r, const Rect.fromLTWH(100, 0, 200, 300));
    });

    test('wide image in a tall box is letterboxed', () {
      final r = containRect(const Size(2000, 1000), const Size(400, 800));
      expect(r, const Rect.fromLTWH(0, 300, 400, 200));
    });

    test('empty sizes give zero', () {
      expect(containRect(Size.zero, const Size(10, 10)), Rect.zero);
      expect(containRect(const Size(10, 10), Size.zero), Rect.zero);
    });
  });

  group('normalising', () {
    const image = Rect.fromLTWH(100, 50, 200, 400);

    test('round trip', () {
      const p = Offset(150, 150);
      final n = toNormalized(p, image)!;
      expect(n, const Offset(0.25, 0.25));
      expect(fromNormalized(n, image), p);
    });

    test('outside the image is null', () {
      expect(toNormalized(const Offset(50, 100), image), isNull);
    });

    test('selection is ordered and clamped to the image', () {
      final r = normalizedSelection(
        const Offset(350, 500),
        const Offset(200, 0),
        image,
      );
      expect(r, const Rect.fromLTRB(0.5, 0, 1, 1));
    });

    test('denormalize inverts a selection', () {
      const n = Rect.fromLTRB(0.25, 0.5, 0.75, 1);
      expect(
        denormalizeRect(n, image),
        const Rect.fromLTRB(150, 250, 250, 450),
      );
    });

    test('pixel rect normalised to the image', () {
      expect(
        normalizePixelRect(
          const Rect.fromLTRB(100, 200, 300, 400),
          const Size(1000, 800),
        ),
        const Rect.fromLTRB(0.1, 0.25, 0.3, 0.5),
      );
    });
  });

  group('pixelCrop', () {
    test('covers the normalised rect', () {
      final c = pixelCrop(const Rect.fromLTRB(0.1, 0.2, 0.5, 0.6), 1000, 500);
      expect((c.x, c.y, c.width, c.height), (100, 100, 400, 200));
    });

    test('never empty, even for a zero-size rect', () {
      final c = pixelCrop(const Rect.fromLTRB(0.5, 0.5, 0.5, 0.5), 100, 100);
      expect(c.width, greaterThanOrEqualTo(1));
      expect(c.height, greaterThanOrEqualTo(1));
    });

    test('clamped at the far edge', () {
      final c = pixelCrop(const Rect.fromLTRB(0.9, 0.9, 1.2, 1.2), 100, 100);
      expect(c.x + c.width, lessThanOrEqualTo(100));
      expect(c.y + c.height, lessThanOrEqualTo(100));
    });
  });

  test('tiny selections are rejected', () {
    expect(isUsableSelection(const Rect.fromLTRB(0, 0, 0.01, 0.5)), isFalse);
    expect(isUsableSelection(const Rect.fromLTRB(0, 0, 0.1, 0.1)), isTrue);
  });
}
