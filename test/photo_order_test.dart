import 'package:flutter_test/flutter_test.dart';
import 'package:manabee/core/photo_order.dart';

void main() {
  test('EXIF dates', () {
    expect(
      parseExifDate('2026:10:14 09:30:12'),
      DateTime(2026, 10, 14, 9, 30, 12),
    );
    expect(parseExifDate('0000:00:00 00:00:00'), isNull);
    expect(parseExifDate(''), isNull);
    expect(parseExifDate(null), isNull);
  });

  test('camera file names', () {
    expect(
      dateFromFilename('IMG_20261014_093012.jpg'),
      DateTime(2026, 10, 14, 9, 30, 12),
    );
    expect(
      dateFromFilename('PXL_20261014_093012345.jpg'),
      DateTime(2026, 10, 14, 9, 30, 12, 345),
    );
    expect(
      dateFromFilename('20261014_093012.jpg'),
      DateTime(2026, 10, 14, 9, 30, 12),
    );
    expect(
      dateFromFilename('Screenshot_2026-10-14-09-30-12.png'),
      DateTime(2026, 10, 14, 9, 30, 12),
    );
    expect(dateFromFilename('page 3.jpg'), isNull);
    expect(dateFromFilename('IMG_99999999_999999.jpg'), isNull);
  });

  test('ordered by the best clock: EXIF, then the name, then the file', () {
    final photos = [
      // Picked out of order, as a gallery hands them over.
      const PhotoInfo('IMG_20261014_093105.jpg'), // page 3 by name
      PhotoInfo('a.jpg', exifDate: DateTime(2026, 10, 14, 9, 30, 0)), // page 1
      PhotoInfo('b.jpg', fileDate: DateTime(2026, 10, 14, 9, 30, 30)), // page 2
      const PhotoInfo('cover.jpg'), // undated: last
    ];
    expect(inTakenOrder(photos, (p) => p).map((p) => p.name), [
      'a.jpg',
      'b.jpg',
      'IMG_20261014_093105.jpg',
      'cover.jpg',
    ]);
  });

  test('EXIF beats a misleading file name', () {
    final photos = [
      PhotoInfo('IMG_20200101_000000.jpg', exifDate: DateTime(2026, 1, 2)),
      PhotoInfo('IMG_20300101_000000.jpg', exifDate: DateTime(2026, 1, 1)),
    ];
    expect(
      inTakenOrder(photos, (p) => p).first.name,
      'IMG_20300101_000000.jpg',
    );
  });

  test('undated photos fall back to natural name order', () {
    final photos = [const PhotoInfo('p10.jpg'), const PhotoInfo('p2.jpg')];
    expect(inTakenOrder(photos, (p) => p).map((p) => p.name), [
      'p2.jpg',
      'p10.jpg',
    ]);
  });
}
