/// Grammar drills: particles, and joining words.
///
/// Both are rules rather than vocabulary, so both are scheduled per rule —
/// を for the object, に for where something goes, ても for "even if" —
/// and each question is built from a rule and a verb: the learner's own
/// verbs where there are some, a core set otherwise. A session takes the
/// rules that are due first, then new ones; a first answer that's right
/// counts as Good, a wrong one as Again.
library;

import 'dart:math';

import 'package:flutter/material.dart';

import '../core/conjugate.dart';
import '../core/joining.dart';
import '../core/particles.dart';
import '../core/srs.dart';
import '../services/speech.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'conjugation_screen.dart';

enum Drill { particles, joining }

const int kGrammarSessionLength = 10;

/// Verbs the joining drill can always use, with their groups.
const kCoreJoinVerbs = [
  Verb('食べる', 'たべる', VerbGroup.ichidan),
  Verb('見る', 'みる', VerbGroup.ichidan),
  Verb('寝る', 'ねる', VerbGroup.ichidan),
  Verb('飲む', 'のむ', VerbGroup.godan),
  Verb('書く', 'かく', VerbGroup.godan),
  Verb('読む', 'よむ', VerbGroup.godan),
  Verb('行く', 'いく', VerbGroup.godan, special: 'iku'),
  Verb('遊ぶ', 'あそぶ', VerbGroup.godan),
  Verb('待つ', 'まつ', VerbGroup.godan),
  Verb('話す', 'はなす', VerbGroup.godan),
  Verb('買う', 'かう', VerbGroup.godan),
  Verb('する', 'する', VerbGroup.suru),
  Verb('来る', 'くる', VerbGroup.kuru),
];

/// The rules due for practice, in the order a session takes them: due
/// ones (most overdue first), then new ones, then the rest by due date.
List<String> rulesInOrder(
  List<String> ids,
  ReviewState Function(String) state,
  DateTime now,
) {
  int rank(ReviewState s) => s.isNew ? 1 : (s.isDue(now) ? 0 : 2);
  final sorted = [...ids];
  sorted.sort((a, b) {
    final sa = state(a);
    final sb = state(b);
    final r = rank(sa).compareTo(rank(sb));
    if (r != 0) return r;
    if (sa.due != null && sb.due != null) return sa.due!.compareTo(sb.due!);
    return ids.indexOf(a).compareTo(ids.indexOf(b));
  });
  return sorted;
}

/// One question, either kind.
class _Q {
  _Q.particle(this.gap, int seed)
    : join = null,
      ruleId = gap!.ruleId,
      answer = gap.rule.particle,
      choices = choicesFor(gap, seed);

  _Q.join(this.join)
    : gap = null,
      ruleId = join!.joinerId,
      answer = join.answer,
      choices = join.choices;

  final ParticleGap? gap;
  final JoinQuestion? join;
  final String ruleId;
  final String answer;
  final List<String> choices;

  bool isRight(String c) =>
      gap != null ? gap!.answers.contains(c) : c == answer;
}

class GrammarScreen extends StatefulWidget {
  const GrammarScreen({super.key, required this.drill, this.mangaId});

  final Drill drill;

  /// Whose verbs to build questions from (null: every word).
  final String? mangaId;

  @override
  State<GrammarScreen> createState() => _GrammarScreenState();
}

class _GrammarScreenState extends State<GrammarScreen> {
  final _random = Random();
  List<_Q> _questions = [];
  int _index = 0;
  String? _picked;
  int _right = 0;
  final List<String> _missed = [];

