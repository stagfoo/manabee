/// Flash cards, run the way Anki runs them.
///
/// Front: furigana, the word, romaji; tap or Show answer to flip. Back:
/// the full entry and four buttons — Again, Hard, Good, Easy — each
/// labelled with when the card will come back. The session holds today's
/// due reviews, cards still in learning, and the day's ration of new cards
/// (core/srs.dart). Cards still being learned come back within the
/// sitting, after their 1- and 10-minute steps.
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/srs.dart';
import '../models.dart';
import '../services/store.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/entry_detail.dart';

class FlashcardsScreen extends StatefulWidget {
  const FlashcardsScreen({super.key, this.mangaId});

  final String? mangaId;

  @override
  State<FlashcardsScreen> createState() => _FlashcardsScreenState();
}

class _FlashcardsScreenState extends State<FlashcardsScreen> {
  late StudySession _session;
  bool _flipped = false;
  int _reviewed = 0;

  /// Repaints while waiting on a learning step, so the card appears when
  /// it's due without a tap.
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _start();
    _tick = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  void _start() {
    final lib = AppScope.read(context);
    _session = StudySession(
      {for (final w in lib.wordsFor(widget.mangaId)) w.id: w.review},
      DateTime.now(),
      newLimit: lib.newAllowanceToday(),
    );
  }

  void _answer(String id, Grade grade) {
    final state = _session.answer(id, grade, DateTime.now());
    AppScope.read(context).setReview(id, state);
    HapticFeedback.selectionClick();
    setState(() {
      _flipped = false;
      _reviewed++;
    });
  }

  void _undo() {
    final undone = _session.undo();
    if (undone == null) return;
    AppScope.read(context).setReview(undone.$1, undone.$2);
    setState(() {
      _flipped = true;
      _reviewed = math.max(0, _reviewed - 1);
    });
  }

  void _moreNew() {
    final lib = AppScope.read(context);
    final added = _session.addNew(
      lib.wordsFor(widget.mangaId).map((w) => w.id),
      10,
    );
    setState(() {});
    if (added == 0) toast(context, 'No new cards left in this deck.');
  }

