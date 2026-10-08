import 'package:flutter_test/flutter_test.dart';
import 'package:manabee/core/focus.dart';

List<String> ids(int n) => [for (var i = 1; i <= n; i++) 'w$i'];

void main() {
  test('nothing focused yet: the first batch', () {
    expect(nextBatch(ids(50), {}, 20), ids(20));
  });

  test('the next batch follows the current one', () {
    final first = nextBatch(ids(50), {}, 20).toSet();
    expect(nextBatch(ids(50), first, 20), [
      for (var i = 21; i <= 40; i++) 'w$i',
    ]);
  });

  test('at the end it wraps round, never repeating the current set', () {
    final current = {for (var i = 41; i <= 50; i++) 'w$i'};
    final next = nextBatch(ids(50), current, 20);
    expect(next, ids(20));
    expect(next.toSet().intersection(current), isEmpty);
  });

  test('fewer candidates than a batch: tops up rather than shrinking', () {
    // 25 unlearned words, 20 of them already focused: 5 new + 15 kept.
    final current = ids(20).toSet();
    final next = nextBatch(ids(25), current, 20);
    expect(next.length, 20);
    expect(next.take(5), ['w21', 'w22', 'w23', 'w24', 'w25']);
  });

  test('a small deck gives what there is', () {
    expect(nextBatch(ids(7), {}, 20), ids(7));
    expect(nextBatch([], {}, 20), isEmpty);
  });

  test('current words that are no longer candidates (learned) drop out', () {
    // w1..w20 focused; w1..w10 since learned, so not in the candidates.
    final candidates = [for (var i = 11; i <= 40; i++) 'w$i'];
    final next = nextBatch(candidates, ids(20).toSet(), 20);
    expect(next.first, 'w21');
    expect(next, isNot(contains('w1')));
  });
}
