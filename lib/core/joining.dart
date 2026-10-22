/// Joining words: how two clauses become one sentence.
///
/// Each joiner attaches to one particular form of the verb before it —
/// から to the plain form (食べるから), ながら to the masu-stem
/// (食べながら), ても to the te-form (食べても) — and that is the whole
/// rule. So a question is built from any verb: given "even if" and 食べる,
/// the answer is the conjugation map's te-form plus も. Wrong choices are
/// either the right joiner on the wrong form (食べるても, which isn't
/// Japanese) or another joiner on its own right form (食べたら, which is
/// Japanese but means something else) — the two mistakes that matter.
///
/// Pure Dart: tested without Flutter.
library;

import 'conjugate.dart';

/// One joiner, and the form it hangs on.
class Joiner {
  const Joiner({
    required this.id,
    required this.joiner,
    required this.meaning,
    required this.base,
    required this.attach,
    required this.example,
    required this.english,
  });

  final String id;

  /// As written after the verb: から, ながら, ても.
  final String joiner;

  /// "because", "even if".
  final String meaning;

  /// The form it attaches to, as a map node id ('' is the dictionary
  /// form, 'polite' the ます form whose stem it takes).
  final String base;

  /// How the base is turned into the joined form.
  final String Function(String base) attach;

  /// A sentence showing it, written by hand.
  final String example;
  final String english;

  /// What the base form is called, for "attaches to the te-form".
  String get baseName => switch (base) {
    '' => 'plain form',
    'polite' => 'masu-stem',
    'te' => 'te-form',
    'past' => 'past (た) form',
    'conditional' => 'ば-form',
    _ => base,
  };
}

String _plus(String s, String add) => '$s$add';
String _stem(String masu) => masu.substring(0, masu.length - 2);

final List<Joiner> kJoiners = [
  Joiner(
    id: 'kara',
    joiner: 'から',
    meaning: 'because',
    base: '',
    attach: (b) => _plus(b, 'から'),
    example: '雨が降るから、行かない。',
    english: "It's raining, so I won't go.",
  ),
  Joiner(
    id: 'node',
    joiner: 'ので',
    meaning: 'since (softer because)',
    base: '',
    attach: (b) => _plus(b, 'ので'),
    example: '時間があるので、手伝います。',
    english: "Since I have time, I'll help.",
  ),
  Joiner(
    id: 'kedo',
    joiner: 'けど',
    meaning: 'but',
    base: '',
    attach: (b) => _plus(b, 'けど'),
    example: '高いけど、買う。',
    english: "It's expensive, but I'll buy it.",
  ),
  Joiner(
    id: 'noni',
    joiner: 'のに',
    meaning: 'even though (and it disappoints)',
    base: '',
    attach: (b) => _plus(b, 'のに'),
    example: '勉強したのに、忘れた。',
    english: 'Even though I studied, I forgot.',
  ),
  Joiner(
    id: 'maeni',
    joiner: '前に',
    meaning: 'before',
    base: '',
    attach: (b) => _plus(b, '前に'),
    example: '寝る前に、歯を磨く。',
    english: 'Before sleeping, I brush my teeth.',
  ),
  Joiner(
    id: 'made',
    joiner: 'まで',
    meaning: 'until',
    base: '',
    attach: (b) => _plus(b, 'まで'),
    example: '母が帰るまで、待つ。',
    english: 'I wait until my mother comes home.',
  ),
  Joiner(
    id: 'nagara',
    joiner: 'ながら',
    meaning: 'while (doing both)',
    base: 'polite',
    attach: (b) => _plus(_stem(b), 'ながら'),
    example: '音楽を聞きながら、勉強する。',
    english: 'I study while listening to music.',
  ),
  Joiner(
    id: 'te',
    joiner: 'て',
    meaning: 'and (then)',
    base: 'te',
    attach: (b) => b,
    example: '朝ご飯を食べて、学校に行く。',
    english: 'I eat breakfast and go to school.',
  ),
  Joiner(
    id: 'tekara',
    joiner: 'てから',
    meaning: 'after',
    base: 'te',
    attach: (b) => _plus(b, 'から'),
    example: '宿題をしてから、遊ぶ。',
    english: "After doing homework, I'll play.",
  ),
  Joiner(
    id: 'temo',
    joiner: 'ても',
    meaning: 'even if',
    base: 'te',
    attach: (b) => _plus(b, 'も'),
    example: '雨が降っても、行く。',
    english: "Even if it rains, I'll go.",
  ),
  Joiner(
    id: 'tara',
    joiner: 'たら',
    meaning: 'if / when (once it happens)',
    base: 'past',
    attach: (b) => _plus(b, 'ら'),
    example: '駅に着いたら、電話して。',
    english: 'When you get to the station, call me.',
  ),
  Joiner(
    id: 'tari',
    joiner: 'たり',
    meaning: 'things like… (listing)',
    base: 'past',
    attach: (b) => _plus(b, 'り'),
    example: '週末は、本を読んだりする。',
    english: 'At weekends I do things like read.',
  ),
  Joiner(
    id: 'ba',
    joiner: 'ば',
    meaning: 'if (as a condition)',
    base: 'conditional',
    attach: (b) => b,
    example: '急げば、間に合う。',
    english: "If you hurry, you'll make it.",
  ),
];

