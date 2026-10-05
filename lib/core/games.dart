/// The two vocabulary games: a multiple-choice quiz and a pair-matching
/// board. Game state only — no widgets — and every random choice goes
/// through a [Random] the caller passes in, so a seeded game is fully
/// reproducible in tests.
library;

import 'dart:math';

/// The minimum a game needs to be a game rather than a formality.
const int kMinQuizWords = 2;
const int kMinMatchWords = 2;

/// What the quiz shows and what it asks for.
enum QuizDirection {
  /// Show the Japanese, pick the meaning.
  toMeaning,

  /// Show the meaning, pick the Japanese.
  toJapanese,
}

/// The facts a game needs about a word. Kept separate from the stored Word
/// so the games test without the persistence model.
class GameCard {
  const GameCard({
    required this.id,
    required this.japanese,
    required this.reading,
    required this.meaning,
  });

  final String id;
  final String japanese;
  final String reading;
  final String meaning;
}

class QuizQuestion {
  const QuizQuestion({
    required this.card,
    required this.direction,
    required this.options,
    required this.answerIndex,
  });

  final GameCard card;
  final QuizDirection direction;

  /// Displayed answers; [answerIndex] is the right one.
  final List<String> options;
  final int answerIndex;

  String get prompt =>
      direction == QuizDirection.toMeaning ? card.japanese : card.meaning;

  bool isCorrect(int index) => index == answerIndex;
}

/// One question per card in [cards] (up to [length]), shuffled, alternating
/// direction, each with up to [optionCount] options. Distractors are other
/// cards' answers, and never a duplicate of the right answer's text — two
/// words that share a meaning ("young" for both 若い and 幼い) would
/// otherwise make a question with two right answers marked one wrong.
List<QuizQuestion> buildQuiz(
  List<GameCard> cards,
  Random random, {
  int length = 10,
  int optionCount = 4,
}) {
  if (cards.length < kMinQuizWords) return const [];
  final pool = [...cards]..shuffle(random);
  final picked = pool.take(length).toList();
  final questions = <QuizQuestion>[];
  for (var q = 0; q < picked.length; q++) {
    final card = picked[q];
    final direction = q.isEven
        ? QuizDirection.toMeaning
        : QuizDirection.toJapanese;
    String answerOf(GameCard c) =>
        direction == QuizDirection.toMeaning ? c.meaning : c.japanese;
    final right = answerOf(card);
    final distractors = <String>[];
    final others = [...cards]..shuffle(random);
    for (final other in others) {
      if (distractors.length >= optionCount - 1) break;
      final text = answerOf(other);
      if (other.id == card.id || text == right || distractors.contains(text)) {
        continue;
      }
      distractors.add(text);
    }
    if (distractors.isEmpty) continue;
    final answerIndex = random.nextInt(distractors.length + 1);
    final options = [...distractors]..insert(answerIndex, right);
    questions.add(
      QuizQuestion(
        card: card,
        direction: direction,
        options: options,
        answerIndex: answerIndex,
      ),
    );
  }
  return questions;
}

enum TileSide { japanese, meaning }

class MatchTile {
  const MatchTile(this.cardId, this.side, this.label);

  final String cardId;
  final TileSide side;
  final String label;
}

enum MatchResult { selected, deselected, matched, mismatched, ignored }

/// A board of [MatchTile]s: tap one Japanese and one meaning; a pair that
/// belongs to the same card clears.
class MatchGame {
  MatchGame._(this.tiles);

  factory MatchGame.deal(List<GameCard> cards, Random random, {int pairs = 6}) {
    // Cards sharing a meaning or a spelling would make a "wrong" pair that
    // looks exactly right; keep only the first of each.
    final seenMeaning = <String>{};
    final seenJapanese = <String>{};
    final usable = <GameCard>[];
    for (final c in [...cards]..shuffle(random)) {
      if (seenMeaning.add(c.meaning) && seenJapanese.add(c.japanese)) {
        usable.add(c);
      }
      if (usable.length == pairs) break;
    }
    final tiles = [
      for (final c in usable) ...[
        MatchTile(c.id, TileSide.japanese, c.japanese),
        MatchTile(c.id, TileSide.meaning, c.meaning),
      ],
    ]..shuffle(random);
    return MatchGame._(tiles);
  }

  final List<MatchTile> tiles;
  final Set<int> cleared = {};
  int? selected;
  int mistakes = 0;

  int get pairCount => tiles.length ~/ 2;
  bool get finished => tiles.isNotEmpty && cleared.length == tiles.length;

  MatchResult tap(int index) {
    if (index < 0 || index >= tiles.length || cleared.contains(index)) {
      return MatchResult.ignored;
    }
    final current = selected;
    if (current == null) {
      selected = index;
      return MatchResult.selected;
    }
    if (current == index) {
      selected = null;
      return MatchResult.deselected;
    }
    final a = tiles[current];
    final b = tiles[index];
    if (a.side == b.side) {
      // Two from the same column: the newer tap becomes the selection.
      selected = index;
      return MatchResult.selected;
    }
    selected = null;
    if (a.cardId == b.cardId) {
      cleared
        ..add(current)
        ..add(index);
      return MatchResult.matched;
    }
    mistakes++;
    return MatchResult.mismatched;
  }
}
