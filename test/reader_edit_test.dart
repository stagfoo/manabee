import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manabee/main.dart';
import 'package:manabee/models.dart';
import 'package:manabee/screens/reader_screen.dart';
import 'package:manabee/services/jisho.dart';
import 'package:manabee/services/store.dart';

void main() {
  testWidgets('a hand-placed bubble can be given its Japanese, and merged', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final lib = Library(MemoryStorage());
    final m = Manga(
      id: 'm',
      title: 'nichijou',
      chapters: [
        Chapter(id: 'c', title: '01', pages: ['missing/1.jpg']),
      ],
    );
    lib.mangas.add(m);
    m.bubbles.addAll([
      Bubble(
        id: 'a',
        chapterId: 'c',
        page: 0,
        position: const Offset(0.5, 0.3),
        translation: 'breakfast',
      ),
      Bubble(
        id: 'b',
        chapterId: 'c',
        page: 0,
        position: const Offset(0.5, 0.7),
        source: '作って下さい',
      ),
    ]);

    await tester.pumpWidget(ManabeeApp(library: lib, dictionary: Jisho()));
    tester
        .state<NavigatorState>(find.byType(Navigator).first)
        .push(
          MaterialPageRoute(
            builder: (_) => const ReaderScreen(mangaId: 'm', chapterIndex: 0),
          ),
        );
    // The page file doesn't exist; let the size probe fail for real.
    for (var i = 0; i < 10 && find.text('breakfast').evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      await tester.runAsync(
        () => Future.delayed(const Duration(milliseconds: 50)),
      );
    }
    await tester.pump(const Duration(milliseconds: 500));

    await tester.tap(find.text('breakfast'));
    await tester.pumpAndSettle();
    expect(find.text('Tap to add the Japanese'), findsOneWidget);

    await tester.tap(find.text('Tap to add the Japanese'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(1), '朝食は自分で');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(m.bubbles.first.source, '朝食は自分で');

    // Merge the second bubble into the first.
    await tester.tap(find.byTooltip('Merge with another bubble'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Tap the bubble to merge'), findsOneWidget);
    await tester.tap(find.text('作って下さい').first);
    await tester.pumpAndSettle();
    expect(m.bubbles.length, 1);
    expect(m.bubbles.single.source, '朝食は自分で作って下さい');
    expect(m.bubbles.single.translation, 'breakfast');

    await lib.save();
  });
}
