import 'dart:convert';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:manabee/core/srs.dart';
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
    final answered = lib.words.single.review.answer(Grade.good, DateTime.now());
    lib.setReview(lib.words.single.id, answered);
    expect(lib.saveWord('m1', e), isFalse);
    expect(lib.words.single.review, answered);
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

  test('new cards per day is shared across decks', () {
    final lib = Library(MemoryStorage());
    lib.settings.newPerDay = 3;
    for (final w in ['虫', '朝', '森', '光']) {
      lib.saveWord(w == '光' ? 'm2' : 'm1', entry(w, '', w));
    }
    expect(lib.dueToday('m1').newCards, 3);
    final now = DateTime.now();
    lib.setReview(lib.words[0].id, lib.words[0].review.answer(Grade.good, now));
    lib.setReview(lib.words[1].id, lib.words[1].review.answer(Grade.good, now));
    expect(lib.newAllowanceToday(now), 1);
    expect(lib.dueToday('m2').newCards, 1);
    expect(lib.dueToday(null).learning, 2);
    lib.dispose();
  });

  test('settings keep the daily new-card limit', () async {
    final storage = MemoryStorage();
    final lib = Library(storage)..settings.newPerDay = 7;
    await lib.save();
    final again = Library(storage);
    await again.load();
    expect(again.settings.newPerDay, 7);
    lib.dispose();
    again.dispose();
  });

  group('a word only keeps a sentence it is in', () {
    final tsuku = entry('着く', 'つく', 'to arrive');
    final tsukuru = entry('作る', 'つくる', 'to make');
    const sentence = '朝食は自分で作って下さい!';

    test('findInSentence matches plain and conjugated forms', () {
      expect(findInSentence(tsuku, sentence), isNull);
      expect(findInSentence(tsukuru, sentence), (6, 7)); // 作 of 作って
      expect(findInSentence(entry('自分', 'じぶん', 'self'), sentence), (3, 5));
      expect(
        findInSentence(entry('いってきます', 'いってきます', ''), 'いってきまーす'),
        isNotNull,
      );
      expect(findInSentence(tsuku, ''), isNull);
      // Written in kana on the page: found by the reading's stem, or by the
      // exact form seen when that's known.
      final asobu = entry('遊ぶ', 'あそぶ', 'to play');
      expect(findInSentence(asobu, 'また あとで あそべるよ'), (7, 9));
      expect(findInSentence(asobu, 'また あとで あそべるよ', surface: 'あそべる'), (7, 11));
    });

    test('saving with another bubble selected stores no sentence', () {
      final lib = Library(MemoryStorage());
      lib.saveWord('m', tsuku, context: sentence, bubbleId: 'b1');
      lib.saveWord('m', tsukuru, context: sentence, bubbleId: 'b1');
      expect(lib.words[0].context, '');
      expect(lib.words[0].bubbleId, isNull);
      expect(lib.words[1].context, sentence);
      expect(lib.words[1].bubbleId, 'b1');
      lib.dispose();
    });
  });
}
