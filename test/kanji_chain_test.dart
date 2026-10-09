import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:manabee/core/kanji_chain.dart';

Combo c(String k, String a, String b, {int g = 1}) =>
    Combo(kanji: k, a: a, b: b, grade: g, meanings: ['$k meaning']);

final small = ComboBook([
  c('林', '木', '木'),
  c('森', '木', '林'),
  c('明', '日', '月', g: 2),
  c('休', '亻', '木'),
  c('男', '田', '力'),
]);

void main() {
  test('parts combine in either order', () {
    expect(small.combine('日', '月')!.kanji, '明');
    expect(small.combine('月', '日')!.kanji, '明');
    expect(small.combine('木', '林')!.kanji, '森');
    expect(small.combine('日', '木'), isNull);
  });

  test('the slingshot always holds a part that combines with the board', () {
    for (var seed = 0; seed < 50; seed++) {
      final game = ChainGame(small, Random(seed));
      expect(game.goodSlots, isNotEmpty, reason: 'seed $seed');
    }
  });

  test('a merge builds the kanji in place and scores', () {
    final game = ChainGame(small, Random(1));
    final slot = game.goodSlots.first;
    final expected = small.combine(game.ammo, game.board[slot]!.glyph)!;
    expect(game.hit(slot), ShotResult.merged);
    expect(game.board[slot]!.glyph, expected.kanji);
    expect(game.board[slot]!.made, isTrue);
    expect(game.made.single, expected);
    expect(game.score, 10);
    expect(game.goodSlots, isNotEmpty);
  });

  test('chains: 木 into 木 makes 林, then 木 into 林 makes 森, scoring more', () {
    final game = ChainGame(small, Random(3));
    game.board
      ..fillRange(0, game.board.length, const Target('田'))
      ..[0] = const Target('木');
    game.ammo = '木';
    expect(game.hit(0), ShotResult.merged);
    expect(game.board[0]!.glyph, '林');
    expect(game.score, 10);

    game.ammo = '木';
    expect(game.hit(0), ShotResult.merged);
    expect(game.board[0]!.glyph, '森');
    expect(game.chain, 2);
    expect(game.score, 30); // 10, then 10 × chain of 2
    expect(game.made.map((m) => m.kanji), ['林', '森']);
  });

  test('a wrong hit or a miss costs a heart and breaks the chain', () {
    final game = ChainGame(small, Random(4));
    game.board[0] = const Target('田');
    game.ammo = '日';
    game.chain = 2;
    expect(game.hit(0), ShotResult.wrong);
    expect(game.hearts, 2);
    expect(game.chain, 0);
    expect(game.ammo, '日'); // try again with the same part
    game.miss();
    game.miss();
    expect(game.over, isTrue);
    expect(
      game.hit(game.goodSlots.isEmpty ? 0 : game.goodSlots.first),
      ShotResult.missed,
    );
  });

  test('the pool widens with the score', () {
    final game = ChainGame(small, Random(5));
    expect(game.maxGrade, 2);
    game.score = 130;
    expect(game.maxGrade, 4);
    game.score = 400;
    expect(game.maxGrade, 8);
  });

  test(
    'the shipped data: real chains, and every starting board is winnable',
    () {
      final json = jsonDecode(
        File('assets/kanji/combos.json').readAsStringSync(),
      );
      final book = ComboBook([
        for (final j in json['combos'] as List) Combo.fromJson(j),
      ]);
      expect(book.combine('日', '月')!.kanji, '明');
      expect(book.combine('木', '木')!.kanji, '林');
      expect(book.combine('木', '林')!.kanji, '森');
      expect(book.combine('亻', '木')!.kanji, '休');
      expect(book.combine('木', '林')!.meanings, contains('forest'));
      for (var seed = 0; seed < 200; seed++) {
        final game = ChainGame(book, Random(seed));
        expect(game.goodSlots, isNotEmpty, reason: 'seed $seed');
        // And keeps being winnable as it's played.
        for (var shot = 0; shot < 20; shot++) {
          game.hit(game.goodSlots[seed % game.goodSlots.length]);
          expect(game.goodSlots, isNotEmpty, reason: 'seed $seed shot $shot');
        }
      }
    },
  );
}
