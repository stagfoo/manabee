/// Multiple choice: alternately "what does this mean?" and "which word is
/// this?". Practice only — it doesn't touch the flash-card schedule.
library;

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/games.dart';
import '../core/kana.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'study_screen.dart';

class QuizScreen extends StatefulWidget {
  const QuizScreen({super.key, this.mangaId});

  final String? mangaId;

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  late List<QuizQuestion> _questions;
  int _index = 0;
  int _score = 0;
  int? _picked;

  @override
  void initState() {
    super.initState();
    _deal();
  }

  void _deal() {
    final words = AppScope.read(context).wordsFor(widget.mangaId);
    _questions = buildQuiz([for (final w in words) gameCardOf(w)], Random());
    _index = 0;
    _score = 0;
    _picked = null;
  }

  void _pick(int i) {
    if (_picked != null) return;
    final q = _questions[_index];
    final right = q.isCorrect(i);
    setState(() {
      _picked = i;
      if (right) _score++;
    });
    right ? HapticFeedback.lightImpact() : HapticFeedback.heavyImpact();
    // Practice only: the schedule belongs to flash cards, as in Anki. A
    // multiple-choice guess is recognition, not recall, and letting it
    // push cards out would have them come back later than they should.
  }

  @override
  Widget build(BuildContext context) {
    final done = _index >= _questions.length;
    return GridScaffold(
      header: false,
      body: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'QUIZ',
                      style: T.headlineMd.copyWith(
                        letterSpacing: 4,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                Text(
                  '$_score / ${_questions.length}',
                  style: T.monoBold.copyWith(color: C.lime, fontSize: 14),
                ),
                IconButton(
                  onPressed: () => Navigator.maybePop(context),
                  icon: const Icon(Icons.close_rounded, color: C.textDim),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ProgressBar(
              _questions.isEmpty ? 0 : _index / _questions.length,
              rest: C.track,
            ),
            const SizedBox(height: 24),
            if (_questions.isEmpty)
              const Expanded(
                child: EmptyState(
                  emoji: '🤔',
                  title: 'Not enough words',
                  body: 'Save a few more words with different meanings.',
                ),
              )
            else if (done)
              Expanded(
                child: EmptyState(
                  emoji: _score == _questions.length ? '🏆' : '🎉',
                  title: '$_score of ${_questions.length} right',
                  action: LimeButton(
                    label: 'Play again',
                    onPressed: () => setState(_deal),
                  ),
                ),
              )
            else
              Expanded(child: _question(_questions[_index])),
          ],
        ),
      ),
    );
  }

  Widget _question(QuizQuestion q) {
    final toMeaning = q.direction == QuizDirection.toMeaning;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          toMeaning ? 'WHAT DOES THIS MEAN?' : 'WHICH WORD IS THIS?',
          style: T.monoSm,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Container(
          constraints: const BoxConstraints(minHeight: 150),
          padding: const EdgeInsets.all(20),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: C.violet,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (toMeaning &&
                  containsKanji(q.card.japanese) &&
                  _picked != null)
                Text(q.card.reading, style: T.jp.copyWith(fontSize: 16)),
              Text(
                q.prompt,
                textAlign: TextAlign.center,
                style: toMeaning
                    ? T.jp.copyWith(
                        fontSize: 40,
                        fontWeight: FontWeight.w800,
                        height: 1.25,
                      )
                    : T.headlineLg,
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        for (var i = 0; i < q.options.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _Option(
              label: q.options[i],
              jp: !toMeaning,
              state: _picked == null
                  ? _OptState.idle
                  : q.isCorrect(i)
                  ? _OptState.right
                  : i == _picked
                  ? _OptState.wrong
                  : _OptState.idle,
              onTap: () => _pick(i),
            ),
          ),
        const Spacer(),
        if (_picked != null)
          LimeButton(
            label: _index + 1 < _questions.length ? 'Next' : 'Finish',
            icon: Icons.arrow_forward_rounded,
            onPressed: () => setState(() {
              _index++;
              _picked = null;
            }),
          ),
      ],
    );
  }
}

enum _OptState { idle, right, wrong }

class _Option extends StatelessWidget {
  const _Option({
    required this.label,
    required this.jp,
    required this.state,
    required this.onTap,
  });

  final String label;
  final bool jp;
  final _OptState state;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (bg, fg, border) = switch (state) {
      _OptState.idle => (C.surface, C.text, C.ghostBorder),
      _OptState.right => (C.mint, Colors.black, C.mint),
      _OptState.wrong => (C.danger, Colors.black, C.danger),
    };
    return Material(
      color: bg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: border, width: 1.5),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: (jp ? T.jp.copyWith(fontSize: 20, height: 1.3) : T.bodyLg)
                .copyWith(color: fg),
          ),
        ),
      ),
    );
  }
}
