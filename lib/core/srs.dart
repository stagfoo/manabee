/// Flash-card scheduling, the way Anki does it: SM-2 with learning steps.
///
/// Adapted from jlptbenkyo's scheduler. A new card goes through short
/// learning steps (1 minute, then 10) inside the same sitting before it
/// graduates to day intervals; after that each review multiplies the
/// interval by the card's ease, which Hard and Easy nudge down and up.
/// Forgetting a graduated card (a lapse) sends it back through the steps
/// with its interval halved rather than erased.
///
/// Plain Dart with no clock of its own — `now` is always passed in — so a
/// year of reviews runs in a test in milliseconds.
library;

import 'dart:math' as math;

/// The four answers, as on Anki's buttons.
enum Grade { again, hard, good, easy }

/// Waits between answers while a card is being learned or relearned.
const List<Duration> kLearningSteps = [
  Duration(minutes: 1),
  Duration(minutes: 10),
];

/// The first real interval once a card leaves the learning steps.
const int kGraduatingIntervalDays = 1;

/// Where a card lands if it skipped the steps with Easy.
const int kEasyIntervalDays = 4;

/// 2.5 = "next time, two and a half times as long as last time".
const double kStartingEase = 2.5;

/// Failures drive ease down, never below this. Under ~1.3 the intervals
/// stop growing and a card is in front of you every other day forever.
const double kMinimumEase = 1.3;

const double kEasePenaltyAgain = -0.20;
const double kEasePenaltyHard = -0.15;
const double kEaseBonusEasy = 0.15;

/// A lapse multiplies the interval by this instead of resetting it: a word
/// you've known for months and blanked on once isn't new again.
const double kLapseMultiplier = 0.5;

const int kMaximumIntervalDays = 365 * 2;

/// A graduated card at or past this interval counts as learned in the
/// progress figures — a week between reviews is when a word has stuck.
const int kLearnedIntervalDays = 7;

/// Everything the scheduler knows about one card. Immutable: answering
/// returns a new state, so the review screen can preview all four buttons
/// and undo is just keeping the old one.
class ReviewState {
  const ReviewState({
    this.reps = 0,
    this.lapses = 0,
    this.ease = kStartingEase,
    this.intervalDays = 0,
    this.step = 0,
    this.due,
    this.introduced,
  });

  /// Successful reviews since the card was last (re)learned.
  final int reps;

  /// Times it was forgotten after graduating.
  final int lapses;
  final double ease;

  /// Zero while still in the first learning steps.
  final int intervalDays;

  /// Index into [kLearningSteps], or -1 once graduated.
  final int step;

  /// Null means never seen.
  final DateTime? due;

  /// When the card was first answered — what the daily new-card limit
  /// counts.
  final DateTime? introduced;

  bool get isNew => due == null;
  bool get isLearning => !isNew && step >= 0;
  bool get isReview => !isNew && step < 0;
  bool get learned => isReview && intervalDays >= kLearnedIntervalDays;

  bool isDue(DateTime now) => due == null || !due!.isAfter(now);

  /// Due at any point before [now]'s day ends.
  bool isDueToday(DateTime now) => due == null || due!.isBefore(endOfDay(now));

  ReviewState copyWith({
    int? reps,
    int? lapses,
    double? ease,
    int? intervalDays,
    int? step,
    DateTime? due,
    DateTime? introduced,
  }) => ReviewState(
    reps: reps ?? this.reps,
    lapses: lapses ?? this.lapses,
    ease: ease ?? this.ease,
    intervalDays: intervalDays ?? this.intervalDays,
    step: step ?? this.step,
    due: due ?? this.due,
    introduced: introduced ?? this.introduced,
  );

  ReviewState answer(Grade grade, DateTime now) {
    final card = isNew ? copyWith(introduced: now) : this;
    return card.step >= 0
        ? _reviewLearning(card, grade, now)
        : _reviewGraduated(card, grade, now);
  }

