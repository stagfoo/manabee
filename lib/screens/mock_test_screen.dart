/// Mock JLPT tests: the vocabulary paper's first two parts, 漢字読み and
/// 表記, made from native sentences (core/mock_test.dart).
///
/// Run like the real thing rather than like a quiz: no right or wrong
/// shown while you go, an answer can be changed until you move on, and a
/// clock running. Everything is marked at the end, with each sentence's
/// translation, and the words you missed can go straight into a book of
/// their own — where they come up as reading cards.
library;

import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/mock_test.dart';
import '../core/sentences.dart';
import '../models.dart';
import '../services/sentence_bank.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/confetti.dart';
import 'kanji_chain_screen.dart' show loadComboBook;

/// Builds a test at [level] from the bundled sentences and dictionary.
Future<List<MockQuestion>> makeMockTest(
  BuildContext context,
  String level, {
  Random? random,
}) async {
  final dictionary = AppScope.dictionaryOf(context);
  final sentences = await SentenceBank.load();
  final combos = await loadComboBook();
  final words = <String, Entry>{};
  for (final l in kSentenceLevels.sublist(
    0,
    kSentenceLevels.indexOf(level) + 1,
  )) {
    for (final e in await dictionary.jlptWords(l)) {
      words.putIfAbsent('${e.word}|${e.reading}', () => e);
    }
  }
  return buildMockTest(
    level: level,
    sentences: sentences,
    words: words,
    facts: mockKanjiFacts(combos.combos),
    lookup: dictionary.lookup,
    random: random,
  );
}

class MockTestScreen extends StatefulWidget {
  const MockTestScreen({super.key, this.build = makeMockTest});

  /// How a test is made — swapped in tests for one without the real
  /// dictionary.
  final Future<List<MockQuestion>> Function(BuildContext, String) build;

  @override
  State<MockTestScreen> createState() => _MockTestScreenState();
}

