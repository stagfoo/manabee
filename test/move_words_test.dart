import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manabee/core/srs.dart';
import 'package:manabee/main.dart';
import 'package:manabee/models.dart';
import 'package:manabee/screens/words_screen.dart';
import 'package:manabee/services/jisho.dart';
import 'package:manabee/services/store.dart';

Entry entry(String w, String r, String m) => Entry(
  word: w,
  reading: r,
  senses: [
    Sense(glosses: [m]),
  ],
);

final learned = ReviewState(
  step: -1,
  intervalDays: 30,
  reps: 5,
  due: DateTime(2026, 12, 1),
  introduced: DateTime(2026, 1, 1),
);

void main() {
  Library library() {
    final lib = Library(MemoryStorage());
    lib.addCommonplaceBook('A');
    lib.addCommonplaceBook('B');
    return lib;
  }

  String id(Library lib, String title) =>
      lib.mangas.firstWhere((m) => m.title == title).id;

  test('a moved word keeps its progress, and loses only its bubble', () {
    final lib = library();
    final a = id(lib, 'A');
    final b = id(lib, 'B');
    lib.saveWord(a, entry('森', 'もり', 'forest'));
    final w = lib.words.single
      ..review = learned
      ..speaking = learned
      ..focus = true;
    expect(w.id, startsWith(a));
    expect(lib.moveWords([w.id], b), (1, 0));
    final moved = lib.words.single;
    expect(moved.mangaId, b);
    expect(moved.id, Word.idFor(b, moved.entry));
    expect(moved.review.intervalDays, 30);
    expect(moved.speaking.intervalDays, 30);
    expect(moved.focus, isTrue);
    expect(lib.wordsFor(a), isEmpty);
  });

  test('into a book that has it already: merged, further progress kept', () {
    final lib = library();
    final a = id(lib, 'A');
    final b = id(lib, 'B');
    lib.saveWord(a, entry('森', 'もり', 'forest'));
    lib.saveWord(b, entry('森', 'もり', 'forest'));
    lib.wordsFor(a).single.review = learned; // A's card is further along
    lib.wordsFor(b).single.speaking = learned; // B's speaking is
    expect(lib.moveWords([lib.wordsFor(a).single.id], b), (0, 1));
    final w = lib.words.single;
    expect(w.mangaId, b);
    expect(w.review.intervalDays, 30);
    expect(w.speaking.intervalDays, 30);
  });

  testWidgets('move one word, then several into a new book', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final lib = library();
    final a = id(lib, 'A');
    for (final (w, r, m) in [
      ('森', 'もり', 'forest'),
      ('朝', 'あさ', 'morning'),
      ('猫', 'ねこ', 'cat'),
    ]) {
      lib.saveWord(a, entry(w, r, m));
    }
    await tester.pumpWidget(ManabeeApp(library: lib, dictionary: Jisho()));
    tester
        .state<NavigatorState>(find.byType(Navigator).first)
        .push(MaterialPageRoute(builder: (_) => WordsScreen(mangaId: a)));
    await tester.pumpAndSettle();

    // One word, from its sheet, to book B.
    await tester.tap(find.text('森'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Move to another book'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('B'));
    await tester.pumpAndSettle();
    expect(lib.wordsFor(id(lib, 'B')).single.entry.word, '森');
    expect(find.text('森'), findsNothing);

    // The rest, chosen together, into a book made on the way.
    await tester.tap(find.text('Move words…'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Select all'));
    await tester.pumpAndSettle();
    expect(find.text('2 chosen'), findsOneWidget);
    await tester.tap(find.text('Move to…'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('New commonplace book…'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Animals & time');
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();
    expect(
      lib.wordsFor(id(lib, 'Animals & time')).map((w) => w.entry.word).toSet(),
      {'朝', '猫'},
    );
    expect(lib.wordsFor(a), isEmpty);
  });
}
