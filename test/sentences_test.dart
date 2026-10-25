import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manabee/core/sentences.dart';
import 'package:manabee/main.dart';
import 'package:manabee/models.dart';
import 'package:manabee/screens/sentence_shadow_screen.dart';
import 'package:manabee/services/jisho.dart';
import 'package:manabee/services/shadow_audio.dart';
import 'package:manabee/services/store.dart';

const tsv = '''
1\tN5\t朝ご飯を食べました。\tI ate breakfast.\t朝ご飯|あさごはん,食べる|たべる\tamy
2\tN4\t勉強は順調にいっています。\tMy studies are going well.\t勉強|べんきょう,順調|じゅんちょう,言う|いう\tken
3\tN5\tパンを食べる。\tI eat bread.\t食べる|たべる\tamy
4\tN5\tりんごを食べてください。\tPlease eat an apple.\t林檎|りんご,食べる|たべる\tamy
5\tN4\t明日は学校に行く。\tTomorrow I go to school.\t明日|あした,学校|がっこう,行く|いく\tken
''';

Entry e(String w, String r) => Entry(
  word: w,
  reading: r,
  senses: const [
    Sense(glosses: ['x']),
  ],
);

class FakeAudio implements ShadowAudio {
  final played = <String>[];
  @override
  Future<bool> startRecording() async => true;
  @override
  Future<bool> stopRecording() async => true;
  @override
  Future<void> playYours() async => played.add('yours');
  @override
  Future<String?> playNative(String text) async {
    played.add(text);
    return null;
  }

  @override
  Future<void> stopAll() async {}
  @override
  void dispose() {}
}

void main() {
  final all = parseSentences(tsv);

  test('the bundled sentences parse whole', () {
    final tsvFile = File('assets/sentences/sentences.tsv').readAsStringSync();
    final bundled = parseSentences(tsvFile);
    expect(bundled.length, tsvFile.trim().split('\n').length);
    expect(bundled.length, greaterThan(10000));
    for (final s in bundled) {
      expect(kSentenceLevels, contains(s.level));
      expect(s.author, isNotEmpty);
      expect(s.english, isNotEmpty);
    }
    // Real focus words find real sentences.
    expect(sentencesFor(bundled, [e('食べる', 'たべる')]), hasLength(3));
  });

  test('parse', () {
    expect(all, hasLength(5));
    expect(all.first.words, ['朝ご飯|あさごはん', '食べる|たべる']);
    expect(all.first.key, 'tatoeba:1');
    expect(all.first.source, contains('amy'));
  });

  test('a word is used only where it is listed and visible', () {
    expect(usesWord(all[0], e('食べる', 'たべる')), isTrue);
    // Listed as 言う, but 言 isn't on the page: the segmenter's guess.
    expect(usesWord(all[1], e('言う', 'いう')), isFalse);
    // A kanji word the sentence writes in kana counts: 林檎 as りんご.
    expect(usesWord(all[3], e('りんご', 'りんご')), isTrue);
    expect(wordSpanIn(all[0], e('食べる', 'たべる')), (4, 5));
  });

  test('sentences for focus words: easiest first, each once', () {
    final found = sentencesFor(all, [e('食べる', 'たべる'), e('学校', 'がっこう')]);
    expect(found.map((s) => s.id), ['3', '1', '4', '5']);
    expect(sentencesFor(all, [e('食べる', 'たべる')], perWord: 1).single.id, '3');
    expect(sentencesAt(all, 'N4').map((s) => s.id), ['5', '2']);
  });

  testWidgets('shadow a focus word in its sentences', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final lib = Library(MemoryStorage());
    lib.saveWord('m', e('食べる', 'たべる'));
    lib.setFocus({lib.words.single.id});
    final audio = FakeAudio();
    await tester.pumpWidget(ManabeeApp(library: lib, dictionary: Jisho()));
    tester
        .state<NavigatorState>(find.byType(Navigator).first)
        .push(
          MaterialPageRoute(
            builder: (_) => SentenceShadowScreen(sentences: all, audio: audio),
          ),
        );
    await tester.pumpAndSettle();
    // Easiest first, spoken on arrival, the word lit.
    expect(find.text('パンを食べる。', findRichText: true), findsOneWidget);
    expect(find.text('I eat bread.'), findsOneWidget);
    expect(audio.played, ['パンを食べる。']);
    await tester.tap(find.text('Good'));
    await tester.pumpAndSettle();
    expect(lib.sentenceSpeaking['tatoeba:3'], isNotNull);
    expect(find.text('朝ご飯を食べました。', findRichText: true), findsOneWidget);

    // A level instead.
    await tester.tap(find.text('N4'));
    await tester.pumpAndSettle();
    expect(find.text('明日は学校に行く。', findRichText: true), findsOneWidget);
  });

  testWidgets('no focus words: starts on N5', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ManabeeApp(library: Library(MemoryStorage()), dictionary: Jisho()),
    );
    tester
        .state<NavigatorState>(find.byType(Navigator).first)
        .push(
          MaterialPageRoute(
            builder: (_) =>
                SentenceShadowScreen(sentences: all, audio: FakeAudio()),
          ),
        );
    await tester.pumpAndSettle();
    expect(find.text('SAY THE SENTENCE · N5'), findsOneWidget);
  });
}
