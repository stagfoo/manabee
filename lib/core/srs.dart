/// Flash-card scheduling: a Leitner box system.
///
/// The cards have two buttons, 👍 and 👎, so the scheduler takes exactly
/// that and nothing finer. Leitner is the scheme that fits a binary
/// answer: 👍 moves a card up a box and pushes it further out, 👎 sends it
/// back to the first box. (SM-2, as jlptbenkyo uses, earns its keep by
/// grading on four levels — with two it collapses to roughly this anyway,
/// with more to explain.)
///
/// No clock of its own: `now` is always passed in, so tests run a month of
/// reviews instantly.
library;

/// Days a card waits after landing in each box. Box 0 is "new or just
/// missed" and is due straight away.
const List<int> kBoxIntervalsDays = [0, 1, 3, 7, 14, 30, 60];

int get kTopBox => kBoxIntervalsDays.length - 1;

/// A card at or past this box counts as learned in the progress figures.
/// Three right answers spread over a week is when a word has stuck rather
/// than been recognised from a minute ago.
const int kLearnedBox = 3;

class ReviewState {
  const ReviewState({this.box = 0, this.due, this.ups = 0, this.downs = 0});

  final int box;

  /// Null means never reviewed, which is due now.
  final DateTime? due;
  final int ups;
  final int downs;

  bool get learned => box >= kLearnedBox;

  /// The last answer was 👍. A card answered 👎 and never since is the
  /// opposite; a card never answered is neither.
  bool get known => box > 0;

  bool isDue(DateTime now) => due == null || !due!.isAfter(now);

  ReviewState answer({required bool knewIt, required DateTime now}) {
    final nextBox = knewIt ? (box + 1).clamp(0, kTopBox) : 0;
    return ReviewState(
      box: nextBox,
      due: now.add(Duration(days: kBoxIntervalsDays[nextBox])),
      ups: ups + (knewIt ? 1 : 0),
      downs: downs + (knewIt ? 0 : 1),
    );
  }

  Map<String, dynamic> toJson() => {
    'box': box,
    if (due != null) 'due': due!.toIso8601String(),
    'ups': ups,
    'downs': downs,
  };

  factory ReviewState.fromJson(Map<String, dynamic>? j) {
    if (j == null) return const ReviewState();
    return ReviewState(
      box: ((j['box'] as num?)?.toInt() ?? 0).clamp(0, kTopBox),
      due: DateTime.tryParse(j['due'] as String? ?? ''),
      ups: (j['ups'] as num?)?.toInt() ?? 0,
      downs: (j['downs'] as num?)?.toInt() ?? 0,
    );
  }
}

/// The order to study [items] in: everything due first (lowest box, then
/// longest overdue, then insertion order), then the rest soonest-due
/// first. Nothing is hidden — a deck you want to run through again today
/// is still all there, just with the cards that need it at the front.
List<T> studyOrder<T>(
  List<T> items,
  ReviewState Function(T) stateOf,
  DateTime now,
) {
  final indexed = [for (var i = 0; i < items.length; i++) (i, items[i])];
  int rank((int, T) e) => stateOf(e.$2).isDue(now) ? 0 : 1;
  indexed.sort((a, b) {
    final r = rank(a).compareTo(rank(b));
    if (r != 0) return r;
    final sa = stateOf(a.$2);
    final sb = stateOf(b.$2);
    if (rank(a) == 0) {
      final byBox = sa.box.compareTo(sb.box);
      if (byBox != 0) return byBox;
    }
    final da = sa.due ?? DateTime.fromMillisecondsSinceEpoch(0);
    final db = sb.due ?? DateTime.fromMillisecondsSinceEpoch(0);
    final byDue = da.compareTo(db);
    return byDue != 0 ? byDue : a.$1.compareTo(b.$1);
  });
  return [for (final e in indexed) e.$2];
}

int dueCount<T>(List<T> items, ReviewState Function(T) stateOf, DateTime now) =>
    items.where((e) => stateOf(e).isDue(now)).length;