  bool get _particles => widget.drill == Drill.particles;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_questions.isEmpty) _questions = _build();
  }

  List<_Q> _build() {
    final lib = AppScope.read(context);
    final mine = [for (final w in lib.wordsFor(widget.mangaId)) w.entry];
    final ruleIds = _particles
        ? [for (final r in kParticleRules) r.id]
        : [for (final j in kJoiners) j.id];
    final order = rulesInOrder(
      ruleIds,
      lib.grammarState,
      DateTime.now(),
    ).take(kGrammarSessionLength).toList();
    X pick<X>(List<X> xs) => xs[_random.nextInt(xs.length)];

    if (_particles) {
      // Your verbs' gaps preferred; the core set and the hand-written gaps
      // make sure every rule has some.
      final yours = [for (final e in mine) ...gapsForVerb(e)];
      final core = [
        ...kFixedGaps,
        for (final e in kCoreVerbs) ...gapsForVerb(e),
      ];
      return [
        for (final id in order)
          _Q.particle(
            pick(
              yours.where((g) => g.ruleId == id).isNotEmpty &&
                      _random.nextBool()
                  ? yours.where((g) => g.ruleId == id).toList()
                  : core.where((g) => g.ruleId == id).toList(),
            ),
            _random.nextInt(1000),
          ),
      ];
    }
    final verbs = <Verb>[for (final e in mine) ?Verb.fromEntry(e)];
    return [
      for (final id in order)
        _Q.join(
          joinQuestion(
            verbs.isNotEmpty && _random.nextBool()
                ? pick(verbs)
                : pick(kCoreJoinVerbs),
            joiner(id),
            _random.nextInt(1000),
          ),
        ),
    ];
  }

  void _answer(String c) {
    if (_picked != null) return;
    final q = _questions[_index];
    final right = q.isRight(c);
    setState(() {
      _picked = c;
      if (right) {
        _right++;
      } else {
        _missed.add(q.ruleId);
      }
    });
    AppScope.read(context)
        .gradeGrammar(q.ruleId, right ? Grade.good : Grade.again);
    // Hear it said right.
    final said = q.gap != null
        ? '${q.gap!.before}${q.answer}${q.gap!.after}'
        : q.answer;
    Speech.instance.say(said);
  }

  void _next() => setState(() {
    _index++;
    _picked = null;
  });

  void _again() => setState(() {
    _questions = _build();
    _index = 0;
    _picked = null;
    _right = 0;
    _missed.clear();
  });

  void _showRules() {
    final lib = AppScope.read(context);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.8,
        builder: (context, scroll) => ListView(
          controller: scroll,
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
          children: [
            Text(
              _particles ? 'Particle rules' : 'Joining words',
              style: T.headlineMd,
            ),
            const SizedBox(height: 10),
            if (_particles)
              for (final r in kParticleRules)
                _RuleCard(
                  title: '${r.particle}  ·  ${r.job}',
                  example: r.example,
                  english: r.english,
                  note: r.note,
                  state: lib.grammarState(r.id),
                )
            else
              for (final j in kJoiners)
                _RuleCard(
                  title: '〜${j.joiner}  ·  ${j.meaning}',
                  example: j.example,
                  english: j.english,
                  note:
                      'Attaches to the ${j.baseName}: '
                      '食べる → ${joined(kCoreJoinVerbs.first, j)}',
                  state: lib.grammarState(j.id),
                ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final done = _index >= _questions.length;
    return GridScaffold(
      onBack: () => Navigator.maybePop(context),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _particles ? 'Particles' : 'Joining words',
                  style: T.headlineMd,
                ),
              ),
              TextButton.icon(
                onPressed: _showRules,
                icon: const Icon(Icons.menu_book_outlined, size: 18),
                label: const Text('Rules'),
              ),
            ],
          ),
          if (!done) ...[
            Text('${_index + 1} / ${_questions.length}', style: T.monoSm),
            const SizedBox(height: 12),
            _question(_questions[_index]),
          ] else
            _summary(),
        ],
      ),
    );
  }

  Widget _question(_Q q) {
    final answered = _picked != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Panel(
          child: Column(
            children: [
              if (q.gap != null) ...[
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: q.gap!.before),
                      TextSpan(
                        text: answered ? ' ${q.answer} ' : ' ＿ ',
                        style: TextStyle(color: answered ? C.lime : C.textDim),
                      ),
                      TextSpan(text: q.gap!.after),
                    ],
                  ),
                  textAlign: TextAlign.center,
                  style: T.jp.copyWith(
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  q.gap!.english,
                  textAlign: TextAlign.center,
                  style: T.bodyMd.copyWith(color: C.textDim),
                ),
              ] else ...[
                Text(
                  q.join!.verb.written,
                  style: T.jp.copyWith(
                    fontSize: 30,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '+ ${q.join!.joinerRule.meaning}',
                  textAlign: TextAlign.center,
                  style: T.bodyLg.copyWith(color: C.lime),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        for (final c in q.choices)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _Choice(
              text: c,
              state: !answered
                  ? null
                  : q.isRight(c)
                  ? true
                  : c == _picked
                  ? false
                  : null,
              onTap: () => _answer(c),
            ),
          ),
        if (answered) ...[
          const SizedBox(height: 4),
          _feedback(q),
          const SizedBox(height: 12),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: C.lime,
              foregroundColor: C.onLime,
              minimumSize: const Size.fromHeight(52),
            ),
            onPressed: _next,
            child: Text(_index + 1 == _questions.length ? 'Finish' : 'Next'),
          ),
        ],
      ],
    );
  }

  Widget _feedback(_Q q) {
    final right = q.isRight(_picked!);
    if (q.gap != null) {
      final r = q.gap!.rule;
      return _RuleCard(
        title: '${right ? 'Right' : 'Not quite'} — ${r.particle}: ${r.job}',
        example: r.example,
        english: r.english,
        note: r.note,
        good: right,
      );
    }
    final j = q.join!.joinerRule;
    final v = q.join!.verb;
    final base = joinBases(v)[j.base]!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _RuleCard(
          title:
              '${right ? 'Right' : 'Not quite'} — 〜${j.joiner}: ${j.meaning}',
          example: j.example,
          english: j.english,
          note:
              '〜${j.joiner} attaches to the ${j.baseName}: '
              '${v.written} → $base → ${q.answer}',
          good: right,
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => Navigator.of(context, rootNavigator: true).push(
              MaterialPageRoute(
                builder: (_) => ConjugationScreen(verb: v, onPage: base),
              ),
            ),
            icon: const Icon(Icons.hub_outlined, size: 18),
            label: Text('$base on the verb map'),
          ),
        ),
      ],
    );
  }

  Widget _summary() {
    final missed = _missed.toSet();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 24),
        Text(
          '$_right / ${_questions.length}',
          textAlign: TextAlign.center,
          style: T.headlineMd.copyWith(fontSize: 44, color: C.lime),
        ),
        const SizedBox(height: 8),
        Text(
          missed.isEmpty
              ? 'Every rule right.'
              : 'Missed rules come back sooner.',
          textAlign: TextAlign.center,
          style: T.bodyMd.copyWith(color: C.textDim),
        ),
        const SizedBox(height: 16),
        for (final id in missed)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              _particles
                  ? '${particleRule(id).particle} — ${particleRule(id).job}'
                  : '〜${joiner(id).joiner} — ${joiner(id).meaning}',
              textAlign: TextAlign.center,
              style: T.bodyLg,
            ),
          ),
        const SizedBox(height: 16),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: C.lime,
            foregroundColor: C.onLime,
            minimumSize: const Size.fromHeight(52),
          ),
          onPressed: _again,
          child: const Text('Another round'),
        ),
        TextButton(
          onPressed: () => Navigator.maybePop(context),
          child: const Text('Done'),
        ),
      ],
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 22),
    decoration: BoxDecoration(
      color: C.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: C.border),
    ),
    child: child,
  );
}

