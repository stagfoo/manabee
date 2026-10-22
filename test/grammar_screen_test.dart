import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manabee/core/conjugate.dart';
import 'package:manabee/core/srs.dart';
import 'package:manabee/main.dart';
import 'package:manabee/screens/conjugation_screen.dart';
import 'package:manabee/screens/grammar_screen.dart';
import 'package:manabee/services/jisho.dart';
import 'package:manabee/services/store.dart';

void main() {
  late Library lib;
  late List<String> spoken;

  Future<void> open(WidgetTester tester, Widget screen) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    spoken = [];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('flutter_tts'),
      (call) async {
        if (call.method == 'getLanguages') return ['ja-JP', 'en-US'];
        if (call.method == 'speak') spoken.add(call.arguments as String);
        return 1;
      },
    );
    lib = Library(MemoryStorage());
    await tester.pumpWidget(ManabeeApp(library: lib, dictionary: Jisho()));
    tester
        .state<NavigatorState>(find.byType(Navigator).first)
        .push(MaterialPageRoute(builder: (_) => screen));
    await tester.pumpAndSettle();
  }

  /// Answers the question on screen with its first choice, then moves on.
  Future<void> answerAndNext(WidgetTester tester) async {
    final choice = find.byWidgetPredicate(
      (w) => w is InkWell && w.borderRadius == BorderRadius.circular(12),
    );
    await tester.tap(choice.first);
    await tester.pumpAndSettle();
    final next = find.text('Next').evaluate().isNotEmpty
        ? find.text('Next')
        : find.text('Finish');
    await tester.ensureVisible(next);
    await tester.pumpAndSettle();
    await tester.tap(next);
    await tester.pumpAndSettle();
  }

  testWidgets('a particle session: ten rules, graded, then a summary', (
    tester,
  ) async {
    await open(tester, const GrammarScreen(drill: Drill.particles));
    expect(find.text('1 / 10'), findsOneWidget);
    expect(find.textContaining('＿', findRichText: true), findsOneWidget);
    for (var i = 0; i < 10; i++) {
      await answerAndNext(tester);
    }
    expect(find.text('Another round'), findsOneWidget);
    expect(find.textContaining(' / 10'), findsOneWidget);
    // Each rule answered got a schedule.
    expect(lib.grammar, hasLength(10));
    expect(spoken, hasLength(10));
  });

  testWidgets('joining: feedback names the form, and links to the map', (
    tester,
  ) async {
    await open(tester, const GrammarScreen(drill: Drill.joining));
    final choice = find.byWidgetPredicate(
      (w) => w is InkWell && w.borderRadius == BorderRadius.circular(12),
    );
    await tester.tap(choice.first);
    await tester.pumpAndSettle();
    expect(find.textContaining('attaches to the'), findsOneWidget);
    final link = find.textContaining('on the verb map');
    await tester.ensureVisible(link);
    await tester.pumpAndSettle();
    await tester.tap(link);
    await tester.pumpAndSettle();
    expect(find.byType(ConjugationScreen), findsOneWidget);
  });

  testWidgets('the rules list shows every rule', (tester) async {
    await open(tester, const GrammarScreen(drill: Drill.particles));
    await tester.tap(find.text('Rules'));
    await tester.pumpAndSettle();
    expect(find.text('Particle rules'), findsOneWidget);
    expect(find.textContaining('the thing acted on'), findsOneWidget);
  });

  testWidgets('verb map: add a form as its own card', (tester) async {
    await open(
      tester,
      const ConjugationScreen(
        verb: Verb('食べる', 'たべる', VerbGroup.ichidan),
        meaning: 'to eat',
      ),
    );
    // The dictionary form is the word itself: nothing to add.
    expect(find.text('Add'), findsNothing);
    await tester.tap(find.text('食べない').first);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Add'));
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();
    final w = lib.wordsFor(kVerbFormBookId).single;
    expect(w.entry.word, '食べない');
    expect(w.entry.reading, 'たべない');
    expect(w.entry.shortMeaning, '食べる (to eat) · negative: not');
    expect(find.text('Added'), findsOneWidget);
    expect(lib.mangas.single.title, 'Verb forms');
  });

  test('sessions take due rules, then new, then the rest', () {
    final now = DateTime(2026, 10, 23, 12);
    final states = {
      'later': ReviewState(
        step: -1,
        intervalDays: 5,
        due: now.add(const Duration(days: 3)),
      ),
      'due': ReviewState(
        step: -1,
        intervalDays: 1,
        due: now.subtract(const Duration(hours: 1)),
      ),
    };
    ReviewState st(String id) => states[id] ?? const ReviewState();
    expect(rulesInOrder(['later', 'new1', 'due', 'new2'], st, now), [
      'due',
      'new1',
      'new2',
      'later',
    ]);
  });
}
