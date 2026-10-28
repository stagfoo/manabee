/// The mock test screen: pick a level, answer without being told, then
/// see it marked and keep the misses.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manabee/core/mock_test.dart';
import 'package:manabee/core/sentences.dart';
import 'package:manabee/main.dart';
import 'package:manabee/models.dart';
import 'package:manabee/screens/mock_test_screen.dart';
import 'package:manabee/services/jisho.dart';
import 'package:manabee/services/store.dart';

const _sentence = Sentence(
  id: '1',
  level: 'N5',
  japanese: '学校へ行きます。',
  english: 'I go to school.',
  words: ['学校|がっこう'],
  author: 'amy',
);

MockQuestion q(MockSection section, List<String> options, int answer) =>
    MockQuestion(
      section: section,
      sentence: _sentence,
      start: 0,
      end: 2,
      written: '学校',
      kana: 'がっこう',
      options: options,
      answer: answer,
      entry: const Entry(
        word: '学校',
        reading: 'がっこう',
        jlpt: 'N5',
        senses: [
          Sense(glosses: ['school']),
        ],
      ),
    );

void main() {
  testWidgets('answer, mark, and keep the misses as reading cards', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final lib = Library(MemoryStorage());
    await tester.pumpWidget(ManabeeApp(library: lib, dictionary: Jisho()));
    await tester.pump();
    final nav = tester.state<NavigatorState>(find.byType(Navigator).first);
    nav.push(
      MaterialPageRoute(
        builder: (_) => MockTestScreen(
          build: (_, level) async => [
            q(MockSection.reading, ['がこう', 'がっこう', 'かっこう', 'がっこ'], 1),
            q(MockSection.writing, ['学校', '字校', '学交', '校学'], 0),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('N5'));
    await tester.pump();
    await tester.pump();
    expect(find.text('How is the underlined word read?'), findsOneWidget);

    // Right, and nothing says so yet.
    await tester.tap(find.text('がっこう'));
    await tester.pump();
    await tester.tap(find.text('Next'));
    await tester.pump();
    expect(find.text('How is the underlined word written?'), findsOneWidget);

    // Wrong.
    await tester.tap(find.text('字校'));
    await tester.pump();
    await tester.tap(find.text('Mark it'));
    await tester.pump();

    expect(find.text('1 / 2'), findsOneWidget);
    expect(lib.mockResults.single.readingRight, 1);
    expect(lib.mockResults.single.writingRight, 0);
    expect(find.text('I go to school.'), findsWidgets);

    await tester.tap(find.text('Study the 1 I missed as reading cards'));
    await tester.pump();
    final book = lib.mangaById('mock-misses')!;
    expect(book.commonplace, isTrue);
    expect(lib.wordsFor(book.id).single.entry.word, '学校');
    expect(lib.cardsFor(book.id, CardSkill.reading), hasLength(1));
    await lib.save();
  });
}
