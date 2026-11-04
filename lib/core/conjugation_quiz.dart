/// "How do you make this past tense?" — conjugation as a quiz.
///
/// A question is a verb and a form to make of it; the answer comes from
/// the conjugation map (conjugate.dart), so it's never wrong. The wrong
/// choices are the mistakes people make:
///
/// - the other group's rule: 帰る treated as ichidan (帰た), 食べる as godan
///   (食べった) — the classic error, since both end in る;
/// - the wrong te/ta row for a godan verb: 書く → 書って, 書んで;
/// - the masu-stem with the ending stuck on: 書きた, 書きて;
/// - a real form of the verb that isn't the one asked for: 食べなかった
///   when the past was asked.
///
/// Scheduled per rule — a form for a kind of verb, "te-form of く-verbs" —
/// since that's what's learned, not the verb.
///
/// Pure Dart: tested without Flutter.
library;

import 'conjugate.dart';

/// The forms quizzed: map node id, and how the question names it.
const List<(String, String)> kQuizForms = [
  ('polite', 'polite (〜ます)'),
  ('negative', 'negative (not)'),
  ('past', 'past (did)'),
  ('negative/past', 'past negative (did not)'),
  ('te', 'te-form (and…)'),
  ('polite/past', 'polite past'),
  ('polite/negative', 'polite negative'),
  ('potential', 'potential (can)'),
  ('volitional', "volitional (let's)"),
  ('conditional', 'conditional (if, 〜ば)'),
  ('past/if', 'if / when (〜たら)'),
  ('polite/want', 'want to (〜たい)'),
  ('te/progressive', 'is doing (〜ている)'),
  ('passive', 'passive (is done)'),
  ('causative', 'causative (make / let)'),
  ('imperative', 'command (rough)'),
];

String quizFormName(String id) =>
    kQuizForms.firstWhere((f) => f.$1 == id, orElse: () => (id, id)).$2;

/// The kind of verb a rule is about: its group, and for godan its ending
/// (each row conjugates its own way), with 行く apart.
String verbKind(Verb v) => switch (v.group) {
  VerbGroup.ichidan => 'ichidan',
  VerbGroup.suru => 'する',
  VerbGroup.kuru => 'くる',
  VerbGroup.godan when v.special == 'iku' => '行く',
  VerbGroup.godan => '〜${v.reading[v.reading.length - 1]}',
};

/// How a kind is named to a learner.
String verbKindName(String kind) => switch (kind) {
  'ichidan' => 'ichidan (る) verbs',
  'する' => 'する verbs',
  'くる' => 'くる',
  '行く' => '行く',
  _ => 'godan $kind verbs',
};

/// The schedule key for making [formId] of [kind] verbs.
String conjugationRule(String kind, String formId) => 'conj:$kind:$formId';

class ConjugationQuestion {
  const ConjugationQuestion({
    required this.verb,
    required this.formId,
    required this.answer,
    required this.choices,
    required this.form,
  });

  final Verb verb;
  final String formId;
  final String answer;
  final List<String> choices;

  /// The answer's place on the map, for its route and rule.
  final VerbForm form;

  String get rule => conjugationRule(verbKind(verb), formId);
}

VerbForm? _at(VerbForm root, String id) =>
    root.all.where((f) => f.id == id).firstOrNull;

/// The question "make [formId] of [v]", with four choices.
ConjugationQuestion conjugationQuestion(Verb v, String formId, int seed) {
  final root = conjugate(v);
  final form = _at(root, formId)!;
  final answer = form.text.written;
  // Never offered as wrong: anything else on the map that means the same
  // (ら-less 食べれる for the potential, 食べられる as passive too).
  final alsoRight = {
    for (final f in root.all)
      if (f.id.startsWith('$formId/casual')) f.text.written,
  };

  final wrong = <String>[];
  void add(String? s) {
    if (s == null || s.isEmpty || s == answer || alsoRight.contains(s)) {
      return;
    }
    if (!wrong.contains(s)) wrong.add(s);
  }

  // The other group's rule, where it can apply (a る-ending verb).
  if (v.reading.endsWith('る') && v.written.endsWith('る')) {
    if (v.group == VerbGroup.ichidan) {
      add(
        _at(
          conjugate(Verb(v.written, v.reading, VerbGroup.godan)),
          formId,
        )?.text.written,
      );
    } else if (v.group == VerbGroup.godan && v.special.isEmpty) {
      add(
        _at(
          conjugate(Verb(v.written, v.reading, VerbGroup.ichidan)),
          formId,
        )?.text.written,
      );
    }
  }

  // The wrong te/ta row, and the masu-stem with the ending stuck on.
  final te = _at(root, 'te')!.text.written;
  final ta = _at(root, 'past')!.text.written;
  final masuStem = _at(root, 'polite')!.text.written;
  final stem = masuStem.substring(0, masuStem.length - 2);
  if (v.group == VerbGroup.godan) {
    // 書いて… built on the te- or ta-form: the same, on the wrong row.
    final dict = v.written.substring(0, v.written.length - 1);
    if (answer.startsWith(te)) {
      final tail = answer.substring(te.length);
      for (final row in ['って', 'んで', 'いて']) {
        add('$dict$row$tail');
      }
    } else if (answer.startsWith(ta)) {
      final tail = answer.substring(ta.length);
      for (final row in ['った', 'んだ', 'いた']) {
        add('$dict$row$tail');
      }
    }
  }
  if (formId == 'past' || formId == 'te' || formId.startsWith('past/')) {
    final ending = formId == 'te' ? 'て' : 'た';
    add('$stem$ending${formId == 'past/if' ? 'ら' : ''}');
  }

  // Real forms that aren't the one asked for: near ones first.
  const near = {
    'past': ['negative/past', 'te/progressive/casual/past', 'polite/past'],
    'negative': ['negative/past', 'polite/negative', 'potential/negative'],
    'negative/past': ['past', 'negative', 'polite/negative/past'],
    'te': ['past', 'te/progressive', 'conditional'],
    'polite': ['polite/past', 'polite/negative', 'polite/volitional'],
    'polite/past': ['polite', 'past', 'polite/negative/past'],
    'polite/negative': ['polite', 'negative', 'polite/negative/past'],
    'potential': ['passive', 'causative', 'volitional'],
    'volitional': ['polite/volitional', 'imperative', 'conditional'],
    'conditional': ['past/if', 'volitional', 'potential'],
    'past/if': ['conditional', 'past', 'te'],
    'polite/want': ['polite', 'polite/want/past', 'volitional'],
    'te/progressive': ['te/progressive/casual', 'te', 'past'],
    'passive': ['causative', 'potential', 'causative/passive'],
    'causative': ['passive', 'causative/passive', 'potential'],
    'imperative': ['volitional', "imperative/don't", 'conditional'],
  };
  for (final id in near[formId] ?? const <String>[]) {
    add(_at(root, id)?.text.written);
  }
  // Short of three: any other quizzed form.
  for (final (id, _) in kQuizForms) {
    if (wrong.length >= 6) break;
    if (id != formId) add(_at(root, id)?.text.written);
  }

  // Up to three, the made-up mistakes first: they're the ones that teach.
  final picked = wrong.take(3).toList();
  final choices = [answer, ...picked];
  final order = [for (var i = 0; i < choices.length; i++) i]
    ..sort((a, b) => ((a * 7 + seed) % 11).compareTo((b * 7 + seed) % 11));
  return ConjugationQuestion(
    verb: v,
    formId: formId,
    answer: answer,
    choices: [for (final i in order) choices[i]],
    form: _at(root, formId)!,
  );
}
