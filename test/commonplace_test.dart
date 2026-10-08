import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manabee/main.dart';
import 'package:manabee/models.dart';
import 'package:manabee/services/dictionary.dart';
import 'package:manabee/services/store.dart';

/// Answers like the real one would for the days of the week, in either
/// Japanese or English.
class FakeDictionary implements Dictionary {
  static const days = {'月曜日': ('げつようび', 'Monday'), '火曜日': ('かようび', 'Tuesday')};

  @override
  Future<List<Entry>> lookup(String q) async => [
    for (final MapEntry(key: word, value: (reading, english)) in days.entries)
      if (q == word || q.toLowerCase() == english.toLowerCase())
        Entry(
          word: word,
          reading: reading,
          jlpt: 'N5',
          senses: [
            Sense(glosses: [english]),
          ],
        ),
  ];
}

void main() {
  test('commonplace books are saved as such and kept off the shelf', () async {
    final storage = MemoryStorage();
    final lib = Library(storage);
    lib.upsertManga(Manga(id: 'y', title: 'Yotsuba'));
    final book = lib.addCommonplaceBook('Days of the week');
    await lib.save();

    final again = Library(storage);
    await again.load();
    expect(again.mangaById(book.id)!.commonplace, isTrue);
    expect(again.mangaById('y')!.commonplace, isFalse);
    expect(again.shelf.map((m) => m.title), ['Yotsuba']);
    expect(again.recent, hasLength(2));
    lib.dispose();
    again.dispose();
  });

  testWidgets('make a commonplace book and fill it from the dictionary', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final lib = Library(MemoryStorage());
    await tester.pumpWidget(
      ManabeeApp(library: lib, dictionary: FakeDictionary()),
    );
    await tester.pump();

    // Words tab → the new-book tile.
    await tester.tap(find.byIcon(Icons.chat_bubble_outline_rounded).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Commonplace book'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Days of the week');
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    // Straight into the book: search first, nothing in it yet.
    expect(find.text('Days of the week'), findsOneWidget);
    expect(find.text('In this book'), findsOneWidget);
    expect(find.textContaining('Empty so far'), findsOneWidget);
    expect(find.text('Bubbles'), findsNothing);

    // Japanese…
    await tester.enterText(find.byType(TextField), '月曜日');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    await tester.tap(find.text('げつようび').first);
    await tester.pumpAndSettle();
    // …and English.
    await tester.enterText(find.byType(TextField), 'Tuesday');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    await tester.tap(find.text('かようび').first);
    await tester.pumpAndSettle();

    final book = lib.recent.single;
    expect(book.commonplace, isTrue);
    expect(lib.wordsFor(book.id).map((w) => w.entry.word), ['月曜日', '火曜日']);
    expect(find.textContaining('Empty so far'), findsNothing);

    // Not a manga to read; but a deck to study.
    await tester.tap(find.byIcon(Icons.home_outlined));
    await tester.pumpAndSettle();
    expect(find.text('Your shelf is empty'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.inventory_2_outlined));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(ChoiceChip, '📒 Days of the week'), findsOneWidget);
    await lib.save();
  });
}