class _Choice extends StatelessWidget {
  const _Choice({required this.text, required this.state, required this.onTap});

  final String text;

  /// Null before answering (and for choices that played no part), true
  /// for the right one, false for a wrong pick.
  final bool? state;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colour = switch (state) {
      true => C.mint,
      false => C.danger,
      null => C.border,
    };
    return Material(
      color: C.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colour, width: state == null ? 1 : 2),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: T.jp.copyWith(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: state == null ? C.text : colour,
            ),
          ),
        ),
      ),
    );
  }
}

/// A rule: its name, an example with the key part lit, why.
class _RuleCard extends StatelessWidget {
  const _RuleCard({
    required this.title,
    required this.example,
    required this.english,
    required this.note,
    this.state,
    this.good,
  });

  final String title;

  /// With the particle in 【】, which is shown lit.
  final String example;
  final String english;
  final String note;
  final ReviewState? state;
  final bool? good;

  @override
  Widget build(BuildContext context) {
    final parts = example.split(RegExp('[【】]'));
    final status = switch (state) {
      null => null,
      final s when s.isNew => 'new',
      final s when s.learned => 'learned',
      _ => 'learning',
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: C.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: switch (good) {
            true => C.mint,
            false => C.danger,
            null => C.border,
          },
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: T.bodyLg.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              if (status != null)
                Text(
                  status,
                  style: T.monoSm.copyWith(
                    color: status == 'learned' ? C.mint : C.textDim,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text.rich(
            TextSpan(
              children: [
                for (final (i, p) in parts.indexed)
                  TextSpan(
                    text: p,
                    style: i.isOdd ? const TextStyle(color: C.lime) : null,
                  ),
              ],
            ),
            style: T.jp.copyWith(fontSize: 20),
          ),
          Text(english, style: T.bodyMd.copyWith(color: C.textDim)),
          const SizedBox(height: 6),
          Text(note, style: T.bodyMd.copyWith(fontSize: 13)),
        ],
      ),
    );
  }
}
