import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manabee/core/srs.dart';
import 'package:manabee/main.dart';
import 'package:manabee/models.dart';
import 'package:manabee/screens/flashcards_screen.dart';
import 'package:manabee/services/jisho.dart';
import 'package:manabee/services/store.dart';
import 'package:manabee/widgets/confetti.dart';

Future<Library> pump(
  WidgetTester tester, [
  void Function(Library)? seed,
]) async {
  // A phone, not the default 800×600 landscape test window.
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final lib = Library(MemoryStorage());
  seed?.call(lib);
  await tester.pumpWidget(ManabeeApp(library: lib, jisho: Jisho()));
  await tester.pump();
  return lib;
}

Entry wakai() => const Entry(
  word: '若い',
  reading: 'わかい',
  senses: [
    Sense(glosses: ['young', 'youthful'], partsOfSpeech: ['I-adjective']),
  ],
  common: true,
  jlpt: 'N5',
);

void main() {
  testWidgets('empty library offers an import', (tester) async {
    await pump(tester);
    expect(find.text('Your shelf is empty'), findsOneWidget);
    expect(find.text('+ import a manga'), findsOneWidget);
  });

  testWidgets('dock switches tabs', (tester) async {
    await pump(tester);
    await tester.tap(find.byIcon(Icons.inventory_2_outlined));
    await tester.pumpAndSettle();
    expect(find.text('No flash cards yet.'), findsOneWidget);
    expect(find.text('Practice'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.chat_bubble_outline_rounded).last);
    await tester.pumpAndSettle();
    expect(find.text('No words yet'), findsOneWidget);
  });

  testWidgets('a manga shows on the shelf with its progress', (tester) async {
    await pump(tester, (lib) {
      lib.mangas.add(
        Manga(
          id: 'm',
          title: 'Mushishi',
          chapters: [
            Chapter(
              id: 'c',
              title: '01# Chapter',
              pages: ['x/1.jpg', 'x/2.jpg'],
              readUpTo: 1,
            ),
          ],
        ),
      );
    });
    expect(find.text('Mushishi'), findsOneWidget);
    expect(find.text('Chapter 1 of 1 Completed'), findsOneWidget);
  });

  testWidgets('study tab shows today\'s counts and opens a session', (
    tester,
  ) async {
    final lib = await pump(tester, (lib) => lib.saveWord('m', wakai()));
    await tester.tap(find.byIcon(Icons.inventory_2_outlined));
    await tester.pumpAndSettle();
    expect(find.text('Due today'), findsOneWidget);
    expect(find.text('Study 1'), findsOneWidget);
    await tester.tap(find.text('Study 1'));
    await tester.pumpAndSettle();
    expect(find.text('Show answer'), findsOneWidget);
    // Full screen, above the dock.
    expect(find.byIcon(Icons.inventory_2_outlined), findsNothing);
    await lib.save();
  });

  testWidgets('flash card: question, answer under a rule, grade, undo', (
    tester,
  ) async {
    final lib = await pump(tester, (lib) => lib.saveWord('m', wakai()));
    final nav = tester.state<NavigatorState>(find.byType(Navigator).first);
    nav.push(MaterialPageRoute(builder: (_) => const FlashcardsScreen()));
    await tester.pumpAndSettle();

    // Question side: the word and its level, nothing that gives it away.
    expect(find.text('若い'), findsOneWidget);
    expect(find.text('N5'), findsOneWidget);
    expect(find.text('wakai'), findsNothing);
    expect(find.text('young; youthful'), findsNothing);
    expect(find.text('0 / 1'), findsOneWidget);
    // The speaker sits beside Show answer, not up in the app bar.
    final say = tester.getCenter(find.byTooltip('Say it'));
    final show = tester.getCenter(find.text('Show answer'));
    expect((say.dy - show.dy).abs(), lessThan(4));
    expect(say.dx, greaterThan(show.dx));
    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.byTooltip('Say it'),
      ),
      findsNothing,
    );

    await tester.tap(find.text('Show answer'));
    await tester.pumpAndSettle();
    expect(find.text('若い'), findsOneWidget);
    expect(find.text('わかい'), findsOneWidget);
    expect(find.text('wakai'), findsOneWidget);
    expect(find.text('young; youthful'), findsOneWidget);
    // Each button carries the interval it would give a brand-new card.
    expect(find.text('Again'), findsOneWidget);
    expect(find.text('1m'), findsNWidgets(2)); // Again, Hard
    expect(find.text('10m'), findsOneWidget); // Good
    expect(find.text('4d'), findsOneWidget); // Easy

    await tester.tap(find.text('Good'));
    await tester.pumpAndSettle();
    expect(lib.words.single.review.isLearning, isTrue);
    // Nothing else to study, so the learning card is shown again early.
    expect(find.text('Show answer'), findsOneWidget);

    await tester.tap(find.byTooltip('Undo'));
    await tester.pumpAndSettle();
    expect(lib.words.single.review.isNew, isTrue);

    await tester.tap(find.text('Easy'));
    await tester.pumpAndSettle();
    expect(lib.words.single.review.intervalDays, kEasyIntervalDays);
    expect(find.text('1 reviewed'), findsOneWidget);
    expect(find.byType(Confetti), findsOneWidget);
    expect(find.textContaining('Congratulations'), findsOneWidget);

    await lib.save();
  });
}
