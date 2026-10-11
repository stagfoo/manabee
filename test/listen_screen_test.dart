import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manabee/core/srs.dart';
import 'package:manabee/main.dart';
import 'package:manabee/models.dart';
import 'package:manabee/screens/listen_screen.dart';
import 'package:manabee/services/jisho.dart';
import 'package:manabee/services/speech.dart';
import 'package:manabee/services/store.dart';

Entry entry(String word, String reading, List<String> glosses) => Entry(
  word: word,
  reading: reading,
  senses: [Sense(glosses: glosses)],
);

void main() {
  setUp(() => Speech.instance.reset());

  testWidgets(
    'plays Japanese, the meaning in English, then the tone, per word',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      // The phone's text-to-speech, faked: both voices installed, and every
      // call recorded in order.
      final heard = <String>[];
      var language = '';
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('flutter_tts'),
        (call) async {
          switch (call.method) {
            case 'getLanguages':
              return ['ja-JP', 'en-US'];
            case 'setLanguage':
              language = call.arguments as String;
            case 'speak':
              heard.add('$language:${call.arguments}');
          }
          return 1;
        },
      );

      final lib = Library(MemoryStorage())
        ..settings.listenThinkSeconds = 0.5
        ..settings.listenLoop = false
        ..settings.listenOrder = 'saved'
        ..settings.listenRepeats = false;
      lib.saveWord('m', entry('若い', 'わかい', ['young', 'youthful']));
      lib.saveWord('m', entry('遊ぶ', 'あそぶ', ['to play (games, sports)']));

      await tester.pumpWidget(ManabeeApp(library: lib, dictionary: Jisho()));
      tester
          .state<NavigatorState>(find.byType(Navigator).first)
          .push(
            MaterialPageRoute(
              builder: (_) =>
                  ListenScreen(playTone: () async => heard.add('tone')),
            ),
          );
      await tester.pumpAndSettle();
      expect(find.text('若い'), findsOneWidget);
      expect(find.text('Listen  1 / 2'), findsOneWidget);

      await tester.tap(find.byTooltip('Play'));
      for (var i = 0; i < 60; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(heard, [
        'ja-JP:わかい',
        'en-US:young, youthful',
        'tone',
        'ja-JP:あそぶ',
        'en-US:to play',
        'tone',
      ]);
      // Finished, not looping: back to a play button.
      expect(find.byTooltip('Play'), findsOneWidget);
      await lib.save();
    },
  );

  testWidgets('chime before, meaning first: the order the options promise', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final heard = <String>[];
    var language = '';
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('flutter_tts'),
      (call) async {
        switch (call.method) {
          case 'getLanguages':
            return ['ja-JP', 'en-US'];
          case 'setLanguage':
            language = call.arguments as String;
          case 'speak':
            heard.add('$language:${call.arguments}');
        }
        return 1;
      },
    );
    final lib = Library(MemoryStorage())
      ..settings.listenThinkSeconds = 0.5
      ..settings.listenToneBefore = true
      ..settings.listenMeaningFirst = true
      ..settings.listenOrder = 'saved'
      ..settings.listenRepeats = false;
    lib.saveWord('m', entry('若い', 'わかい', ['young']));
    lib.saveWord('m', entry('遊ぶ', 'あそぶ', ['to play']));
    await tester.pumpWidget(ManabeeApp(library: lib, dictionary: Jisho()));
    tester
        .state<NavigatorState>(find.byType(Navigator).first)
        .push(
          MaterialPageRoute(
            builder: (_) =>
                ListenScreen(playTone: () async => heard.add('tone')),
          ),
        );
    await tester.pumpAndSettle();
    // The options, in their sheet, show what's set.
    await tester.tap(find.byTooltip('Options'));
    await tester.pumpAndSettle();
    expect(find.text('Before word'), findsOneWidget);
    expect(find.text('Meaning'), findsOneWidget);
    expect(find.text('As saved'), findsOneWidget);
    await tester.tapAt(const Offset(10, 10)); // close the sheet
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Play'));
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(heard, [
      'tone',
      'en-US:young',
      'ja-JP:わかい',
      'tone',
      'en-US:to play',
      'ja-JP:あそぶ',
    ]);
    await lib.save();
  });

  testWidgets('weakest first, new words repeated, the sentence after', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final heard = <String>[];
    var language = '';
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('flutter_tts'),
      (call) async {
        switch (call.method) {
          case 'getLanguages':
            return ['ja-JP', 'en-US'];
          case 'setLanguage':
            language = call.arguments as String;
          case 'speak':
            heard.add('$language:${call.arguments}');
        }
        return 1;
      },
    );
    final lib = Library(MemoryStorage())
      ..settings.listenThinkSeconds = 0.5
      ..settings.listenOrder = 'weakest';
    // A learned word saved first, a new one second: the new one plays
    // first, and comes back twice.
    lib.saveWord('m', entry('森', 'もり', ['forest']));
    lib.setReview(
      lib.words.first.id,
      ReviewState(step: -1, intervalDays: 20, reps: 4, due: DateTime(2030)),
    );
    lib.saveWord('m', entry('若い', 'わかい', ['young']), context: '若い頃の記憶');

    await tester.pumpWidget(ManabeeApp(library: lib, dictionary: Jisho()));
    tester
        .state<NavigatorState>(find.byType(Navigator).first)
        .push(
          MaterialPageRoute(
            builder: (_) =>
                ListenScreen(playTone: () async => heard.add('tone'), seed: 1),
          ),
        );
    await tester.pumpAndSettle();
    expect(find.text('Listen  1 / 4'), findsOneWidget); // 2 words, 2 repeats

    await tester.tap(find.byTooltip('Play'));
    for (var i = 0; i < 160; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    final japanese = heard.where((h) => h.startsWith('ja-JP')).toList();
    expect(japanese.first, 'ja-JP:わかい');
    expect(japanese.where((h) => h == 'ja-JP:わかい'), hasLength(3));
    expect(japanese.where((h) => h == 'ja-JP:もり'), hasLength(1));
    // Its sentence after it, each time; the learned word has none.
    expect(japanese.where((h) => h == 'ja-JP:若い頃の記憶'), hasLength(3));
    expect(heard.where((h) => h == 'tone'), hasLength(4));
    await lib.save();
  });

  testWidgets('without a Japanese voice it says so and stops', (tester) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('flutter_tts'),
      (call) async => call.method == 'getLanguages' ? ['en-US'] : 1,
    );
    final lib = Library(MemoryStorage());
    lib.saveWord('m', entry('若い', 'わかい', ['young']));
    await tester.pumpWidget(ManabeeApp(library: lib, dictionary: Jisho()));
    tester
        .state<NavigatorState>(find.byType(Navigator).first)
        .push(MaterialPageRoute(builder: (_) => const ListenScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Play'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.textContaining('No Japanese voice'), findsOneWidget);
    expect(find.byTooltip('Play'), findsOneWidget);
    await tester.pumpAndSettle();
    await lib.save();
  });
}
