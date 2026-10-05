import 'package:flutter_test/flutter_test.dart';
import 'package:manabee/core/pages.dart';

void main() {
  test('natural sort puts 2 before 10', () {
    expect(naturalSorted(['10.jpg', '2.jpg', '1.jpg']), [
      '1.jpg',
      '2.jpg',
      '10.jpg',
    ]);
    expect(naturalSorted(['p10', 'P2', 'p1']), ['p1', 'P2', 'p10']);
    expect(naturalSorted(['ch2/1.png', 'ch10/1.png', 'ch1/1.png']), [
      'ch1/1.png',
      'ch2/1.png',
      'ch10/1.png',
    ]);
  });

  test('zero padding ties break consistently', () {
    expect(naturalSorted(['01', '1', '001']), ['1', '01', '001']);
  });

  test('extensions', () {
    expect(extensionOf('a/b/Page.JPG'), 'jpg');
    expect(extensionOf('.hidden'), '');
    expect(isImagePath('x.webp'), isTrue);
    expect(isImagePath('x.txt'), isFalse);
    expect(isArchivePath('Vol 1.cbz'), isTrue);
    expect(withoutExtension('Vol 1.cbz'), 'Vol 1');
    expect(basename('a\\b\\c.png'), 'c.png');
  });

  group('groupArchiveEntries', () {
    test('flat archive is one chapter', () {
      final g = groupArchiveEntries([
        '10.jpg',
        '2.jpg',
        '1.jpg',
      ], rootName: 'Vol1');
      expect(g, {
        'Vol1': ['1.jpg', '2.jpg', '10.jpg'],
      });
    });

    test('single wrapper folder is the chapter', () {
      final g = groupArchiveEntries(['Ch1/2.jpg', 'Ch1/1.jpg', 'Ch1/']);
      expect(g, {
        'Ch1': ['Ch1/1.jpg', 'Ch1/2.jpg'],
      });
    });

    test('folders become chapters, wrapper looked through', () {
      final g = groupArchiveEntries([
        'Vol/ch10/1.png',
        'Vol/ch2/2.png',
        'Vol/ch2/1.png',
        'Vol/ch1/1.png',
      ]);
      expect(g.keys, ['ch1', 'ch2', 'ch10']);
      expect(g['ch2'], ['Vol/ch2/1.png', 'Vol/ch2/2.png']);
    });

    test('junk and non-images are skipped', () {
      final g = groupArchiveEntries([
        '__MACOSX/._1.jpg',
        '.DS_Store',
        'ComicInfo.xml',
        '1.jpg',
      ], rootName: 'R');
      expect(g, {
        'R': ['1.jpg'],
      });
    });

    test('root files beside folders form their own chapter', () {
      final g = groupArchiveEntries([
        'cover.jpg',
        'a/1.jpg',
      ], rootName: 'Extras');
      expect(g.keys.toSet(), {'Extras', 'a'});
    });

    test('backslash paths are normalised', () {
      final g = groupArchiveEntries(['ch1\\1.jpg', 'ch2\\1.jpg']);
      expect(g.keys, ['ch1', 'ch2']);
    });

    test('nothing usable gives nothing', () {
      expect(groupArchiveEntries(['readme.txt']), isEmpty);
    });
  });
}
