import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:manabee/services/importer.dart';

/// A JPEG of [w]×[h] in one colour, with an EXIF capture time and
/// rotation tag, as a phone camera writes them.
File photo(
  Directory dir,
  String name,
  int w,
  int h, {
  String? taken,
  int? orientation,
  required int shade,
}) {
  final image = img.Image(width: w, height: h);
  img.fill(image, color: img.ColorRgb8(shade, shade, shade));
  if (taken != null) image.exif.exifIfd['DateTimeOriginal'] = taken;
  if (orientation != null) image.exif.imageIfd.orientation = orientation;
  final f = File('${dir.path}/$name');
  f.writeAsBytesSync(img.encodeJpg(image));
  return f;
}

void main() {
  late Directory root;
  late Directory src;

  setUp(() {
    root = Directory.systemTemp.createTempSync('manabee_root');
    src = Directory.systemTemp.createTempSync('manabee_src');
  });
  tearDown(() {
    root.deleteSync(recursive: true);
    src.deleteSync(recursive: true);
  });

  test('pages come out in the order taken, upright, and scaled down', () async {
    // Named so that name order would be wrong; EXIF says the truth.
    final page2 = photo(
      src,
      'a.jpg',
      300,
      200,
      taken: '2026:10:14 09:31:00',
      shade: 20,
    );
    final page1 = photo(
      src,
      'b.jpg',
      300,
      200,
      taken: '2026:10:14 09:30:00',
      orientation: 6,
      shade: 120,
    ); // sideways
    final page3 = photo(
      src,
      'c.jpg',
      6000,
      4000,
      taken: '2026:10:14 09:32:00',
      shade: 220,
    ); // huge

    final chapter = await Importer(root.path).importPhotos(
      'm',
      paths: [page2.path, page3.path, page1.path],
      title: 'Book',
    );
    expect(chapter.pages, hasLength(3));
    final pages = [
      for (final p in chapter.pages)
        img.decodeJpg(File('${root.path}/$p').readAsBytesSync())!,
    ];
    // By shade: taken order is page1 (120), page2 (20), page3 (220).
    expect(
      [for (final p in pages) p.getPixel(5, 5).r.round()],
      [closeTo(120, 8), closeTo(20, 8), closeTo(220, 8)],
    );
    // The sideways one is upright: 300×200 turned to 200×300.
    expect((pages[0].width, pages[0].height), (200, 300));
    // The huge one is 2400 on its long side.
    expect((pages[2].width, pages[2].height), (kPhotoLongSide, 1600));
  });

  test('from the camera, the order shot is kept', () async {
    final first = photo(
      src,
      'z.jpg',
      100,
      100,
      taken: '2026:10:14 10:00:00',
      shade: 40,
    );
    final second = photo(
      src,
      'a.jpg',
      100,
      100,
      taken: '2026:10:14 09:00:00',
      shade: 200,
    );
    final chapter = await Importer(root.path).importPhotos(
      'm',
      paths: [first.path, second.path],
      title: 'Book',
      sortByTaken: false,
    );
    final shades = [
      for (final p in chapter.pages)
        img
            .decodeJpg(File('${root.path}/$p').readAsBytesSync())!
            .getPixel(5, 5)
            .r
            .round(),
    ];
    expect(shades, [closeTo(40, 8), closeTo(200, 8)]);
  });
}