class _MockTestScreenState extends State<MockTestScreen> {
  String? _level;
  List<MockQuestion>? _questions;
  List<int?> _answers = [];
  int _index = 0;
  bool _marked = false;
  final _clock = Stopwatch();
  Timer? _tick;
  String? _problem;

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  Future<void> _start(String level) async {
    setState(() {
      _level = level;
      _questions = null;
      _problem = null;
      _marked = false;
      _index = 0;
    });
    try {
      final qs = await widget.build(context, level);
      if (!mounted) return;
      setState(() {
        _questions = qs;
        _answers = List.filled(qs.length, null);
        if (qs.isEmpty) _problem = 'Couldn\'t make a test at $level.';
      });
      _clock
        ..reset()
        ..start();
      _tick?.cancel();
      _tick = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted && !_marked) setState(() {});
      });
    } catch (e) {
      if (mounted) setState(() => _problem = 'Couldn\'t make a test: $e');
    }
  }

  void _finish() {
    final qs = _questions!;
    _clock.stop();
    _tick?.cancel();
    int right(MockSection s) => [
      for (final (i, q) in qs.indexed)
        if (q.section == s && _answers[i] == q.answer) q,
    ].length;
    int total(MockSection s) => qs.where((q) => q.section == s).length;
    AppScope.read(context).addMockResult(
      MockResult(
        level: _level!,
        taken: DateTime.now(),
        readingRight: right(MockSection.reading),
        readingTotal: total(MockSection.reading),
        writingRight: right(MockSection.writing),
        writingTotal: total(MockSection.writing),
        seconds: _clock.elapsed.inSeconds,
      ),
    );
    HapticFeedback.mediumImpact();
    setState(() => _marked = true);
  }

  @override
  Widget build(BuildContext context) {
    final qs = _questions;
    return GridScaffold(
      header: false,
      body: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Header(
              title: _level == null ? 'MOCK TEST' : 'MOCK $_level',
              clock: _level == null || qs == null || qs.isEmpty
                  ? null
                  : _clock.elapsed,
              onClose: () => Navigator.maybePop(context),
            ),
            const SizedBox(height: 12),
            if (_level == null)
              Expanded(child: _LevelPicker(onPick: _start))
            else if (_problem != null)
              Expanded(
                child: EmptyState(
                  emoji: '😵',
                  title: 'No test this time',
                  body: _problem,
                  action: LimeButton(
                    label: 'Back',
                    onPressed: () => setState(() => _level = null),
                  ),
                ),
              )
            else if (qs == null)
              const Expanded(
                child: Center(child: CircularProgressIndicator(color: C.lime)),
              )
            else if (_marked)
              Expanded(
                child: _Results(
                  level: _level!,
                  questions: qs,
                  answers: _answers,
                  time: _clock.elapsed,
                  onAgain: () => _start(_level!),
                  onLevels: () => setState(() => _level = null),
                ),
              )
            else ...[
              ProgressBar(_index / qs.length, rest: C.track),
              const SizedBox(height: 16),
              Expanded(
                child: _QuestionView(
                  key: ValueKey(_index),
                  question: qs[_index],
                  number: _index + 1,
                  partNumber: _partIndex(qs, _index),
                  partSize: qs
                      .where((q) => q.section == qs[_index].section)
                      .length,
                  picked: _answers[_index],
                  onPick: (i) => setState(() => _answers[_index] = i),
                ),
              ),
              Row(
                children: [
                  if (_index > 0)
                    TextButton.icon(
                      onPressed: () => setState(() => _index--),
                      icon: const Icon(Icons.chevron_left_rounded),
                      label: const Text('Back'),
                    ),
                  if (_index > 0) const SizedBox(width: 8),
                  Expanded(
                    child: LimeButton(
                      label: _index == qs.length - 1 ? 'Mark it' : 'Next',
                      onPressed: _answers[_index] == null
                          ? null
                          : () => _index == qs.length - 1
                                ? _finish()
                                : setState(() => _index++),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Which question of its part this is: 漢字読み 3 of 12.
  int _partIndex(List<MockQuestion> qs, int i) =>
      qs.take(i + 1).where((q) => q.section == qs[i].section).length;
}

String _clockText(Duration d) =>
    '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

class _Header extends StatelessWidget {
  const _Header({required this.title, this.clock, required this.onClose});

  final String title;
  final Duration? clock;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          title,
          style: T.headlineMd.copyWith(
            letterSpacing: 4,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      if (clock != null)
        Text(
          _clockText(clock!),
          style: T.monoBold.copyWith(color: C.lime, fontSize: 14),
        ),
      IconButton(
        tooltip: 'Close',
        onPressed: onClose,
        icon: const Icon(Icons.close_rounded, color: C.textDim),
      ),
    ],
  );
}

class _LevelPicker extends StatelessWidget {
  const _LevelPicker({required this.onPick});

  final void Function(String level) onPick;

  @override
  Widget build(BuildContext context) {
    final lib = AppScope.library(context);
    return ListView(
      children: [
        Text(
          '$kMockReadingQuestions kanji readings (漢字読み) and '
          '$kMockWritingQuestions spellings (表記), the first two parts of '
          'the vocabulary paper, in sentences written by native speakers. '
          'Nothing is marked until the end.',
          style: T.bodyMd.copyWith(color: C.textDim),
        ),
        const SizedBox(height: 16),
        for (final level in kSentenceLevels) ...[
          _LevelCard(
            level: level,
            results: [
              for (final r in lib.mockResults)
                if (r.level == level) r,
            ],
            onStart: () => onPick(level),
          ),
          const SizedBox(height: 10),
        ],
        const SizedBox(height: 8),
        Text(
          'Sentences from tatoeba.org (CC BY 2.0 FR); each is credited in '
          'the marking.',
          style: T.monoSm,
        ),
      ],
    );
  }
}

class _LevelCard extends StatelessWidget {
  const _LevelCard({
    required this.level,
    required this.results,
    required this.onStart,
  });

  final String level;
  final List<MockResult> results;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final last = results.lastOrNull;
    final best = results.isEmpty
        ? null
        : results.reduce(
            (a, b) => a.right * b.total >= b.right * a.total ? a : b,
          );
    return Material(
      color: C.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: C.ghostBorder, width: 1.5),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onStart,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Text(
                level,
                style: T.headlineMd.copyWith(color: jlptColour(level)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  last == null
                      ? 'Not taken yet'
                      : 'Last ${last.right}/${last.total}'
                            '${best == null || identical(best, last) ? '' : ' · best ${best.right}/${best.total}'}'
                            ' · ${results.length} taken',
                  style: T.bodyMd.copyWith(color: C.textDim),
                ),
              ),
              const Icon(Icons.play_arrow_rounded, color: C.lime),
            ],
          ),
        ),
      ),
    );
  }
}

