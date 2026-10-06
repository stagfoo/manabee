/// Flash cards, laid out like jlptbenkyo's review screen and run like
/// Anki.
///
/// The question shows as little as possible: the word, big, under its JLPT
/// level. Show answer keeps the question on screen and adds the answer
/// under a rule, as Anki does — the reading, the meanings, and the bubble
/// the word was found in. Four buttons grade it, each labelled with when
/// the card comes back. The session itself (what's due, learning steps,
/// the daily ration of new cards) is core/srs.dart's StudySession.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/srs.dart';
import '../models.dart';
import '../services/speech.dart';
import '../services/store.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/confetti.dart';

class FlashcardsScreen extends StatefulWidget {
  const FlashcardsScreen({super.key, this.mangaId});

  final String? mangaId;

  @override
  State<FlashcardsScreen> createState() => _FlashcardsScreenState();
}

class _FlashcardsScreenState extends State<FlashcardsScreen> {
  late StudySession _session;
  bool _revealed = false;
  int _answered = 0;

  /// Repaints while waiting on a learning step, so the card appears when
  /// it's due without a tap.
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    final lib = AppScope.read(context);
    _session = StudySession(
      {for (final w in lib.wordsFor(widget.mangaId)) w.id: w.review},
      DateTime.now(),
      newLimit: lib.newAllowanceToday(),
    );
    _tick = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  void _grade(String id, Grade grade) {
    final state = _session.answer(id, grade, DateTime.now());
    AppScope.read(context).setReview(id, state);
    HapticFeedback.selectionClick();
    setState(() {
      _revealed = false;
      _answered++;
    });
  }

  void _undo() {
    final undone = _session.undo();
    if (undone == null) return;
    AppScope.read(context).setReview(undone.$1, undone.$2);
    setState(() {
      _revealed = true;
      if (_answered > 0) _answered--;
    });
  }