Joiner joiner(String id) => kJoiners.firstWhere((j) => j.id == id);

/// The forms of [v] a joiner can hang on, by map node id.
Map<String, String> joinBases(Verb v) {
  final root = conjugate(v);
  String at(String id) => root.all.firstWhere((f) => f.id == id).text.written;
  return {
    for (final id in ['', 'polite', 'te', 'past', 'conditional']) id: at(id),
  };
}

/// [v] joined with [j]: 食べる + ても → 食べても.
String joined(Verb v, Joiner j) => j.attach(joinBases(v)[j.base]!);

class JoinQuestion {
  const JoinQuestion({
    required this.joinerId,
    required this.verb,
    required this.answer,
    required this.choices,
  });

  final String joinerId;
  final Verb verb;
  final String answer;
  final List<String> choices;

  Joiner get joinerRule => joiner(joinerId);
}

/// A question: join [v] with [j]. Choices are the answer, the same joiner
/// on two wrong forms, and a different joiner on its right form.
JoinQuestion joinQuestion(Verb v, Joiner j, int seed) {
  final bases = joinBases(v);
  final answer = joined(v, j);
  final wrongForms = <String>{
    for (final b in ['', 'past', 'te', 'polite'])
      if (b != j.base && !(_alsoReal[j.id]?.contains(b) ?? false))
        _wrongly(j, bases[b]!, b),
  }..remove(answer);
  // The neighbour most likely confused with it: same "if", same "and".
  const rivals = {
    'kara': 'tekara',
    'tekara': 'kara',
    'node': 'kara',
    'kedo': 'noni',
    'noni': 'temo',
    'temo': 'noni',
    'tara': 'ba',
    'ba': 'tara',
    'te': 'tekara',
    'nagara': 'te',
    'maeni': 'tekara',
    'made': 'maeni',
    'tari': 'tara',
  };
  final rival = joined(v, joiner(rivals[j.id]!));
  final choices = <String>{
    answer,
    if (rival != answer) rival,
    ...wrongForms,
  }.take(4).toList();
  final order = [for (var i = 0; i < choices.length; i++) i]
    ..sort((a, b) => ((a * 5 + seed) % 7).compareTo((b * 5 + seed) % 7));
  return JoinQuestion(
    joinerId: j.id,
    verb: v,
    answer: answer,
    choices: [for (final i in order) choices[i]],
  );
}

/// Bases that look wrong for a joiner but are real Japanese, so never
/// offered as mistakes: から, ので, けど and のに take the past as well
/// (飲んだから, "because I drank"); 飲んでたら is casual 飲んでいたら;
/// 飲んだまで is "did no more than drink".
const _alsoReal = {
  'kara': {'past'},
  'node': {'past'},
  'kedo': {'past'},
  'noni': {'past'},
  'made': {'past'},
  'tara': {'te'},
};

/// [j]'s joiner put on the wrong base [form] — 食べる + ても as 食べるても.
String _wrongly(Joiner j, String form, String base) {
  final tail = switch (j.id) {
    'te' => 'て',
    'tekara' => 'てから',
    'temo' => 'ても',
    'tara' => 'たら',
    'tari' => 'たり',
    'ba' => 'ば',
    _ => j.joiner,
  };
  // A masu form is offered as its stem, the way a joiner would take it.
  final b = base == 'polite' ? _stem(form) : form;
  return '$b$tail';
}