/// The sentence with its word underlined, as the test prints it.
class _Sentence extends StatelessWidget {
  const _Sentence(this.question, {this.style});

  final MockQuestion question;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final s = question.shown;
    final (a, b) = question.underline;
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: s.substring(0, a)),
          TextSpan(
            text: s.substring(a, b),
            style: const TextStyle(
              color: C.lime,
              decoration: TextDecoration.underline,
              decorationColor: C.lime,
              decorationThickness: 2,
            ),
          ),
          TextSpan(text: s.substring(b)),
        ],
      ),
      style: style ?? Jp.sentence,
    );
  }
}

class _QuestionView extends StatelessWidget {
  const _QuestionView({
    super.key,
    required this.question,
    required this.number,
    required this.partNumber,
    required this.partSize,
    required this.picked,
    required this.onPick,
  });

  final MockQuestion question;
  final int number;
  final int partNumber;
  final int partSize;
  final int? picked;
  final ValueChanged<int> onPick;

  @override
  Widget build(BuildContext context) {
    final reading = question.section == MockSection.reading;
    return ListView(
      children: [
        Text(
          reading
              ? 'もんだい1 · 漢字読み  $partNumber / $partSize'
              : 'もんだい2 · 表記  $partNumber / $partSize',
          style: T.monoSm,
        ),
        const SizedBox(height: 4),
        Text(
          reading
              ? 'How is the underlined word read?'
              : 'How is the underlined word written?',
          style: T.bodyMd.copyWith(color: C.textDim),
        ),
        const SizedBox(height: 20),
        _Sentence(question),
        const SizedBox(height: 24),
        for (final (i, o) in question.options.indexed) ...[
          _Option(
            number: i + 1,
            label: o,
            picked: picked == i,
            onTap: () {
              HapticFeedback.selectionClick();
              onPick(i);
            },
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _Option extends StatelessWidget {
  const _Option({
    required this.number,
    required this.label,
    required this.picked,
    required this.onTap,
    this.mark,
  });

  final int number;
  final String label;
  final bool picked;
  final VoidCallback? onTap;

  /// After marking: true for the right answer, false for a wrong pick.
  final bool? mark;

  @override
  Widget build(BuildContext context) {
    final (bg, fg, border) = switch ((mark, picked)) {
      (true, _) => (C.mint, Colors.black, C.mint),
      (false, _) => (C.danger, Colors.black, C.danger),
      (null, true) => (C.lime, C.onLime, C.lime),
      (null, false) => (C.surface, C.text, C.ghostBorder),
    };
    return Material(
      color: bg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: border, width: 1.5),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Text('$number', style: T.monoBold.copyWith(color: fg)),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: T.jp.copyWith(fontSize: 20, height: 1.3, color: fg),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Results extends StatefulWidget {
  const _Results({
    required this.level,
    required this.questions,
    required this.answers,
    required this.time,
    required this.onAgain,
    required this.onLevels,
  });

  final String level;
  final List<MockQuestion> questions;
  final List<int?> answers;
  final Duration time;
  final VoidCallback onAgain;
  final VoidCallback onLevels;

  @override
  State<_Results> createState() => _ResultsState();
}

class _ResultsState extends State<_Results> {
  bool _saved = false;

  List<MockQuestion> get _missed => [
    for (final (i, q) in widget.questions.indexed)
      if (widget.answers[i] != q.answer) q,
  ];

  void _saveMissed() {
    final lib = AppScope.read(context);
    final book = lib.mockMissesBook();
    final added = lib.addEntriesTo(book, _missed.map((q) => q.entry));
    setState(() => _saved = true);
    toast(
      context,
      added == 0
          ? 'Already in “${book.title}”.'
          : 'Added $added to “${book.title}” — they\'ll come up as reading '
                'cards.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final qs = widget.questions;
    int right(MockSection s) => [
      for (final (i, q) in qs.indexed)
        if (q.section == s && widget.answers[i] == q.answer) q,
    ].length;
    int total(MockSection s) => qs.where((q) => q.section == s).length;
    final score = qs.length - _missed.length;
    final good = score >= (qs.length * 0.8).ceil();

    return Stack(
      children: [
        ListView(
          children: [
            Center(
              child: Text(
                '$score / ${qs.length}',
                style: T.headlineXl.copyWith(color: good ? C.mint : C.text),
              ),
            ),
            const SizedBox(height: 4),
            Center(
              child: Text(
                '漢字読み ${right(MockSection.reading)}/${total(MockSection.reading)}'
                '  ·  表記 ${right(MockSection.writing)}/${total(MockSection.writing)}'
                '  ·  ${_clockText(widget.time)}',
                style: T.monoBold.copyWith(color: C.textDim, fontSize: 13),
              ),
            ),
            const SizedBox(height: 16),
            if (_missed.isNotEmpty)
              OutlinedButton.icon(
                onPressed: _saved ? null : _saveMissed,
                icon: Icon(
                  _saved ? Icons.check_rounded : Icons.bookmark_add_outlined,
                ),
                label: Text(
                  _saved
                      ? 'Saved to Mock test misses'
                      : 'Study the ${_missed.length} I missed as reading cards',
                ),
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: widget.onLevels,
                    child: const Text('Levels'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: LimeButton(
                    label: 'Another ${widget.level}',
                    onPressed: widget.onAgain,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            for (final (i, q) in qs.indexed) ...[
              _Marked(number: i + 1, question: q, picked: widget.answers[i]),
              const SizedBox(height: 12),
            ],
          ],
        ),
        if (good)
          const Positioned.fill(child: IgnorePointer(child: Confetti())),
      ],
    );
  }
}

/// One question after marking: the sentence, every option marked, and the
/// word and translation to learn from.
class _Marked extends StatelessWidget {
  const _Marked({
    required this.number,
    required this.question,
    required this.picked,
  });

  final int number;
  final MockQuestion question;
  final int? picked;

  @override
  Widget build(BuildContext context) {
    final q = question;
    final ok = picked == q.answer;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: C.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: ok ? C.mint.withValues(alpha: 0.5) : C.danger,
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                ok ? Icons.check_circle_rounded : Icons.cancel_rounded,
                color: ok ? C.mint : C.danger,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                '$number · ${q.section == MockSection.reading ? '漢字読み' : '表記'}',
                style: T.monoSm,
              ),
            ],
          ),
          const SizedBox(height: 8),
          _Sentence(q, style: Jp.sentence.copyWith(fontSize: 18)),
          const SizedBox(height: 4),
          Text(q.sentence.english, style: T.bodyMd.copyWith(color: C.textDim)),
          const SizedBox(height: 10),
          for (final (i, o) in q.options.indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: _Option(
                number: i + 1,
                label: o,
                picked: picked == i,
                onTap: null,
                mark: i == q.answer
                    ? true
                    : picked == i
                    ? false
                    : null,
              ),
            ),
          const SizedBox(height: 4),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(text: q.entry.word, style: Jp.reading),
                TextSpan(
                  text: '  ${q.entry.reading}  ',
                  style: T.bodyMd.copyWith(color: C.textDim),
                ),
                TextSpan(text: q.entry.shortMeaning, style: T.bodyMd),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(q.sentence.source, style: T.monoSm),
        ],
      ),
    );
  }
}
