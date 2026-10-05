import 'package:flutter_test/flutter_test.dart';
import 'package:manabee/core/srs.dart';

final t0 = DateTime(2026, 1, 1, 9);

ReviewState graduated(int ivl, {double ease = kStartingEase}) => ReviewState(
  step: -1,
  reps: 3,
  intervalDays: ivl,
  ease: ease,
  due: t0,
  introduced: t0.subtract(const Duration(days: 30)),
);

void main() {
  group('a new card', () {
    test('is new and due', () {
      const s = ReviewState();
      expect(s.isNew, isTrue);
      expect(s.isDue(t0), isTrue);
      expect(s.learned, isFalse);
    });

    test('good walks it through 1m, 10m, then graduates to a day', () {
      var s = const ReviewState().answer(Grade.good, t0);
      expect(s.isLearning, isTrue);
      expect(s.step, 1);
      expect(s.due, t0.add(kLearningSteps[1]));
      expect(s.introduced, t0);

      s = s.answer(Grade.good, s.due!);
      expect(s.isReview, isTrue);
      expect(s.intervalDays, kGraduatingIntervalDays);
    });

    test('again returns to the first step', () {
      var s = const ReviewState().answer(Grade.good, t0);
      s = s.answer(Grade.again, t0);
      expect(s.step, 0);
      expect(s.due, t0.add(kLearningSteps.first));
    });

    test('hard repeats the step', () {
      final s = const ReviewState().answer(Grade.hard, t0);
      expect(s.step, 0);
      expect(s.due, t0.add(kLearningSteps[0]));
    });

    test('easy skips the steps', () {
      final s = const ReviewState().answer(Grade.easy, t0);
      expect(s.isReview, isTrue);
      expect(s.intervalDays, kEasyIntervalDays);
    });

    test('introduced is set once and kept', () {
      var s = const ReviewState().answer(Grade.again, t0);
      s = s.answer(Grade.good, t0.add(const Duration(hours: 1)));
      expect(s.introduced, t0);
    });
  });

  group('a graduated card', () {
    test('good multiplies by the ease', () {
      final s = graduated(10).answer(Grade.good, t0);
      expect(s.intervalDays, 25);
      expect(s.due, t0.add(const Duration(days: 25)));
    });

    test('hard grows slowly and lowers ease', () {
      final s = graduated(10).answer(Grade.hard, t0);
      expect(s.intervalDays, 12);
      expect(s.ease, closeTo(kStartingEase + kEasePenaltyHard, 1e-9));
    });

    test('easy grows fastest and raises ease', () {
      final s = graduated(10).answer(Grade.easy, t0);
      expect(s.intervalDays, greaterThan(25));
      expect(s.ease, closeTo(kStartingEase + kEaseBonusEasy, 1e-9));
    });

    test('hard, good and easy never collapse to the same day', () {
      final p = previewAll(graduated(1), t0);
      final days = [
        Grade.hard,
        Grade.good,
        Grade.easy,
      ].map((g) => p[g]!.intervalDays).toList();
      expect(days.toSet().length, 3);
      expect(days, orderedEquals([...days]..sort()));
    });

    test('intervals are capped', () {
      final s = graduated(kMaximumIntervalDays).answer(Grade.easy, t0);
      expect(s.intervalDays, kMaximumIntervalDays);
    });

    test('learned at a week', () {
      expect(graduated(kLearnedIntervalDays).learned, isTrue);
      expect(graduated(kLearnedIntervalDays - 1).learned, isFalse);
    });
  });

  group('forgetting', () {
    test('a lapse halves the interval and relearns', () {
      final s = graduated(20).answer(Grade.again, t0);
      expect(s.isLearning, isTrue);
      expect(s.lapses, 1);
      expect(s.intervalDays, 10);
      expect(s.due, t0.add(kLearningSteps.first));
      expect(s.ease, closeTo(kStartingEase + kEasePenaltyAgain, 1e-9));
    });

    test('relearned card resumes from the halved interval', () {
      var s = graduated(20).answer(Grade.again, t0);
      s = s.answer(Grade.good, t0);
      s = s.answer(Grade.good, t0);
      expect(s.isReview, isTrue);
      expect(s.intervalDays, 10);
    });

    test('ease has a floor', () {
      final s = graduated(
        10,
        ease: kMinimumEase + 0.05,
      ).answer(Grade.again, t0);
      expect(s.ease, kMinimumEase);
      expect(
        graduated(10, ease: kMinimumEase).answer(Grade.hard, t0).ease,
        kMinimumEase,
      );
    });
  });

  group('json', () {
    test('round trip', () {
      final s = graduated(12, ease: 2.1).copyWith(lapses: 2);
      expect(ReviewState.fromJson(s.toJson()), s);
    });

    test('null and junk fall back safely', () {
      expect(ReviewState.fromJson(null).isNew, isTrue);
      final s = ReviewState.fromJson({'ease': 0.2, 'step': 9, 'due': 'x'});
      expect(s.ease, kMinimumEase);
      expect(s.step, kLearningSteps.length - 1);
      expect(s.isNew, isTrue);
    });

    test('old 👍/👎 boxes migrate without losing progress', () {
      final due = t0.add(const Duration(days: 3));
      final box3 = ReviewState.fromJson({
        'box': 3,
        'due': due.toIso8601String(),
        'ups': 3,
        'downs': 0,
      });
      expect(box3.isReview, isTrue);
      expect(box3.intervalDays, 7);
      expect(box3.due, due);

      final missed = ReviewState.fromJson({
        'box': 0,
        'due': t0.toIso8601String(),
      });
      expect(missed.isLearning, isTrue);

      expect(ReviewState.fromJson({'box': 0}).isNew, isTrue);
    });
  });

  test('formatInterval', () {
    expect(formatInterval(const Duration(seconds: 20)), '<1m');
    expect(formatInterval(const Duration(minutes: 10)), '10m');
    expect(formatInterval(const Duration(hours: 3)), '3h');
    expect(formatInterval(const Duration(days: 4)), '4d');
    expect(formatInterval(const Duration(days: 45)), '1.5mo');
    expect(formatInterval(const Duration(days: 60)), '2mo');
    expect(formatInterval(const Duration(days: 438)), '1.2y');
  });

  group('daily counts', () {
    test('new cards are rationed, learning and reviews are not', () {
      final cards = [
        for (var i = 0; i < 30; i++) const ReviewState(),
        graduated(5),
        graduated(5).copyWith(due: t0.add(const Duration(days: 2))),
        // Later today still counts: reviews are due by the day.
        graduated(5).copyWith(due: t0.add(const Duration(hours: 8))),
        const ReviewState().answer(Grade.good, t0),
      ];
      final c = countDue(
        cards,
        t0.add(const Duration(hours: 1)),
        newPerDay: 20,
        newAlreadyToday: 5,
      );
      expect(c.newCards, 15);
      expect(c.review, 2);
      expect(c.learning, 1);
    });

    test('introducedToday counts by calendar day', () {
      final today = const ReviewState().answer(Grade.good, t0);
      final yesterday = const ReviewState().answer(
        Grade.good,
        t0.subtract(const Duration(days: 1)),
      );
      expect(introducedToday([today, yesterday, const ReviewState()], t0), 1);
    });
  });

  group('a study session', () {
    Map<String, ReviewState> deck() => {
      'review-late': graduated(3)
          .copyWith(due: t0.subtract(const Duration(days: 2))),
      'review-now': graduated(3),
      'not-due': graduated(3).copyWith(due: t0.add(const Duration(days: 1))),
      'new1': const ReviewState(),
      'new2': const ReviewState(),
      'new3': const ReviewState(),
    };

    test('reviews (most overdue first), then new up to the limit', () {
      final s = StudySession(deck(), t0, newLimit: 2);
      expect(s.reviewCount, 2);
      expect(s.newCount, 2);
      expect(s.current(t0), 'review-late');
      s.answer('review-late', Grade.good, t0);
      expect(s.current(t0), 'review-now');
      s.answer('review-now', Grade.good, t0);
      expect(s.current(t0), 'new1');
    });

    test('a review due later today is in today\'s session', () {
      final s = StudySession(
        {'eve': graduated(1).copyWith(due: t0.add(const Duration(hours: 10)))},
        t0,
        newLimit: 0,
      );
      expect(s.current(t0), 'eve');
    });

    test('tomorrow\'s review is not', () {
      final s = StudySession(
        {'tmrw': graduated(1).copyWith(due: endOfDay(t0))},
        t0,
        newLimit: 0,
      );
      expect(s.current(t0), isNull);
    });

    test('a learning card comes back when its step is up', () {
      final s = StudySession(
        {'a': const ReviewState(), 'b': const ReviewState()},
        t0,
        newLimit: 2,
      );
      s.answer('a', Grade.again, t0); // due in 1m
      expect(s.learningCount, 1);
      expect(s.current(t0), 'b');
      final later = t0.add(const Duration(minutes: 2));
      expect(s.current(later), 'a');
    });

    test('learns ahead when nothing else is left', () {
      final s = StudySession({'a': const ReviewState()}, t0, newLimit: 1);
      s.answer('a', Grade.good, t0); // due in 10m
      expect(s.current(t0), 'a');
    });

    test('ends once every card has graduated', () {
      final s = StudySession({'a': const ReviewState()}, t0, newLimit: 1);
      s.answer('a', Grade.easy, t0);
      expect(s.current(t0), isNull);
      expect(s.nextLearningDue, isNull);
    });

    test('a learning step beyond learn-ahead waits', () {
      final s = StudySession(
        {'a': const ReviewState()},
        t0,
        newLimit: 1,
        learnAhead: const Duration(minutes: 5),
      );
      s.answer('a', Grade.good, t0); // 10m away
      expect(s.current(t0), isNull);
      expect(s.nextLearningDue, t0.add(kLearningSteps[1]));
    });

    test('undo restores the card and its place', () {
      final s = StudySession(deck(), t0, newLimit: 2);
      final before = s.states['review-late'];
      s.answer('review-late', Grade.again, t0);
      expect(s.learningCount, 1);
      final undone = s.undo()!;
      expect(undone.$1, 'review-late');
      expect(undone.$2, before);
      expect(s.learningCount, 0);
      expect(s.reviewCount, 2);
      expect(s.current(t0), 'review-late');
      expect(s.undo(), isNull);
    });

    test('more new cards can be added past the limit', () {
      final d = deck();
      final s = StudySession(d, t0, newLimit: 1);
      expect(s.newCount, 1);
      expect(s.addNew(d.keys, 10), 2);
      expect(s.newCount, 3);
      expect(s.addNew(d.keys, 10), 0);
    });
  });
}
