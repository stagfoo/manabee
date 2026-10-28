import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manabee/main.dart';
import 'package:manabee/models.dart';
import 'package:manabee/screens/listen_screen.dart';
import 'package:manabee/screens/quiz_screen.dart';
import 'package:manabee/screens/study_screen.dart';
import 'package:manabee/services/jisho.dart';
import 'package:manabee/services/store.dart';

Entry entry(String w, String m) => Entry(
  word: w,
  reading: w,
  senses: [
    Sense(glosses: [m]),
  ],
);

void main() {
  Future<Library> open(WidgetTester tester, {required bool focus}) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('flutter_tts'),
      (call) async => call.method == 'getLanguages' ? ['ja-JP'] : 1,
    );
    final lib = Library(MemoryStorage());
    for (var i = 0; i < 12; i++) {
      lib.saveWord('m', entry('ことば$i', 'word $i'));
    }
    if (focus) {
      lib.setFocus({for (final w in lib.words.take(5)) w.id});
    }
    await tester.pumpWidget(ManabeeApp(library: lib, dictionary: Jisho()));
    tester
        .state<NavigatorState>(find.byType(Navigator).first)
        .push(MaterialPageRoute(builder: (_) => const StudyScreen()));
    await tester.pumpAndSettle();
    // Study a different deck at the top: Listening ignores it.
    await tester.tap(find.text('All words'));
    await tester.pumpAndSettle();
    return lib;
  }

  /// The page itself, not the row of deck chips.
  final page = find.byWidgetPredicate(
    (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
  );

  Future<void> tapTile(WidgetTester tester, String title) async {
    await tester.scrollUntilVisible(
      find.text(title),
      200,
      scrollable: page.first,
    );
    await tester.ensureVisible(find.text(title));
    await tester.pumpAndSettle();
    await tester.tap(find.text(title));
    await tester.pumpAndSettle();
  }

  testWidgets('Listening uses the focus words, whatever deck is picked', (
    tester,
  ) async {
    await open(tester, focus: true);
    await tester.scrollUntilVisible(
      find.text('Practice below uses your 5 focus words.'),
      200,
      scrollable: page.first,
    );
    await tapTile(tester, 'Listen');
    expect(
      tester.widget<ListenScreen>(find.byType(ListenScreen)).mangaId,
      kFocusDeck,
    );
    Navigator.of(tester.element(find.byType(ListenScreen))).pop();
    await tester.pumpAndSettle();
    await tapTile(tester, 'Listening Quiz');
    final quiz = tester.widget<QuizScreen>(find.byType(QuizScreen));
    expect(quiz.mangaId, kFocusDeck);
    expect(quiz.audio, isTrue);
  });

  testWidgets('with no focus set, Listening follows the deck', (tester) async {
    await open(tester, focus: false);
    await tapTile(tester, 'Listen');
    expect(
      tester.widget<ListenScreen>(find.byType(ListenScreen)).mangaId,
      isNull,
    );
  });
}