  Map<String, dynamic> toJson() => {
    'reps': reps,
    'lapses': lapses,
    'ease': ease,
    'ivl': intervalDays,
    'step': step,
    if (due != null) 'due': due!.toIso8601String(),
    if (introduced != null) 'introduced': introduced!.toIso8601String(),
  };

  factory ReviewState.fromJson(Map<String, dynamic>? j) {
    if (j == null) return const ReviewState();
    final due = DateTime.tryParse(j['due'] as String? ?? '');
    if (j.containsKey('box') && !j.containsKey('ease')) {
      return _fromLeitner((j['box'] as num?)?.toInt() ?? 0, due);
    }
    return ReviewState(
      reps: (j['reps'] as num?)?.toInt() ?? 0,
      lapses: (j['lapses'] as num?)?.toInt() ?? 0,
      ease: math.max(
        kMinimumEase,
        (j['ease'] as num?)?.toDouble() ?? kStartingEase,
      ),
      intervalDays: ((j['ivl'] as num?)?.toInt() ?? 0).clamp(
        0,
        kMaximumIntervalDays,
      ),
      step: ((j['step'] as num?)?.toInt() ?? 0).clamp(
        -1,
        kLearningSteps.length - 1,
      ),
      due: due,
      introduced: DateTime.tryParse(j['introduced'] as String? ?? ''),
    );
  }

