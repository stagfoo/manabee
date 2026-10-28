import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manabee/core/srs.dart';
import 'package:manabee/main.dart';
import 'package:manabee/models.dart';
import 'package:manabee/screens/flashcards_screen.dart';
import 'package:manabee/services/jisho.dart';
import 'package:manabee/services/store.dart';

Entry entry(String w, String r, String m) => Entry(
  word: w,
  reading: r,
  senses: [
    Sense(glosses: [m]),
  ],
);

void main() {
  testWidgets('the card on screen stays put when another falls due behind it', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final lib = Library(MemoryStorage());
    lib.saveWord('m', entry('森', 'もり', 'forest'));
    lib.saveWord('m', entry('朝', 'あさ', 'morning'));
    // 朝 is mid-learning, due a moment from now: not yet, so 森 (new)
    // comes up first.
    final asa = lib.words.firstWhere((w) => w.entry.word == '朝');
    lib.setCard(
      CardSkill.reading,
      asa.id,
      ReviewState(
        step: 0,
        due: DateTime.now().add(const Duration(seconds: 2)),
        introduced: DateTime.now(),
      ),
    );
    await tester.pumpWidget(ManabeeApp(library: lib, dictionary: Jisho()));
    tester
        .state<NavigatorState>(find.byType(Navigator).first)
        .push(
          MaterialPageRoute(
            builder: (_) => const FlashcardsScreen(skill: CardSkill.reading),
          ),
        );
    await tester.pumpAndSettle();
    expect(find.text('森'), findsOneWidget);

    // 朝 falls due while 森 is being looked at.
    await tester.runAsync(
      () => Future.delayed(const Duration(milliseconds: 2500)),
    );
    await tester.tap(find.text('Show answer'));
    await tester.pumpAndSettle();
    // Still 森, now with its answer — not 朝.
    expect(find.text('森'), findsOneWidget);
    expect(find.text('forest'), findsOneWidget);
    expect(find.text('朝'), findsNothing);

    // Graded, the overdue 朝 comes next.
    await tester.tap(find.text('Good'));
    await tester.pumpAndSettle();
    expect(find.text('朝'), findsOneWidget);
  });
}
