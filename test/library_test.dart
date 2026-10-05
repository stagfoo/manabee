import 'dart:convert';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:manabee/models.dart';
import 'package:manabee/services/store.dart';

Entry entry(String word, String reading, String meaning) => Entry(
  word: word,
  reading: reading,
  senses: [
    Sense(glosses: [meaning]),
  ],
);

Manga sample() => Manga(
  id: 'm1',
  title: 'Mushishi',
  chapters: [
    Chapter(
      id: 'c1',
      title: '01# Chapter',
      pages: ['a/1.jpg', 'a/2.jpg', 'a/3.jpg'],
    ),
    Chapter(id: 'c2', title: '02# Chapter', pages: ['b/1.jpg', 'b/2.jpg']),
  ],
);

void main() {
  test('library survives a save/load round trip', () async {
    final storage = MemoryStorage();
    final lib = Library(storage);
    final m = sample();
    lib.upsertManga(m);
    lib.addBubble(
      m,
      Bubble(
        id: 'b1',
        chapterId: 'c1',
        page: 0,
        position: const Offset(0.3, 0.4),
        region: const Rect.fromLTRB(0.1, 0.2, 0.3, 0.4),
        source: '若い頃',
        translation: 'when I was young',
      ),
    );
    lib.saveWord(
      'm1',
      entry('若い', 'わかい', 'young'),
      context: '若い頃',
      bubbleId: 'b1',
    );
    lib.markRead(m, 0, 1);
    lib.settings.rightToLeft = false;
    await lib.save();

    final again = Library(storage);
    await again.load();
    final m2 = again.mangaById('m1')!;
    expect(m2.title, 'Mushishi');
    expect(m2.chapters.map((c) => c.pages.length), [3, 2]);
    expect(m2.chapters.first.readUpTo, 1);
    expect(m2.lastPage, 1);
    final b = m2.bubbles.single;
    expect(b.position, const Offset(0.3, 0.4));
    expect(b.region, const Rect.fromLTRB(0.1, 0.2, 0.3, 0.4));
    expect(b.translation, 'when I was young');
    final w = again.words.single;
    expect(w.entry.word, '若い');
    expect(w.context, '若い頃');
    expect(again.settings.rightToLeft, isFalse);
    lib.dispose();
    again.dispose();
  });

  test('a corrupt library loads empty instead of crashing', () async {
    final lib = Library(MemoryStorage('{not json'));
    await lib.load();
    expect(lib.mangas, isEmpty);
    lib.dispose();
  });

  test('saving the same word twice is a no-op', () {
    final lib = Library(MemoryStorage());
    final e = entry('虫', 'むし', 'bug');
    expect(lib.saveWord('m1', e), isTrue);
    lib.answer(lib.words.single, knewIt: true);
    expect(lib.saveWord('m1', e), isFalse);
    expect(lib.words.single.review.box, 1);
    // Same word from another manga is its own card.
    expect(lib.saveWord('m2', e), isTrue);
    expect(lib.wordsFor('m1').length, 1);
    expect(lib.wordsFor(null).length, 2);
    lib.dispose();
  });

  test('reading progress and chapter status', () {
    final m = sample();
    expect(statusOf(m.chapters[0]), ChapterStatus.unread);
    expect(pagesRead(m), 0);
    final lib = Library(MemoryStorage());
    lib.upsertManga(m);
    lib.markRead(m, 0, 1);
    expect(statusOf(m.chapters[0]), ChapterStatus.reading);
    lib.markRead(m, 0, 0);
    // Going back doesn't un-read pages.
    expect(m.chapters[0].readUpTo, 1);
    lib.markRead(m, 0, 2);
    expect(statusOf(m.chapters[0]), ChapterStatus.complete);
    expect(chaptersComplete(m), 1);
    expect(pagesRead(m), 3);
    lib.dispose();
  });

  test('bubble numbering is per page', () {
    final lib = Library(MemoryStorage());
    final m = sample();
    lib.upsertManga(m);
    Bubble b(String id, int page) =>
        Bubble(id: id, chapterId: 'c1', page: page, position: Offset.zero);
    final b1 = b('x', 0), b2 = b('y', 0), b3 = b('z', 1);
    for (final x in [b1, b2, b3]) {
      lib.addBubble(m, x);
    }
    expect(lib.bubbleNumber(m, b2), 2);
    expect(lib.bubbleNumber(m, b3), 1);
    expect(lib.bubbleCount(m, 'c1'), 3);
    lib.removeBubble(m, b1);
    expect(lib.bubbleNumber(m, b2), 1);
    lib.dispose();
  });

  test('cover falls back to the first page', () {
    final m = sample();
    expect(m.coverOrFirstPage, 'a/1.jpg');
    m.cover = 'cover.png';
    expect(m.coverOrFirstPage, 'cover.png');
    expect(Manga(id: 'e', title: 'empty').coverOrFirstPage, isNull);
  });

  test('json is plain and versioned', () {
    final lib = Library(MemoryStorage());
    lib.upsertManga(sample());
    final j = jsonDecode(jsonEncode(lib.toJson())) as Map<String, dynamic>;
    expect(j['version'], 1);
    expect((j['mangas'] as List).length, 1);
    lib.dispose();
  });
}