  /// Cards from 1.0.2 and earlier were Leitner boxes graded 👍/👎. A box
  /// above zero had been answered right that many times in a row; it maps
  /// onto a graduated card with that box's interval, keeping its due date,
  /// so nobody's progress resets on update.
  static ReviewState _fromLeitner(int box, DateTime? due) {
    const boxDays = [0, 1, 3, 7, 14, 30, 60];
    if (due == null) return const ReviewState();
    if (box <= 0) return ReviewState(step: 0, due: due, introduced: due);
    return ReviewState(
      reps: box,
      step: -1,
      intervalDays: boxDays[box.clamp(1, boxDays.length - 1)],
      due: due,
      introduced: due,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ReviewState &&
      other.reps == reps &&
      other.lapses == lapses &&
      other.ease == ease &&
      other.intervalDays == intervalDays &&
      other.step == step &&
      other.due == due &&
      other.introduced == introduced;

  @override
  int get hashCode =>
      Object.hash(reps, lapses, ease, intervalDays, step, due, introduced);

  @override
  String toString() =>
      'ReviewState(reps=$reps, lapses=$lapses, '
      'ease=${ease.toStringAsFixed(2)}, ivl=$intervalDays, step=$step, due=$due)';
}

ReviewState _reviewLearning(ReviewState card, Grade grade, DateTime now) {
  switch (grade) {
    case Grade.again:
      return card.copyWith(step: 0, due: now.add(kLearningSteps.first));
    case Grade.hard:
      // Repeat the current step rather than advancing.
      return card.copyWith(due: now.add(kLearningSteps[card.step]));
    case Grade.good:
      final next = card.step + 1;
      if (next < kLearningSteps.length) {
        return card.copyWith(step: next, due: now.add(kLearningSteps[next]));
      }
      // A relearning card keeps the (halved) interval its lapse left it.
      final ivl = math.max(card.intervalDays, kGraduatingIntervalDays);
      return card.copyWith(
        step: -1,
        reps: card.reps + 1,
        intervalDays: ivl,
        due: now.add(Duration(days: ivl)),
      );
    case Grade.easy:
      // Straight out of learning: answering a new card instantly means it
      // was already known.
      final ivl = math.max(card.intervalDays, kEasyIntervalDays);
      return card.copyWith(
        step: -1,
        reps: card.reps + 1,
        intervalDays: ivl,
        due: now.add(Duration(days: ivl)),
      );
  }
}

ReviewState _reviewGraduated(ReviewState card, Grade grade, DateTime now) {
  if (grade == Grade.again) {
    final ivl = math.max(1, (card.intervalDays * kLapseMultiplier).round());
    return card.copyWith(
      step: 0,
      lapses: card.lapses + 1,
      reps: 0,
      ease: math.max(kMinimumEase, card.ease + kEasePenaltyAgain),
      intervalDays: ivl,
      due: now.add(kLearningSteps.first),
    );
  }

  final ease = math.max(
    kMinimumEase,
    card.ease +
        switch (grade) {
          Grade.hard => kEasePenaltyHard,
          Grade.easy => kEaseBonusEasy,
          _ => 0.0,
        },
  );
  final previous = math.max(1, card.intervalDays);
  final grown = switch (grade) {
    Grade.hard => previous * 1.2,
    Grade.good => previous * ease,
    Grade.easy => previous * ease * 1.3,
    Grade.again => previous.toDouble(),
  };
  // Each button lands at least a day beyond the one below it; otherwise
  // at short intervals Good and Easy round to the same day and Easy does
  // nothing.
  final floor =
      previous +
      switch (grade) {
        Grade.hard => 1,
        Grade.good => 2,
        Grade.easy => 3,
        Grade.again => 0,
      };
  final ivl = math.min(kMaximumIntervalDays, math.max(floor, grown.round()));
  return card.copyWith(
    reps: card.reps + 1,
    ease: ease,
    intervalDays: ivl,
    due: now.add(Duration(days: ivl)),
  );
}

/// What each button would do, for the labels on them.
Map<Grade, ReviewState> previewAll(ReviewState card, DateTime now) => {
  for (final g in Grade.values) g: card.answer(g, now),
};

/// Anki-style short interval: `<1m`, `10m`, `3h`, `4d`, `1.5mo`, `1.2y`.
String formatInterval(Duration d) {
  if (d < const Duration(minutes: 1)) return '<1m';
  if (d < const Duration(hours: 1)) return '${d.inMinutes}m';
  if (d < const Duration(days: 1)) return '${d.inHours}h';
  final days = d.inHours / 24;
  if (days < 30) return '${days.round()}d';
  if (days < 365) return '${_oneDecimal(days / 30)}mo';
  return '${_oneDecimal(days / 365)}y';
}

String _oneDecimal(double v) {
  final s = v.toStringAsFixed(1);
  return s.endsWith('.0') ? s.substring(0, s.length - 2) : s;
}

/// Midnight at the end of [now]'s day. Reviews are due by the day, as in
/// Anki: a card reviewed at 9pm with a one-day interval is due all of
/// tomorrow, not only after 9pm.
DateTime endOfDay(DateTime now) => DateTime(now.year, now.month, now.day + 1);

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// New cards already introduced on [now]'s calendar day.
int introducedToday(Iterable<ReviewState> cards, DateTime now) => cards
    .where(
      (c) => c.introduced != null && _sameDay(c.introduced!.toLocal(), now),
    )
    .length;

class DueCounts {
  const DueCounts(this.newCards, this.learning, this.review);

  final int newCards, learning, review;

  int get total => newCards + learning + review;
}

/// What's waiting today: learning and review cards due before the day
/// ends, and new cards up to what's left of [newPerDay].
DueCounts countDue(
  Iterable<ReviewState> cards,
  DateTime now, {
  required int newPerDay,
  int newAlreadyToday = 0,
}) {
  var fresh = 0, learning = 0, review = 0;
  for (final c in cards) {
    if (c.isNew) {
      fresh++;
    } else if (c.isDueToday(now)) {
      c.isLearning ? learning++ : review++;
    }
  }
  final allowance = math.max(0, newPerDay - newAlreadyToday);
  return DueCounts(math.min(fresh, allowance), learning, review);
}

/// One sitting of flash cards, as Anki runs it.
///
/// Built once from the deck: today's due reviews (most overdue first),
/// cards still in learning, and up to [newLimit] new cards in the order
/// they were added. Answering a card that's still learning keeps it in the
/// session; it comes back when its step is up, or early if nothing else is
/// left and it's due within [learnAhead] — Anki's learn-ahead limit, so a
/// session doesn't end with you waiting out a 10-minute step.
class StudySession {
  StudySession(
    Map<String, ReviewState> cards,
    DateTime now, {
    required int newLimit,
    this.learnAhead = const Duration(minutes: 20),
  }) : states = Map.of(cards) {
    final reviews = <String>[];
    for (final e in cards.entries) {
      final s = e.value;
      if (s.isNew) {
        if (_new.length < newLimit) _new.add(e.key);
      } else if (s.isLearning) {
        _learning.add(e.key);
      } else if (s.isDueToday(now)) {
        reviews.add(e.key);
      }
    }
    reviews.sort((a, b) => states[a]!.due!.compareTo(states[b]!.due!));
    _reviews.addAll(reviews);
  }

  final Map<String, ReviewState> states;
  final Duration learnAhead;
  final List<String> _reviews = [];
  final List<String> _new = [];
  final Set<String> _learning = {};
  final List<_Undo> _history = [];

  int get newCount => _new.length;
  int get reviewCount => _reviews.length;
  int get learningCount => _learning.length;
  bool get canUndo => _history.isNotEmpty;

  /// The card to show at [now], or null when the session is over for now.
  String? current(DateTime now) {
    final dueLearning = _earliestLearning(now);
    if (dueLearning != null) return dueLearning;
    if (_reviews.isNotEmpty) return _reviews.first;
    if (_new.isNotEmpty) return _new.first;
    return _earliestLearning(now.add(learnAhead));
  }

  String? _earliestLearning(DateTime by) {
    String? best;
    for (final id in _learning) {
      final due = states[id]!.due!;
      if (due.isAfter(by)) continue;
      if (best == null || due.isBefore(states[best]!.due!)) best = id;
    }
    return best;
  }

  /// When the next learning card in this session comes up, if any.
  DateTime? get nextLearningDue {
    DateTime? next;
    for (final id in _learning) {
      final due = states[id]!.due!;
      if (next == null || due.isBefore(next)) next = due;
    }
    return next;
  }

  ReviewState answer(String id, Grade grade, DateTime now) {
    final before = states[id]!;
    _history.add(
      _Undo(
        id,
        before,
        _reviews.indexOf(id),
        _new.indexOf(id),
        _learning.contains(id),
      ),
    );
    _reviews.remove(id);
    _new.remove(id);
    final after = before.answer(grade, now);
    states[id] = after;
    if (after.isLearning) {
      _learning.add(id);
    } else {
      _learning.remove(id);
    }
    return after;
  }

  /// Takes back the last answer. Returns the card id and the state it had,
  /// for the caller to persist, or null when there's nothing to undo.
  (String, ReviewState)? undo() {
    if (_history.isEmpty) return null;
    final u = _history.removeLast();
    states[u.id] = u.state;
    _learning.remove(u.id);
    if (u.reviewIndex >= 0) _reviews.insert(u.reviewIndex, u.id);
    if (u.newIndex >= 0) _new.insert(u.newIndex, u.id);
    if (u.wasLearning) _learning.add(u.id);
    return (u.id, u.state);
  }

  /// Anki's "custom study: more new cards" — pulls further new cards from
  /// [cards], in order, beyond today's limit.
  int addNew(Iterable<String> ids, int count) {
    var added = 0;
    for (final id in ids) {
      if (added >= count) break;
      final s = states[id];
      if (s == null || !s.isNew || _new.contains(id)) continue;
      _new.add(id);
      added++;
    }
    return added;
  }
}

class _Undo {
  _Undo(this.id, this.state, this.reviewIndex, this.newIndex, this.wasLearning);

  final String id;
  final ReviewState state;
  final int reviewIndex;
  final int newIndex;
  final bool wasLearning;
}
