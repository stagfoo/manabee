import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manabee/main.dart';
import 'package:manabee/models.dart';
import 'package:manabee/screens/reader_screen.dart';
import 'package:manabee/services/dictionary.dart';
import 'package:manabee/services/store.dart';
import 'package:manabee/theme.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Dictionary dict;
  late Library lib;
  late Bubble bubble;

  Future<void> open(WidgetTester tester, String text) async {
    dict = (await tester.runAsync(() async {
      sqfliteFfiInit();
      final db = await databaseFactoryFfi.openDatabase(
        File('assets/dict/jmdict.db').absolute.path,
        options: OpenDatabaseOptions(readOnly: true),
      );
      return LocalDictionary.fromDatabase(db);
    }))!;
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    lib = Library(MemoryStorage());
    final m = Manga(
      id: 'm',
      title: 'Yotsuba',
      chapters: [
        Chapter(id: 'c', title: '01', pages: ['x/1.jpg']),
      ],
    );
    lib.mangas.add(m);
    bubble = Bubble(
      id: 'b',
      chapterId: 'c',
      page: 0,
      position: const Offset(0.5, 0.2),
      source: text,
    );
    m.bubbles.add(bubble);
    await tester.pumpWidget(ManabeeApp(library: lib, dictionary: dict));
    tester
        .state<NavigatorState>(find.byType(Navigator).first)
        .push(
          MaterialPageRoute(
            builder: (_) => const ReaderScreen(mangaId: 'm', chapterIndex: 0),
          ),
        );
    await settle(tester);
    await tester.tap(find.text(text));
    await settle(tester);
  }

  String highlighted(WidgetTester tester) => tester
      .widgetList<Text>(find.byType(Text))
      .where(
        (t) =>
            t.style?.color == C.onLime &&
            t.style?.fontSize == 20 &&
            t.data?.length == 1,
      )
      .map((t) => t.data)
      .join();

  testWidgets('いっばい is read as いっぱい, and the text can be fixed', (
    tester,
  ) async {
    await open(tester, '人がいっばい居る');
    await tester.tap(find.text('い').first);
    await settle(tester);
    expect(highlighted(tester), 'いっばい');
    expect(find.textContaining('Read as', findRichText: true), findsOneWidget);

    await tester.tap(find.text('Fix text'));
    await settle(tester);
    expect(bubble.source, '人がいっぱい居る');
    expect(highlighted(tester), 'いっぱい');
    await lib.save();
  });

  testWidgets('drag the highlight to take in more characters', (tester) async {
    await open(tester, '人がいっぱい居る');
    // Tap 人, then drag from it across to the end of いっぱい.
    await tester.tap(find.text('人'));
    await settle(tester);
    expect(highlighted(tester), '人');
    final from = tester.getCenter(bubbleChar('人'));
    final to = tester.getCenter(bubbleChar('ぱ'));
    final gesture = await tester.startGesture(from);
    await gesture.moveTo(from + const Offset(30, 0));
    await tester.pump();
    await gesture.moveTo(to + const Offset(28, 0)); // past ぱ, onto い
    await tester.pump();
    await gesture.up();
    await settle(tester);
    expect(highlighted(tester), '人がいっぱい');
    await lib.save();
  });
}

/// A character of the bubble's text — not the same character in the search
/// box, the dictionary entry or a chip.
Finder bubbleChar(String c) => find.byWidgetPredicate(
  (w) => w is Text && w.data == c && w.style?.fontSize == 20,
);

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    await tester.runAsync(
      () => Future.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump(const Duration(milliseconds: 20));
  }
}
