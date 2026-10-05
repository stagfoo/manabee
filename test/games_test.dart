import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:manabee/core/games.dart';

GameCard card(String id, String jp, String meaning) =>
    GameCard(id: id, japanese: jp, reading: jp, meaning: meaning);

final deck = [
  card('1', '若い', 'young'),
  card('2', '虫', 'bug'),
  card('3', '目', 'eye'),
  card('4', '朝', 'morning'),
  card('5', '森', 'forest'),
  card('6', '光', 'light'),
];

void main() {
  group('quiz', () {
    test('one question per card, options include the answer once', () {
      final qs = buildQuiz(deck, Random(1));
      expect(qs.length, deck.length);
      for (final q in qs) {
        expect(q.options.length, 4);
        final right = q.direction == QuizDirection.toMeaning
            ? q.card.meaning
            : q.card.japanese;
        expect(q.options[q.answerIndex], right);
        expect(q.options.where((o) => o == right).length, 1);
        expect(q.options.toSet().length, q.options.length);
      }
    });

    test('directions alternate', () {
      final qs = buildQuiz(deck, Random(2));
      expect(qs[0].direction, QuizDirection.toMeaning);
      expect(qs[1].direction, QuizDirection.toJapanese);
    });

    test('a distractor with the same meaning is never offered', () {
      final dupes = [
        card('a', '若い', 'young'),
        card('b', '幼い', 'young'),
        card('c', '虫', 'bug'),
      ];
      for (var seed = 0; seed < 20; seed++) {
        for (final q in buildQuiz(dupes, Random(seed))) {
          expect(q.options.toSet().length, q.options.length);
        }
      }
    });

    test('small decks get fewer options; too small gets no quiz', () {
      final qs = buildQuiz(deck.take(2).toList(), Random(3));
      expect(qs, isNotEmpty);
      expect(qs.first.options.length, 2);
      expect(buildQuiz(deck.take(1).toList(), Random(3)), isEmpty);
    });

    test('length caps the questions', () {
      expect(buildQuiz(deck, Random(4), length: 3).length, 3);
    });

    test('seeded quizzes are reproducible', () {
      final a = buildQuiz(
        deck,
        Random(7),
      ).map((q) => (q.card.id, q.options.join())).toList();
      final b = buildQuiz(
        deck,
        Random(7),
      ).map((q) => (q.card.id, q.options.join())).toList();
      expect(a, b);
    });
  });

  group('match', () {
    int indexOf(MatchGame g, String id, TileSide side) =>
        g.tiles.indexWhere((t) => t.cardId == id && t.side == side);

    test('deals two tiles per card up to the pair limit', () {
      final g = MatchGame.deal(deck, Random(1), pairs: 4);
      expect(g.tiles.length, 8);
      expect(g.pairCount, 4);
    });

    test('a correct pair clears, a wrong one counts a mistake', () {
      final g = MatchGame.deal(deck, Random(1));
      final id = g.tiles.first.cardId;
      final other = g.tiles.firstWhere((t) => t.cardId != id).cardId;

      expect(g.tap(indexOf(g, id, TileSide.japanese)), MatchResult.selected);
      expect(
        g.tap(indexOf(g, other, TileSide.meaning)),
        MatchResult.mismatched,
      );
      expect(g.mistakes, 1);
      expect(g.selected, isNull);

      g.tap(indexOf(g, id, TileSide.japanese));
      expect(g.tap(indexOf(g, id, TileSide.meaning)), MatchResult.matched);
      expect(g.cleared.length, 2);
      expect(g.tap(indexOf(g, id, TileSide.meaning)), MatchResult.ignored);
    });

    test('tapping the selection again deselects; same side reselects', () {
      final g = MatchGame.deal(deck, Random(1));
      final jp = [
        for (var i = 0; i < g.tiles.length; i++)
          if (g.tiles[i].side == TileSide.japanese) i,
      ];
      g.tap(jp[0]);
      expect(g.tap(jp[0]), MatchResult.deselected);
      g.tap(jp[0]);
      expect(g.tap(jp[1]), MatchResult.selected);
      expect(g.selected, jp[1]);
      expect(g.mistakes, 0);
    });

    test('clearing every pair finishes the game', () {
      final g = MatchGame.deal(deck, Random(5));
      for (final id in g.tiles.map((t) => t.cardId).toSet()) {
        g.tap(indexOf(g, id, TileSide.japanese));
        g.tap(indexOf(g, id, TileSide.meaning));
      }
      expect(g.finished, isTrue);
      expect(g.mistakes, 0);
    });

    test('duplicate meanings are dealt only once', () {
      final g = MatchGame.deal([
        card('a', '若い', 'young'),
        card('b', '幼い', 'young'),
        card('c', '虫', 'bug'),
      ], Random(1));
      final meanings = g.tiles
          .where((t) => t.side == TileSide.meaning)
          .map((t) => t.label)
          .toList();
      expect(meanings.toSet().length, meanings.length);
    });

    test('out-of-range taps are ignored', () {
      final g = MatchGame.deal(deck, Random(1));
      expect(g.tap(-1), MatchResult.ignored);
      expect(g.tap(999), MatchResult.ignored);
    });
  });
}
