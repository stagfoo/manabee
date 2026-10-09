/// Kanji Chain: the rules of the slingshot game, without the slingshot.
///
/// Kanji are built from parts — 明 is 日 + 月, 休 is 亻 + 木 — and results
/// are parts too, so they chain: 木 + 木 makes 林, and 木 + 林 makes 森.
/// The board holds parts; the slingshot holds one; firing it into a part
/// it combines with merges them into the kanji they make, which stays on
/// the board for the next shot.
///
/// The game is always winnable: every part loaded into the slingshot
/// combines with something on the board. It starts with first- and
/// second-grade kanji and widens the pool as the score grows.
///
/// Pure Dart; every random choice goes through the [Random] passed in.
library;

import 'dart:math';

class Combo {
  const Combo({
    required this.kanji,
    required this.a,
    required this.b,
    this.position = '',
    required this.grade,
    this.meanings = const [],
    this.on = const [],
    this.kun = const [],
  });

  /// The kanji made.
  final String kanji;

  /// Its two parts, as drawn (亻, not 人).
  final String a;
  final String b;

  /// Where [a] sits: left, top, kamae (enclosing)…
  final String position;

  /// School grade, 1-6, or 8 for the rest of the jouyou set.
  final int grade;
  final List<String> meanings;
  final List<String> on;
  final List<String> kun;

  factory Combo.fromJson(Map<String, dynamic> j) => Combo(
    kanji: j['k'] as String,
    a: j['a'] as String,
    b: j['b'] as String,
    position: j['p'] as String? ?? '',
    grade: (j['g'] as num).toInt(),
    meanings: [for (final m in j['m'] as List? ?? const []) '$m'],
    on: [for (final r in j['on'] as List? ?? const []) '$r'],
    kun: [for (final r in j['kun'] as List? ?? const []) '$r'],
  );

  bool uses(String part) => a == part || b == part;

  /// The other part, given one of them.
  String other(String part) => a == part ? b : a;
}

/// Every combination, looked up by the parts.
class ComboBook {
  ComboBook(List<Combo> combos) : combos = List.unmodifiable(combos) {
    for (final c in combos) {
      // First (easiest, as the list is sorted by grade) wins a pair.
      _byPair.putIfAbsent(_key(c.a, c.b), () => c);
      _byPart.putIfAbsent(c.a, () => []).add(c);
      if (c.b != c.a) _byPart.putIfAbsent(c.b, () => []).add(c);
    }
  }

  final List<Combo> combos;
  final Map<String, Combo> _byPair = {};
  final Map<String, List<Combo>> _byPart = {};

  static String _key(String x, String y) =>
      x.compareTo(y) <= 0 ? '$x|$y' : '$y|$x';

  /// What [x] and [y] make together, in either order, or null.
  Combo? combine(String x, String y) => _byPair[_key(x, y)];

  /// Combinations [part] is in, up to [maxGrade].
  Iterable<Combo> using(String part, int maxGrade) =>
      (_byPart[part] ?? const []).where((c) => c.grade <= maxGrade);
}

class Target {
  const Target(this.glyph, {this.made = false});

  final String glyph;

  /// A kanji built in this game, rather than a part dealt onto the board.
  final bool made;
}

enum ShotResult { merged, wrong, missed }

class ChainGame {
  ChainGame(this.book, this.random, {this.slots = 6}) {
    _refill();
    _loadNext();
  }

  final ComboBook book;
  final Random random;
  final int slots;

  /// The board, one entry per slot; null is an empty slot.
  late final List<Target?> board = List.filled(slots, null);

  /// The part in the slingshot.
  String ammo = '';

  int score = 0;
  int hearts = 3;

  /// Merges in a row onto kanji built this game — 林 then 森 is a chain
  /// of 2 — and what multiplies the score.
  int chain = 0;

  /// Every kanji built, in order.
  final List<Combo> made = [];

  /// The last merge, for the screen to announce.
  Combo? last;

  bool get over => hearts <= 0;

  /// The pool widens with the score: grades 1-2 to start, a grade per 60
  /// points, then the whole jouyou set.
  int get maxGrade {
    final g = 2 + score ~/ 60;
    return g >= 7 ? 8 : g;
  }

  /// The slingshot's part hit slot [i].
  ShotResult hit(int i) {
    final t = board[i];
    if (over || t == null) return ShotResult.missed;
    final c = book.combine(ammo, t.glyph);
    if (c == null) {
      _lose();
      return ShotResult.wrong;
    }
    chain = t.made ? chain + 1 : 1;
    score += 10 * chain;
    board[i] = Target(c.kanji, made: true);
    made.add(c);
    last = c;
    _refill();
    _loadNext();
    return ShotResult.merged;
  }

  /// The shot flew off without hitting anything.
  ShotResult miss() {
    if (!over) _lose();
    return ShotResult.missed;
  }

  void _lose() {
    hearts--;
    chain = 0;
  }

  /// Slots [i] could merge with the slingshot's part.
  List<int> get goodSlots => [
    for (var i = 0; i < board.length; i++)
      if (board[i] != null && book.combine(ammo, board[i]!.glyph) != null) i,
  ];

  /// Loads a part that combines with something on the board — preferring
  /// kanji built this game, so chains are on offer. If nothing on the
  /// board can combine at this grade, one slot is dealt a fresh pair's
  /// other half.
  void _loadNext() {
    final options = <(Combo, String)>[];
    for (final t in board) {
      if (t == null) continue;
      for (final c in book.using(t.glyph, maxGrade)) {
        final part = c.other(t.glyph);
        options.add((c, part));
        // Built kanji count three times: chains are the point.
        if (t.made) options.addAll([(c, part), (c, part)]);
      }
    }
    if (options.isNotEmpty) {
      ammo = options[random.nextInt(options.length)].$2;
      return;
    }
    final c = _randomCombo();
    final slot = _slotToReplace();
    board[slot] = Target(c.b);
    ammo = c.a;
  }

  /// Empty slots get parts from easy combinations.
  void _refill() {
    for (var i = 0; i < board.length; i++) {
      if (board[i] != null) continue;
      // A part not already on the board, if a few tries find one: two of
      // the same is a wasted slot.
      var part = '';
      for (var tries = 0; tries < 8; tries++) {
        final c = _randomCombo();
        part = random.nextBool() ? c.a : c.b;
        if (!board.any((t) => t?.glyph == part)) break;
      }
      board[i] = Target(part);
    }
  }

  Combo _randomCombo() {
    final pool = book.combos.where((c) => c.grade <= maxGrade).toList();
    return pool[random.nextInt(pool.length)];
  }

  /// A dealt part (not a built kanji) if there is one, else any slot.
  int _slotToReplace() {
    final dealt = [
      for (var i = 0; i < board.length; i++)
        if (board[i]?.made != true) i,
    ];
    final from = dealt.isEmpty ? List.generate(board.length, (i) => i) : dealt;
    return from[random.nextInt(from.length)];
  }
}
