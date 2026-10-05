import 'package:flutter_test/flutter_test.dart';
import 'package:manabee/core/srs.dart';

void main() {
  final t0 = DateTime(2026, 1, 1, 9);

  test('a new card is due and not known', () {
    const s = ReviewState();
    expect(s.isDue(t0), isTrue);
    expect(s.known, isFalse);
    expect(s.learned, isFalse);
  });

  test('thumbs up climbs the boxes with growing intervals', () {
    var s = const ReviewState();
    var now = t0;
    for (var box = 1; box <= kTopBox; box++) {
      s = s.answer(knewIt: true, now: now);
      expect(s.box, box);
      expect(s.due, now.add(Duration(days: kBoxIntervalsDays[box])));
      now = s.due!;
    }
    expect(s.ups, kTopBox);
  });

  test('the top box is a ceiling', () {
    var s = ReviewState(box: kTopBox, due: t0);
    s = s.answer(knewIt: true, now: t0);
    expect(s.box, kTopBox);
  });

  test('thumbs down sends a card back to box 0, due now', () {
    var s = const ReviewState(box: 4, ups: 4);
    s = s.answer(knewIt: false, now: t0);
    expect(s.box, 0);
    expect(s.isDue(t0), isTrue);
    expect(s.downs, 1);
    expect(s.ups, 4);
  });

  test('learned at the threshold box', () {
    expect(const ReviewState(box: kLearnedBox).learned, isTrue);
    expect(const ReviewState(box: kLearnedBox - 1).learned, isFalse);
  });

  test('not due before its date, due on it', () {
    final s = const ReviewState().answer(knewIt: true, now: t0);
    expect(s.isDue(t0.add(const Duration(hours: 23))), isFalse);
    expect(s.isDue(t0.add(const Duration(days: 1))), isTrue);
  });

  test('json round trip, and junk falls back safely', () {
    final s = ReviewState(box: 3, due: t0, ups: 5, downs: 2);
    final back = ReviewState.fromJson(s.toJson());
    expect((back.box, back.due, back.ups, back.downs), (3, t0, 5, 2));
    expect(ReviewState.fromJson(null).box, 0);
    expect(ReviewState.fromJson({'box': 99, 'due': 'nope'}).box, kTopBox);
    expect(ReviewState.fromJson({'due': 'nope'}).due, isNull);
  });

  test('study order: due first, lowest box first, then soonest due', () {
    final items = {
      'future': ReviewState(box: 2, due: t0.add(const Duration(days: 3))),
      'dueHigh': ReviewState(box: 4, due: t0.subtract(const Duration(days: 1))),
      'new': const ReviewState(),
      'soon': ReviewState(box: 1, due: t0.add(const Duration(days: 1))),
      'dueLow': ReviewState(box: 1, due: t0),
    };
    final order = studyOrder(items.keys.toList(), (k) => items[k]!, t0);
    expect(order, ['new', 'dueLow', 'dueHigh', 'soon', 'future']);
    expect(dueCount(items.keys.toList(), (k) => items[k]!, t0), 3);
  });

  test('study order is stable for ties', () {
    final order = studyOrder(['a', 'b', 'c'], (_) => const ReviewState(), t0);
    expect(order, ['a', 'b', 'c']);
  });
}