  void _moreNew() {
    final added = _session.addNew(
      AppScope.read(context).wordsFor(widget.mangaId).map((w) => w.id),
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
    final remaining =
        _session.newCount + _session.learningCount + _session.reviewCount;
    final total = _answered + remaining;

    return Scaffold(
      backgroundColor: C.ground,
      appBar: AppBar(
        backgroundColor: C.ground,
        foregroundColor: C.text,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          tooltip: 'Close',
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: Text(
          word == null ? 'Flash cards' : '$_answered / $total',
          style: T.headlineMd,
        ),
        actions: [
          IconButton(
            tooltip: 'Undo',
            onPressed: _session.canUndo ? _undo : null,
            icon: const Icon(Icons.undo_rounded),
          ),
          if (word != null)
            IconButton(
              tooltip: 'Say it',
              icon: const Icon(Icons.volume_up_outlined),
              onPressed: () => _say(context, word.entry),
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(
            value: total == 0 ? 1 : _answered / total,
            minHeight: 4,
            backgroundColor: C.track,
            color: C.lime,
          ),
        ),
      ),
      body: word == null
          ? _done(lib, now)
          : Column(
              children: [
                Expanded(
                  child: _Face(
                    key: ValueKey('${word.id}:$_revealed'),
                    word: word,
                    revealed: _revealed,
                    mangaTitle: lib.mangaById(word.mangaId)?.title,
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _Counts(
                          newCards: _session.newCount,
                          learning: _session.learningCount,
                          review: _session.reviewCount,
                          current: word.review,
                        ),
                        const SizedBox(height: 12),
                        _revealed
                            ? _GradeRow(
                                previews: previewAll(word.review, now),
                                now: now,
                                onGrade: (g) => _grade(word.id, g),
                              )
                            : _BigButton(
                                label: 'Show answer',
                                onPressed: () =>
                                    setState(() => _revealed = true),
                              ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _done(Library lib, DateTime now) {
    final nextLearning = _session.nextLearningDue;
    if (nextLearning != null) {
      return _DoneMessage(
        icon: Icons.hourglass_top_rounded,
        title: 'Learning cards coming up',
        body:
            'The next is due in ${formatInterval(nextLearning.difference(now))}. '
            'Stay here and it appears on its own.',
      );
    }
    final deck = lib.wordsFor(widget.mangaId);
    final newLeft = deck.where((w) => w.review.isNew).length;
    DateTime? nextDue;
    for (final w in deck) {
      final d = w.review.due;
      if (d != null &&
          d.isAfter(now) &&
          (nextDue == null || d.isBefore(nextDue))) {
        nextDue = d;
      }
    }
    final message = _DoneMessage(
      icon: Icons.check_circle_outline_rounded,
      title: deck.isEmpty
          ? 'No cards yet'
          : _answered > 0
          ? '$_answered reviewed'
          : 'Nothing due right now',
      body: [
        if (deck.isNotEmpty)
          'Congratulations! You have finished this deck for now.',
        if (nextDue != null)
          'Next review in ${formatInterval(nextDue.difference(now))}.',
      ].join(' '),
      actions: [
        if (newLeft > 0) ...[
          OutlinedButton.icon(
            onPressed: _moreNew,
            icon: const Icon(Icons.add_rounded),
            label: Text('Study 10 more new cards ($newLeft left)'),
          ),
          const SizedBox(height: 12),
        ],
        _BigButton(label: 'Back', onPressed: () => Navigator.maybePop(context)),
      ],
    );
    // Finishing a day's cards is the habit worth celebrating — not opening
    // the screen with nothing due.
    if (_answered == 0) return message;
    return Stack(
      children: [
        message,
        const Positioned.fill(child: Confetti()),
      ],
    );
  }
}

Future<void> _say(BuildContext context, Entry e) async {
  final problem = await Speech.instance.say(
    e.reading.isEmpty ? e.word : e.reading,
  );
  if (problem != null && context.mounted) toast(context, problem);
}

/// One card. The question part never moves when the answer appears — only
/// the part below the rule is added — so your eye stays on the word.
class _Face extends StatelessWidget {
  const _Face({
    super.key,
    required this.word,
    required this.revealed,
    this.mangaTitle,
  });

  final Word word;
  final bool revealed;
  final String? mangaTitle;

  @override
  Widget build(BuildContext context) {
    final e = word.entry;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 16),
        Center(child: _LevelChip(e.jlpt)),
        const SizedBox(height: 16),
        Center(
          child: Text(e.word, style: Jp.word, textAlign: TextAlign.center),
        ),
        if (revealed) ...[
          const SizedBox(height: 12),
          const Divider(color: C.border, thickness: 1, height: 24),
          // The reading is only worth showing when it differs from the
          // written form; a kana word already is its reading.
          if (e.hasKanji) Center(child: Text(e.reading, style: Jp.reading)),
          Center(
            child: Text(
              e.romaji,
              style: T.monoBold.copyWith(color: C.textDim, fontSize: 14),
            ),
          ),
          const SizedBox(height: 20),
          Center(
            child: Text(
              e.shortMeaning,
              textAlign: TextAlign.center,
              style: T.headlineMd.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          if (e.senses.isNotEmpty &&
              e.senses.first.partsOfSpeech.isNotEmpty) ...[
            const SizedBox(height: 6),
            Center(
              child: Text(
                e.senses.first.partsOfSpeech.join(', '),
                textAlign: TextAlign.center,
                style: T.bodyMd.copyWith(color: C.textDim, fontSize: 12),
              ),
            ),
          ],
          if (e.common || e.wanikani != null) ...[
            const SizedBox(height: 8),
            Center(
              child: Wrap(
                spacing: 6,
                alignment: WrapAlignment.center,
                children: [
                  if (e.common) const _Tag('common'),
                  if (e.wanikani != null) _Tag('WaniKani ${e.wanikani}'),
                ],
              ),
            ),
          ],
          if (e.senses.length > 1 ||
              (e.senses.isNotEmpty && e.senses.first.glosses.length > 2)) ...[
            const SizedBox(height: 16),
            _Senses(e),
          ],
          // Only when the word is really in it: words saved before 1.0.6
          // could carry whichever bubble happened to be selected.
          if (findInSentence(e, word.context) case final match?) ...[
            const SizedBox(height: 12),
            _ContextCard(text: word.context, match: match, source: mangaTitle),
          ],
        ],
      ],
    );
  }
}

class _LevelChip extends StatelessWidget {
  const _LevelChip(this.level);

  final String? level;

  @override
  Widget build(BuildContext context) {
    final colour = jlptColour(level);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: colour.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        level ?? 'not on a JLPT list',
        style: T.pill.copyWith(color: level == null ? C.textDim : colour),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Chip(
    label: Text(label, style: T.bodyMd.copyWith(fontSize: 11)),
    visualDensity: VisualDensity.compact,
    backgroundColor: C.surface,
    side: const BorderSide(color: C.border),
  );
}

/// Every sense, numbered, for words with more than the one-line meaning.
class _Senses extends StatelessWidget {
  const _Senses(this.entry);

  final Entry entry;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: C.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < entry.senses.length && i < 6; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: '${i + 1}. ',
                        style: const TextStyle(color: C.textDim),
                      ),
                      TextSpan(text: entry.senses[i].glosses.join('; ')),
                      if (entry.senses[i].partsOfSpeech.isNotEmpty)
                        TextSpan(
                          text: '  ${entry.senses[i].partsOfSpeech.join(', ')}',
                          style: const TextStyle(
                            color: C.inactive,
                            fontSize: 11,
                          ),
                        ),
                    ],
                  ),
                  style: T.bodyMd,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The bubble the word came from — what jlptbenkyo shows as an example
/// sentence, except this one is from your own book.
class _ContextCard extends StatelessWidget {
  const _ContextCard({required this.text, required this.match, this.source});

  final String text;

  /// Where the word sits in [text], highlighted.
  final (int, int) match;
  final String? source;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: C.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 6, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              source == null
                  ? 'FROM THE PAGE'
                  : 'FROM ${source!.toUpperCase()}',
              style: T.monoSm,
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: text.substring(0, match.$1)),
                    TextSpan(
                      text: text.substring(match.$1, match.$2),
                      style: const TextStyle(
                        color: C.lime,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    TextSpan(text: text.substring(match.$2)),
                  ],
                ),
                style: Jp.sentence,
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: 'Say the sentence',
                icon: const Icon(Icons.volume_up_outlined, color: C.textDim),
                onPressed: () async {
                  final problem = await Speech.instance.say(text);
                  if (problem != null && context.mounted) {
                    toast(context, problem);
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Anki's "12 + 3 + 20": new, learning, review, with the count the current
/// card belongs to underlined.
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
  final ReviewState current;

  @override
  Widget build(BuildContext context) {
    TextSpan count(int n, Color colour, bool on) => TextSpan(
      text: '$n',
      style: TextStyle(
        color: colour,
        fontWeight: FontWeight.w700,
        decoration: on ? TextDecoration.underline : null,
        decorationColor: colour,
        decorationThickness: 2.5,
      ),
    );
    const plus = TextSpan(
      text: '  +  ',
      style: TextStyle(color: C.inactive),
    );
    return Text.rich(
      TextSpan(
        children: [
          count(newCards, Srs.newCards, current.isNew),
          plus,
          count(learning, Srs.learning, current.isLearning),
          plus,
          count(review, Srs.review, current.isReview),
        ],
      ),
      style: T.bodyLg.copyWith(fontSize: 18),
    );
  }
}

/// Again · Hard · Good · Easy, each labelled with where the card lands.
/// Big targets: a mis-tap here costs a card weeks of schedule.
class _GradeRow extends StatelessWidget {
  const _GradeRow({
    required this.previews,
    required this.now,
    required this.onGrade,
  });

  final Map<Grade, ReviewState> previews;
  final DateTime now;
  final ValueChanged<Grade> onGrade;

  static const _buttons = {
    Grade.again: ('Again', Srs.again),
    Grade.hard: ('Hard', Srs.hard),
    Grade.good: ('Good', Srs.good),
    Grade.easy: ('Easy', Srs.easy),
  };

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final g in Grade.values) ...[
          if (g != Grade.again) const SizedBox(width: 8),
          Expanded(
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: _buttons[g]!.$2,
                foregroundColor: Colors.white,
                minimumSize: const Size(0, 60),
                padding: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: () => onGrade(g),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _buttons[g]!.$1,
                      style: T.pill.copyWith(color: Colors.white, fontSize: 16),
                    ),
                    Text(
                      formatInterval(previews[g]!.due!.difference(now)),
                      style: T.bodyMd.copyWith(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _BigButton extends StatelessWidget {
  const _BigButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: FilledButton(
      style: FilledButton.styleFrom(
        backgroundColor: C.lime,
        foregroundColor: C.onLime,
        minimumSize: const Size(0, 60),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: T.pill.copyWith(fontSize: 16),
      ),
      onPressed: onPressed,
      child: Text(label),
    ),
  );
}

class _DoneMessage extends StatelessWidget {
  const _DoneMessage({
    required this.icon,
    required this.title,
    required this.body,
    this.actions = const [],
  });

  final IconData icon;
  final String title;
  final String body;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: C.lime),
            const SizedBox(height: 16),
            Text(title, style: T.headlineLg, textAlign: TextAlign.center),
            if (body.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                body,
                style: T.bodyMd.copyWith(color: C.textDim),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 24),
            ...actions,
          ],
        ),
      ),
    );
  }
}
