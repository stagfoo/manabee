import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:manabee/main.dart';
import 'package:manabee/models.dart';
import 'package:manabee/screens/reader_screen.dart';
import 'package:manabee/services/jisho.dart';
import 'package:manabee/services/store.dart';
import 'package:manabee/theme.dart';

/// jisho.org as probed: no exact entry for あそべるよ or あそべる, 遊ぶ for
/// あそぶ.
Jisho fakeJisho(List<String> asked) => Jisho(
  client: MockClient((req) async {
    final q = req.url.queryParameters['keyword']!;
    asked.add(q);
    Map<String, dynamic> entry(String? word, String reading, String gloss) => {
      'japanese': [
        {'word': ?word, 'reading': reading},
      ],
      'senses': [
        {
          'english_definitions': [gloss],
          'parts_of_speech': ['Godan verb'],
        },
      ],
      'jlpt': ['jlpt-n5'],
    };
    final data = switch (q) {
      'あそべるよ' => [entry('世', 'よ', 'world')],
      'あそべる' => [entry('あそべる絵本', '', 'PictureBook Games')],
      'あそぶ' => [entry('遊ぶ', 'あそぶ', 'to play')],
      _ => <Map<String, dynamic>>[],
    };
    return http.Response.bytes(utf8.encode(jsonEncode({'data': data})), 200);
  }),
);

void main() {
  testWidgets('あそべるよ is looked up as 遊ぶ and saved with its sentence', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    const sentence = 'また あとで あそべるよ';
    final lib = Library(MemoryStorage());
    final m = Manga(
      id: 'm',
      title: 'nichijou',
      chapters: [
        Chapter(id: 'c', title: '01', pages: ['missing/1.jpg']),
      ],
    );
    lib.mangas.add(m);
    m.bubbles.add(
      Bubble(
        id: 'b',
        chapterId: 'c',
        page: 0,
        position: const Offset(0.5, 0.3),
        region: const Rect.fromLTRB(0.4, 0.2, 0.6, 0.4),
        source: sentence,
      ),
    );
    final asked = <String>[];
    await tester.pumpWidget(ManabeeApp(library: lib, jisho: fakeJisho(asked)));
    tester
        .state<NavigatorState>(find.byType(Navigator).first)
        .push(
          MaterialPageRoute(
            builder: (_) => const ReaderScreen(mangaId: 'm', chapterIndex: 0),
          ),
        );
    for (var i = 0; i < 10 && find.text(sentence).evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      await tester.runAsync(
        () => Future.delayed(const Duration(milliseconds: 50)),
      );
    }
    await tester.pump(const Duration(milliseconds: 500));

    await tester.tap(find.text(sentence));
    await tester.pumpAndSettle();
    // Tap the あ that starts あそべるよ (the second あ in the sentence).
    await tester.tap(find.text('あ').at(1));
    await tester.runAsync(
      () => Future.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pumpAndSettle();

    expect(asked, containsAll(['あそべるよ', 'あそべる', 'あそぶ']));
    expect(find.text('遊ぶ'), findsWidgets);
    expect(find.textContaining('On the page'), findsOneWidget);
    expect(find.textContaining('potential'), findsOneWidget);
    // Already in the bubble as あそべる — no offer to add 遊ぶ to the text.
    expect(find.textContaining('to bubble'), findsNothing);

    // Save it with the + button.
    await tester.tap(find.byIcon(Icons.add_rounded).last);
    await tester.pumpAndSettle();
    final w = lib.words.single;
    expect(w.entry.word, '遊ぶ');
    expect(w.context, sentence);
    expect(w.surface, 'あそべる');
    // The word is highlighted where it stands: あそべる, not the よ.
    final highlighted = tester
        .widgetList<Text>(find.byType(Text))
        .where((t) => t.style?.color == C.onLime && t.data?.length == 1)
        .map((t) => t.data)
        .join();
    expect(highlighted, 'あそべる');
    expect(w.form, 'potential');
    expect(findInSentence(w.entry, w.context, surface: w.surface), isNotNull);

    await lib.save();
  });

  testWidgets('long-press one character, tap another: looks up that span', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    const sentence = 'また あとで あそべるよ';
    final lib = Library(MemoryStorage());
    final m = Manga(
      id: 'm',
      title: 'nichijou',
      chapters: [
        Chapter(id: 'c', title: '01', pages: ['missing/1.jpg']),
      ],
    );
    lib.mangas.add(m);
    m.bubbles.add(
      Bubble(
        id: 'b',
        chapterId: 'c',
        page: 0,
        position: const Offset(0.5, 0.3),
        source: sentence,
      ),
    );
    final asked = <String>[];
    await tester.pumpWidget(ManabeeApp(library: lib, jisho: fakeJisho(asked)));
    tester
        .state<NavigatorState>(find.byType(Navigator).first)
        .push(
          MaterialPageRoute(
            builder: (_) => const ReaderScreen(mangaId: 'm', chapterIndex: 0),
          ),
        );
    for (var i = 0; i < 10 && find.text(sentence).evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      await tester.runAsync(
        () => Future.delayed(const Duration(milliseconds: 50)),
      );
    }
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text(sentence));
    await tester.pumpAndSettle();

    await tester.longPress(find.text('ま'));
    await tester.pumpAndSettle();
    expect(find.text('Now tap where the word ends.'), findsOneWidget);
    await tester.tap(find.text('た'));
    await tester.runAsync(
      () => Future.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();

    expect(asked, contains('また'));
    final highlighted = tester
        .widgetList<Text>(find.byType(Text))
        .where((t) => t.style?.color == C.onLime && t.data?.length == 1)
        .map((t) => t.data)
        .join();
    expect(highlighted, 'また');
    await lib.save();
  });
}
