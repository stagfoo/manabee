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
}
