import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manabee/main.dart';
import 'package:manabee/models.dart';
import 'package:manabee/screens/diary_screen.dart';
import 'package:manabee/screens/match_screen.dart';
import 'package:manabee/screens/quiz_screen.dart';
import 'package:manabee/services/dictionary.dart';
import 'package:manabee/services/speech.dart';
import 'package:manabee/services/store.dart';

/// A small dictionary that knows a particle from a noun.
class FakeDictionary implements Dictionary {
  @override
  Future<List<Entry>> jlptWords(String level) async => const [];

  static const _words = {
    '私': ('わたし', 'I', 'pronoun'),
    '学生': ('がくせい', 'student', 'noun'),
    'です': ('です', 'be', 'copula'),
    'が': ('が', 'subject marker', 'particle'),
  };

  @override
  Future<List<Entry>> lookup(String q) async {
    final w = _words[q];
    if (w == null) return const [];
    return [
      Entry(
        word: q,
        reading: w.$1,
        senses: [
          Sense(glosses: [w.$2], partsOfSpeech: [w.$3]),
        ],
      ),
    ];
  }
}

Entry entry(String w, String r, String m) => Entry(
  word: w,
  reading: r,
  senses: [
    Sense(glosses: [m]),
  ],
);

void main() {
  late List<String> spoken;

  setUp(() => Speech.instance.reset());

  Future<Library> open(WidgetTester tester, Widget screen) async {
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
    final lib = Library(MemoryStorage());
    for (final (w, r, m) in [
      ('若い', 'わかい', 'young'),
      ('森', 'もり', 'forest'),
      ('朝', 'あさ', 'morning'),
      ('猫', 'ねこ', 'cat'),
    ]) {
      lib.saveWord('m', entry(w, r, m));
    }
    await tester.pumpWidget(
      ManabeeApp(library: lib, dictionary: FakeDictionary()),
    );
    tester
        .state<NavigatorState>(find.byType(Navigator).first)
        .push(MaterialPageRoute(builder: (_) => screen));
    await tester.pumpAndSettle();
    return lib;
  }

  testWidgets('listening quiz: heard, not shown, until answered', (
    tester,
  ) async {
    final lib = await open(tester, const QuizScreen(audio: true));
    expect(find.text('WHAT DID YOU HEAR?'), findsOneWidget);
    expect(spoken, hasLength(1));
    final reading = spoken.single;
    // None of the Japanese is on screen yet.
    for (final w in ['若い', '森', '朝', '猫']) {
      expect(find.text(w), findsNothing);
    }
    await tester.tap(find.byTooltip('Hear it again'));
    await tester.pumpAndSettle();
    expect(spoken, [reading, reading]);
    // Options are meanings; answer, and the word appears.
    await tester.tap(
      find.text('young').hitTestable().evaluate().isNotEmpty
          ? find.text('young')
          : find.text('forest'),
    );
    await tester.pumpAndSettle();
    expect(
      ['若い', '森', '朝', '猫'].where((w) => find.text(w).evaluate().isNotEmpty),
      hasLength(1),
    );
    await lib.save();
  });

  testWidgets('listening match: Japanese tiles are sounds', (tester) async {
    final lib = await open(tester, const MatchScreen(audio: true));
    expect(find.bySemanticsLabel('Play'), findsNWidgets(4));
    expect(find.text('若い'), findsNothing);
    await tester.tap(find.bySemanticsLabel('Play').first);
    await tester.pump();
    expect(spoken.single, isIn(['わかい', 'もり', 'あさ', 'ねこ']));
    await lib.save();
  });

  testWidgets('diary: write, check, look a word up and save it', (
    tester,
  ) async {
    final lib = await open(tester, const DiaryScreen());
    await tester.tap(find.text('New entry'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '私がが学生です。');
    await tester.tap(find.text('Check'));
    await tester.pumpAndSettle();

    expect(lib.diary.single.text, '私がが学生です。');
    expect(find.text('「が」 twice in a row.'), findsOneWidget);

    // Tap 学 (the start of 学生) to look it up, and save it.
    await tester.tap(find.text('学'));
    await tester.pumpAndSettle();
    expect(find.text('Save to Diary words'), findsOneWidget);
    await tester.tap(find.text('Save to Diary words'));
    await tester.pumpAndSettle();
    final book = lib.mangaById(kDiaryBookId)!;
    expect(book.commonplace, isTrue);
    expect(lib.wordsFor(book.id).single.entry.word, '学生');
    expect(lib.wordsFor(book.id).single.context, '私がが学生です');
    await lib.save();
  });
}
