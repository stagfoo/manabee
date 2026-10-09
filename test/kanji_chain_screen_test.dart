import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manabee/core/kanji_chain.dart';
import 'package:manabee/core/slingshot.dart';
import 'package:manabee/screens/kanji_chain_screen.dart';
import 'package:manabee/theme.dart';

Combo c(String k, String a, String b) =>
    Combo(kanji: k, a: a, b: b, grade: 1, meanings: ['$k meaning']);

final book = ComboBook([
  c('林', '木', '木'),
  c('森', '木', '林'),
  c('明', '日', '月'),
  c('男', '田', '力'),
]);

void main() {
  late Size area;
  late Offset areaTopLeft;

  ChainGame? game;

  Future<ChainGame> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        home: KanjiChainScreen(book: book, seed: 7, onStart: (g) => game = g),
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));
    final grid = find.byKey(const ValueKey('play-area'));
    area = tester.getSize(grid);
    areaTopLeft = tester.getTopLeft(grid);
    return game!;
  }

  testWidgets('aim at a part that combines, let go, and it merges', (
    tester,
  ) async {
    final game = await open(tester);
    expect(game.goodSlots, isNotEmpty);
    final slot = game.goodSlots.first;
    final ammo = game.ammo;
    final made = book.combine(ammo, game.board[slot]!.glyph)!.kanji;

    // Pull back directly away from the target, and release.
    final origin = Offset(area.width / 2, area.height * 0.7);
    final target = slotPosition(slot, game.board.length, area, 0);
    final away = (origin - target) / (origin - target).distance * 120;
    final gesture = await tester.startGesture(areaTopLeft + origin);
    for (var k = 1; k <= 6; k++) {
      await gesture.moveTo(areaTopLeft + origin + away * (k / 6));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    for (var k = 0; k < 90 && game.made.isEmpty; k++) {
      await tester.pump(const Duration(milliseconds: 16));
    }

    expect(game.made.map((m) => m.kanji), [made]);
    expect(game.board[slot]!.glyph, made);
    expect(game.hearts, 3);
    expect(find.text('$made meaning'), findsOneWidget); // announced
  });

  testWidgets('three misses and it is game over, with Play again', (
    tester,
  ) async {
    final game = await open(tester);
    final origin = Offset(area.width / 2, area.height * 0.7);
    for (var shot = 0; shot < 3; shot++) {
      // Pull up: fires straight down, off the bottom.
      await tester.dragFrom(areaTopLeft + origin, const Offset(0, -100));
      for (var k = 0; k < 60 && game.hearts > 2 - shot; k++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
    }
    expect(game.over, isTrue);
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Out of hearts'), findsOneWidget);
    expect(find.text('Play again'), findsOneWidget);
  });
}
