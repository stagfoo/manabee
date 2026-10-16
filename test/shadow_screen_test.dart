import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manabee/main.dart';
import 'package:manabee/models.dart';
import 'package:manabee/screens/shadow_screen.dart';
import 'package:manabee/services/jisho.dart';
import 'package:manabee/services/shadow_audio.dart';
import 'package:manabee/services/store.dart';

/// Audio without a microphone: records what was asked of it.
class FakeShadowAudio implements ShadowAudio {
  final calls = <String>[];
  bool allowMic = true;

  @override
  Future<bool> startRecording() async {
    calls.add('record');
    return allowMic;
  }

  @override
  Future<bool> stopRecording() async {
    calls.add('stop');
    return true;
  }

  @override
  Future<void> playYours() async => calls.add('yours');

  @override
  Future<String?> playNative(String text) async {
    calls.add('native:$text');
    return null;
  }

  @override
  Future<void> stopAll() async {}

  @override
  void dispose() {}
}

Entry entry(String w, String r, String m) => Entry(
  word: w,
  reading: r,
  senses: [
    Sense(glosses: [m]),
  ],
);

void main() {
  testWidgets('hear it, record, compare, grade — on its own schedule', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final lib = Library(MemoryStorage());
    // One word saved from a bubble, one not: both are shadowed as words.
    lib.saveWord('m', entry('若い', 'わかい', 'young'), context: '若い頃の記憶');
    lib.saveWord('m', entry('森', 'もり', 'forest'));
    final audio = FakeShadowAudio();

    await tester.pumpWidget(ManabeeApp(library: lib, dictionary: Jisho()));
    tester
        .state<NavigatorState>(find.byType(Navigator).first)
        .push(MaterialPageRoute(builder: (_) => ShadowScreen(audio: audio)));
    await tester.pumpAndSettle();

    // The word, played on arrival — not the (unchecked) bubble sentence.
    expect(find.text('SAY THE WORD'), findsOneWidget);
    expect(find.text('若い頃の記憶'), findsNothing);
    expect(audio.calls, ['native:わかい']);
    // Nothing of yours to play yet.
    final you = find.widgetWithText(OutlinedButton, '▶  You');
    expect(tester.widget<OutlinedButton>(you).onPressed, isNull);

    await tester.tap(find.bySemanticsLabel('Record'));
    await tester.pumpAndSettle();
    expect(find.text('Recording — tap to stop'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Stop recording'));
    await tester.pumpAndSettle();
    // Played straight back, and now replayable beside the native.
    expect(audio.calls.sublist(1), ['record', 'stop', 'yours']);
    await tester.tap(you);
    await tester.tap(find.widgetWithText(OutlinedButton, '▶  Native'));
    await tester.pumpAndSettle();
    expect(audio.calls.sublist(4), ['yours', 'native:わかい']);

    await tester.tap(find.text('Easy'));
    await tester.pumpAndSettle();
    final wakai = lib.words.first;
    expect(wakai.speaking.intervalDays, 4); // its speaking schedule moved…
    expect(wakai.review.isNew, isTrue); // …its flash cards didn't

    // The next card: also the word, by its reading.
    expect(find.text('SAY THE WORD'), findsOneWidget);
    expect(audio.calls.last, 'native:もり');
    await tester.tap(find.text('Easy'));
    await tester.pumpAndSettle();
    expect(find.text('2 spoken'), findsOneWidget);
    await lib.save();
  });

  testWidgets('a refused microphone says so', (tester) async {
    final lib = Library(MemoryStorage());
    lib.saveWord('m', entry('森', 'もり', 'forest'));
    final audio = FakeShadowAudio()..allowMic = false;
    await tester.pumpWidget(ManabeeApp(library: lib, dictionary: Jisho()));
    tester
        .state<NavigatorState>(find.byType(Navigator).first)
        .push(MaterialPageRoute(builder: (_) => ShadowScreen(audio: audio)));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Record'));
    await tester.pumpAndSettle();
    expect(find.textContaining('microphone'), findsOneWidget);
    await lib.save();
  });
}
