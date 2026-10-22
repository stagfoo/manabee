import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manabee/core/conjugate.dart';
import 'package:manabee/main.dart';
import 'package:manabee/models.dart';
import 'package:manabee/screens/conjugation_screen.dart';
import 'package:manabee/services/jisho.dart';
import 'package:manabee/services/store.dart';

void main() {
  late List<String> spoken;

  Future<void> open(WidgetTester tester, Widget screen, {Library? lib}) async {
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
    await tester.pumpWidget(
      ManabeeApp(library: lib ?? Library(MemoryStorage()), dictionary: Jisho()),
    );
    tester
        .state<NavigatorState>(find.byType(Navigator).first)
        .push(MaterialPageRoute(builder: (_) => screen));
    await tester.pumpAndSettle();
  }

  const taberu = Verb('食べる', 'たべる', VerbGroup.ichidan);

  testWidgets('tap into a branch, hear it, and step back out', (tester) async {
    await open(tester, const ConjugationScreen(verb: taberu));
    // The first ring: ten forms around the dictionary form.
    for (final f in ['食べます', '食べない', '食べた', '食べて', '食べられる']) {
      expect(find.text(f), findsWidgets);
    }
    expect(find.text('食べなかった'), findsNothing);

    await tester.tap(find.text('食べない').first);
    await tester.pumpAndSettle();
    expect(spoken.last, 'たべない');
    expect(find.text('食べなかった'), findsWidgets);
    expect(find.text('食べなきゃ'), findsNothing); // one level further down
    expect(find.text('る → ない'), findsWidgets); // the rule, in the card

    // An end-of-branch form is selected, not opened.
    await tester.tap(find.text('食べなかった').first);
    await tester.pumpAndSettle();
    expect(spoken.last, 'たべなかった');
    expect(find.text('食べなくちゃ'), findsWidgets); // the ring stayed

    // Back out by the route.
    // The route scrolls to keep the current step in view; scroll back.
    await tester.ensureVisible(find.widgetWithText(ActionChip, '食べる'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ActionChip, '食べる'));
    await tester.pumpAndSettle();
    expect(find.text('食べなかった'), findsNothing);
    expect(find.text('食べます'), findsWidgets);
  });

  testWidgets('opened from a word met on the page', (tester) async {
    await open(tester, const ConjugationScreen(verb: taberu, onPage: '食べちゃった'));
    expect(find.text('PAST · CASUAL · ON THE PAGE'), findsOneWidget);
    // The route from the dictionary form, step by step.
    for (final f in ['食べる', '食べて', '食べてしまう', '食べちゃう', '食べちゃった']) {
      expect(find.widgetWithText(ActionChip, f), findsOneWidget);
    }
  });

  testWidgets('verb list: the verbs among your words', (tester) async {
    final lib = Library(MemoryStorage());
    lib.saveWord(
      'm',
      const Entry(
        word: '食べる',
        reading: 'たべる',
        senses: [
          Sense(glosses: ['to eat'], partsOfSpeech: ['Ichidan verb']),
        ],
      ),
    );
    lib.saveWord(
      'm',
      const Entry(
        word: '学校',
        reading: 'がっこう',
        senses: [
          Sense(glosses: ['school'], partsOfSpeech: ['noun (common)']),
        ],
      ),
    );
    await open(tester, const VerbListScreen(), lib: lib);
    expect(find.text('YOUR VERBS · 1'), findsOneWidget);
    await tester.tap(find.text('食べる'));
    await tester.pumpAndSettle();
    expect(find.byType(ConjugationScreen), findsOneWidget);
  });
}