  @override
  Widget build(BuildContext context) {
    final lib = AppScope.library(context);
    final byId = {for (final w in lib.wordsFor(widget.mangaId)) w.id: w};
    final now = DateTime.now();
    final id = _session.current(now);
    final word = id == null ? null : byId[id];

    return GridScaffold(
      header: false,
      body: Padding(
        padding: const EdgeInsets.fromLTRB(28, 16, 28, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'FLASH CARDS',
                      style: T.headlineMd.copyWith(
                        letterSpacing: 4,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Undo',
                  onPressed: _session.canUndo ? _undo : null,
                  icon: Icon(
                    Icons.undo_rounded,
                    color: _session.canUndo ? C.text : C.inactive,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.maybePop(context),
                  icon: const Icon(Icons.close_rounded, color: C.textDim),
                ),
              ],
            ),
            _Counts(
              newCards: _session.newCount,
              learning: _session.learningCount,
              review: _session.reviewCount,
              current: word == null ? null : _kindOf(word.review),
            ),
            const SizedBox(height: 24),
            if (word == null)
              Expanded(child: _done(lib, now))
            else ...[
              // Square when there's room, smaller when there isn't — a
              // short landscape screen can't fit a full-width square.
              Expanded(
                child: Center(
                  child: AspectRatio(
                    aspectRatio: 1.0,
                    child: GestureDetector(
                      onTap: () => setState(() => _flipped = !_flipped),
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(end: _flipped ? math.pi : 0),
                        duration: const Duration(milliseconds: 380),
                        curve: Curves.easeInOutCubic,
                        builder: (context, angle, _) {
                          final showBack = angle > math.pi / 2;
                          return Transform(
                            alignment: Alignment.center,
                            transform: Matrix4.identity()
                              ..setEntry(3, 2, 0.0012)
                              ..rotateY(angle),
                            child: showBack
                                ? Transform(
                                    alignment: Alignment.center,
                                    transform: Matrix4.identity()
                                      ..rotateY(math.pi),
                                    child: _Back(word),
                                  )
                                : _Front(word),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              if (_flipped)
                _GradeRow(
                  previews: previewAll(word.review, now),
                  now: now,
                  onGrade: (g) => _answer(word.id, g),
                )
              else
                LimeButton(
                  label: 'Show answer',
                  onPressed: () => setState(() => _flipped = true),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _done(Library lib, DateTime now) {
    final nextLearning = _session.nextLearningDue;
    if (nextLearning != null) {
      return EmptyState(
        emoji: '⏳',
        title: 'Learning cards coming up',
        body:
            'The next one is due in ${formatInterval(nextLearning.difference(now))}. '
            'Stay here and it appears on its own.',
      );
    }
    final deckWords = lib.wordsFor(widget.mangaId);
    final newLeft = deckWords.where((w) => w.review.isNew).length;
    DateTime? nextDue;
    for (final w in deckWords) {
      final d = w.review.due;
      if (d != null &&
          d.isAfter(now) &&
          (nextDue == null || d.isBefore(nextDue))) {
        nextDue = d;
      }
    }
    return EmptyState(
      emoji: '🎉',
      title: deckWords.isEmpty ? 'No cards yet' : 'All caught up',
      body: [
        if (_reviewed > 0)
          'You reviewed $_reviewed card${_reviewed == 1 ? '' : 's'}.',
        if (nextDue != null)
          'Next review in ${formatInterval(nextDue.difference(now))}.',
        if (newLeft > 0) '$newLeft new card${newLeft == 1 ? '' : 's'} waiting.',
      ].join(' '),
      action: newLeft > 0
          ? GhostButton(
              label: 'Study 10 more new cards',
              icon: Icons.add_rounded,
              onPressed: _moreNew,
            )
          : null,
    );
  }
}

enum _Kind { newCard, learning, review }

_Kind _kindOf(ReviewState s) => s.isNew
    ? _Kind.newCard
    : s.isLearning
    ? _Kind.learning
    : _Kind.review;

/// New · Learning · Review, Anki's three counts, with the current card's
/// count underlined.
class _Counts extends StatelessWidget {
  const _Counts({
    required this.newCards,
    required this.learning,
    required this.review,
    required this.current,
  });

  final int newCards;
  final int learning;
  final int review;
  final _Kind? current;

  @override
  Widget build(BuildContext context) {
    Widget count(int n, String label, Color color, _Kind kind) {
      final on = current == kind;
      return Padding(
        padding: const EdgeInsets.only(right: 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$n',
              style: T.headlineMd.copyWith(
                color: color,
                decoration: on ? TextDecoration.underline : null,
                decorationColor: color,
                decorationThickness: 2,
              ),
            ),
            Text(label, style: T.monoSm),
          ],
        ),
      );
    }

    return Row(
      children: [
        count(newCards, 'NEW', C.violet, _Kind.newCard),
        count(learning, 'LEARNING', C.danger, _Kind.learning),
        count(review, 'REVIEW', C.mint, _Kind.review),
      ],
    );
  }
}

/// Again · Hard · Good · Easy, each with when the card would come back.
class _GradeRow extends StatelessWidget {
  const _GradeRow({
    required this.previews,
    required this.now,
    required this.onGrade,
  });

  final Map<Grade, ReviewState> previews;
  final DateTime now;
  final ValueChanged<Grade> onGrade;

  static const _labels = {
    Grade.again: ('Again', C.danger, Colors.black),
    Grade.hard: ('Hard', C.elevated, C.text),
    Grade.good: ('Good', C.lime, C.onLime),
    Grade.easy: ('Easy', C.mint, Colors.black),
  };

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final g in Grade.values)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Column(
                children: [
                  Text(
                    formatInterval(previews[g]!.due!.difference(now)),
                    style: T.monoSm.copyWith(color: C.textDim, fontSize: 11),
                  ),
                  const SizedBox(height: 6),
                  Material(
                    color: _labels[g]!.$2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: g == Grade.hard
                          ? const BorderSide(color: C.ghostBorder, width: 1.5)
                          : BorderSide.none,
                    ),
                    child: InkWell(
                      onTap: () => onGrade(g),
                      borderRadius: BorderRadius.circular(14),
                      child: SizedBox(
                        height: 48,
                        child: Center(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              _labels[g]!.$1,
                              style: T.pill.copyWith(
                                color: _labels[g]!.$3,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _Front extends StatelessWidget {
  const _Front(this.word);

  final Word word;

  @override
  Widget build(BuildContext context) {
    final e = word.entry;
    return Container(
      decoration: BoxDecoration(
        color: C.violet,
        borderRadius: BorderRadius.circular(24),
        border: const Border(
          bottom: BorderSide(color: Color(0x4D000000), width: 2),
        ),
      ),
      child: Stack(
        children: [
          const Positioned(
            top: 16,
            right: 16,
            child: Icon(Icons.u_turn_left_rounded, color: Colors.white),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (e.hasKanji)
                      Text(e.reading, style: T.jp.copyWith(fontSize: 18)),
                    Text(
                      e.word,
                      style: T.jp.copyWith(
                        fontSize: 44,
                        fontWeight: FontWeight.w800,
                        height: 1.25,
                      ),
                    ),
                    Text(e.romaji, style: T.headlineXl.copyWith(fontSize: 40)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Back extends StatelessWidget {
  const _Back(this.word);

  final Word word;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF26262B),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Stack(
        children: [
          const Positioned(
            top: 16,
            right: 16,
            child: Icon(
              Icons.subdirectory_arrow_right_rounded,
              color: Colors.white,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 44, 18, 18),
            child: SingleChildScrollView(
              child: EntryDetail(word.entry, context_: word.context),
            ),
          ),
        ],
      ),
    );
  }
}
