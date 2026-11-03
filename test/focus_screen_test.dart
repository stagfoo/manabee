import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manabee/core/srs.dart';
import 'package:manabee/main.dart';
import 'package:manabee/models.dart';
import 'package:manabee/services/jisho.dart';
import 'package:manabee/services/store.dart';

Entry entry(String w) => Entry(
  word: w,
  reading: w,
  senses: [
    Sense(glosses: ['meaning of $w']),
  ],
);

void main() {
  test('the focus deck is the ticked words, and moves on 20 at a time', () {
    final lib = Library(MemoryStorage());
    for (var i = 1; i <= 45; i++) {
      lib.saveWord(i <= 30 ? 'yotsuba' : 'book', entry('語$i'));
    }
    expect(lib.wordsFor(kFocusDeck), isEmpty);

    lib.focusNext();
    expect(lib.focusCount, 20);
    expect(lib.wordsFor(kFocusDeck).first.entry.word, '語1');

    lib.focusNext();
    expect(lib.wordsFor(kFocusDeck).map((w) => w.entry.word).first, '語21');
    expect(lib.focusCount, 20);

    // Drawn from one book only.
    lib.focusNext(mangaId: 'book');
    expect(lib.wordsFor(kFocusDeck).every((w) => w.mangaId == 'book'), isTrue);
    expect(lib.focusCount, 15);

    // Learned words are skipped when moving on.
    lib.setFocus({});
    final w1 = lib.words.first;
    lib.setReview(
      w1.id,
      ReviewState(step: -1, intervalDays: 30, due: DateTime(2030), reps: 5),
    );
    lib.focusNext();
    expect(
      lib.wordsFor(kFocusDeck).map((w) => w.entry.word),
      isNot(contains('語1')),
    );
    lib.dispose();
  });

  test('focus survives a save and load', () async {
    final storage = MemoryStorage();
    final lib = Library(storage);
    lib.saveWord('m', entry('若い'));
    lib.saveWord('m', entry('森'));
    lib.toggleFocus(lib.words.last);
    await lib.save();
    final again = Library(storage);
    await again.load();
    expect(again.wordsFor(kFocusDeck).single.entry.word, '森');
    lib.dispose();
    again.dispose();
  });

  testWidgets('choose the next 20, and the Study tab studies just those', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final lib = Library(MemoryStorage());
    for (var i = 1; i <= 37; i++) {
      lib.saveWord('m', entry('語$i'));
    }
    lib.addCommonplaceBook('Days of the week');
    await tester.pumpWidget(ManabeeApp(library: lib, dictionary: Jisho()));
    await tester.tap(find.byIcon(Icons.inventory_2_outlined));
    await tester.pumpAndSettle();

    // The empty commonplace book is a deck already.
    expect(find.text('📒 Days of the week'), findsOneWidget);
    expect(find.text('Study 20'), findsOneWidget); // 37 new, 20 a day

    await tester.tap(find.text('Choose'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next 20'));
    await tester.pumpAndSettle();
    expect(find.text('20 chosen'), findsOneWidget);
    // Untick one.
    await tester.tap(find.text('語1  語1', findRichText: true));
    await tester.pumpAndSettle();
    expect(find.text('19 chosen'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pumpAndSettle();
    expect(find.text('🎯 Focus · 19'), findsOneWidget);
    expect(find.text('Focus: 19 words'), findsOneWidget);
    expect(find.text('Study 19'), findsOneWidget);
    await lib.save();
  });

  test('marking a word known: learned, out of focus, no new card spent', () {
    final lib = Library(MemoryStorage());
    for (var i = 1; i <= 3; i++) {
      lib.saveWord('m', entry('語$i'));
    }
    lib.focusNext();
    final w = lib.words.first;
    final now = DateTime(2026, 11, 4, 9);
    lib.setStatus(w, WordStatus.known, now);
    expect(w.review.learned, isTrue);
    expect(w.review.due, now.add(const Duration(days: kKnownIntervalDays)));
    expect(w.focus, isFalse);
    expect(lib.newAllowanceToday(now), lib.settings.newPerDay);
    expect(wordStatusOf(w.review), WordStatus.known);

    // Next 20 skips it.
    lib.setFocus({});
    lib.focusNext();
    expect(lib.wordsFor(kFocusDeck).map((x) => x.entry.word), ['語2', '語3']);

    // Back to new, and to studying.
    lib.setStatus(w, WordStatus.fresh, now);
    expect(w.review.isNew, isTrue);
    lib.setStatus(w, WordStatus.studying, now);
    expect(wordStatusOf(w.review), WordStatus.studying);
    expect(w.review.isDue(now), isTrue);
    lib.dispose();
  });

  testWidgets('the status select on a focus row', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final lib = Library(MemoryStorage());
    lib.saveWord('m', entry('森'));
    lib.saveWord('m', entry('朝'));
    await tester.pumpWidget(ManabeeApp(library: lib, dictionary: Jisho()));
    await tester.tap(find.byIcon(Icons.inventory_2_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose'));
    await tester.pumpAndSettle();

    expect(find.text('new'), findsNWidgets(2));
    await tester.tap(find.text('new').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Known — I know this already'));
    await tester.pumpAndSettle();
    expect(find.text('known'), findsOneWidget);
    expect(lib.words.first.review.learned, isTrue);
    await lib.save();
  });

  testWidgets('find words to tick by text and status', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final lib = Library(MemoryStorage());
    for (final (w, r, m) in [
      ('食べる', 'たべる', 'to eat'),
      ('飲む', 'のむ', 'to drink'),
      ('森', 'もり', 'forest'),
    ]) {
      lib.saveWord(
        'm',
        Entry(
          word: w,
          reading: r,
          senses: [
            Sense(glosses: [m]),
          ],
        ),
      );
    }
    lib.setStatus(lib.words.last, WordStatus.known);
    await tester.pumpWidget(ManabeeApp(library: lib, dictionary: Jisho()));
    await tester.tap(find.byIcon(Icons.inventory_2_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose'));
    await tester.pumpAndSettle();

    String listed() => ['食べる', '飲む', '森']
        .where(
          (w) => find
              .descendant(
                of: find.byType(CheckboxListTile),
                matching: find.textContaining(w, findRichText: true),
              )
              .evaluate()
              .isNotEmpty,
        )
        .join(',');

    // By meaning, by romaji, by reading.
    await tester.enterText(find.byType(TextField), 'drink');
    await tester.pumpAndSettle();
    expect(listed(), '飲む');
    await tester.enterText(find.byType(TextField), 'taberu');
    await tester.pumpAndSettle();
    expect(listed(), '食べる');
    await tester.enterText(find.byType(TextField), 'もり');
    await tester.pumpAndSettle();
    expect(listed(), '森');

    // By status.
    await tester.enterText(find.byType(TextField), '');
    await tester.tap(find.text('Known'));
    await tester.pumpAndSettle();
    expect(listed(), '森');
    await tester.tap(find.text('New'));
    await tester.pumpAndSettle();
    expect(listed(), '食べる,飲む');
    await lib.save();
  });
}
