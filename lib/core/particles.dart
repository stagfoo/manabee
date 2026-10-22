/// Particles, as rules.
///
/// A particle says what job the word before it does in the sentence — the
/// thing acted on (を), where something goes (に), where an action happens
/// (で). Which job a word has is mostly decided by the verb: a transitive
/// verb takes an object with を, a verb of motion a destination with に, a
/// verb of existence a location with に, any other action a location with
/// で. JMdict records transitivity, so practice gaps are built from the
/// verbs themselves — the learner's own verbs — with no sentences needed.
///
/// The noun in a built gap is a word that fits any verb of its kind: それ
/// (that) as an object, ここ / そこ (here / there) as a place, 友達 as a
/// person, 七時 as a time. Never a random noun, which makes grammatical
/// nonsense (学校を食べる). Jobs that aren't the verb's to decide (の, は,
/// も, から, まで, が with 好き) come with hand-written examples instead.
///
/// Pure Dart: tested without Flutter.
library;

import '../models.dart';

/// One job a particle does.
class ParticleRule {
  const ParticleRule({
    required this.id,
    required this.particle,
    required this.job,
    required this.example,
    required this.english,
    required this.note,
    this.alsoRight = const [],
  });

  final String id;
  final String particle;

  /// "the thing acted on".
  final String job;

  /// A short phrase showing it, the particle in 【】: 本【を】読む.
  final String example;
  final String english;

  /// Why: the rule in a sentence, shown on a wrong answer.
  final String note;

  /// Particles also correct in this job's gaps, never offered as wrong:
  /// a destination takes に or へ.
  final List<String> alsoRight;
}

const List<ParticleRule> kParticleRules = [
  ParticleRule(
    id: 'wo-object',
    particle: 'を',
    job: 'the thing acted on',
    example: '本【を】読む',
    english: 'read a book',
    note:
        'を marks the object of a transitive verb — what is eaten, read, '
        'bought, made.',
  ),
  ParticleRule(
    id: 'wo-through',
    particle: 'を',
    job: 'the place moved through or left',
    example: '公園【を】歩く · 家【を】出る',
    english: 'walk through the park · leave the house',
    note:
        'With verbs of moving along or leaving, を marks the route or the '
        'place left.',
  ),
  ParticleRule(
    id: 'ni-destination',
    particle: 'に',
    job: 'where something goes',
    example: '学校【に】行く',
    english: 'go to school',
    note:
        'に marks the destination of a verb of motion (行く, 来る, 帰る). '
        'へ works too.',
    alsoRight: ['へ'],
  ),
  ParticleRule(
    id: 'he-direction',
    particle: 'へ',
    job: 'the direction something heads',
    example: '東京【へ】行く',
    english: 'head for Tokyo',
    note: 'へ (read え) marks the direction of motion; に works too.',
    alsoRight: ['に'],
  ),
  ParticleRule(
    id: 'ni-existence',
    particle: 'に',
    job: 'where something is',
    example: '家【に】いる',
    english: 'be at home',
    note:
        'With いる, ある and 住む, the place is marked with に — where it '
        'exists, not where something happens.',
  ),
  ParticleRule(
    id: 'de-place',
    particle: 'で',
    job: 'where an action happens',
    example: '公園【で】遊ぶ',
    english: 'play in the park',
    note:
        'で marks where an action takes place. (Where something just is '
        'takes に.)',
  ),
  ParticleRule(
    id: 'de-means',
    particle: 'で',
    job: 'what it is done with or by',
    example: '箸【で】食べる · バス【で】行く',
    english: 'eat with chopsticks · go by bus',
    note:
        'で marks the tool, means or language: by bus, with a pen, in '
        'Japanese.',
  ),
  ParticleRule(
    id: 'ni-time',
    particle: 'に',
    job: 'when, at a clock or calendar time',
    example: '七時【に】起きる',
    english: 'get up at seven',
    note:
        'A specific time — a clock time, a day, a month — takes に. '
        'Relative times (今日, 明日, 毎日) take none.',
  ),
  ParticleRule(
    id: 'ni-target',
    particle: 'に',
    job: 'the person it is aimed at',
    example: '友達【に】会う · 先生【に】あげる',
    english: 'meet a friend · give to the teacher',
    note: 'に marks who an action is directed at: meet, give to, ask, tell.',
  ),
  ParticleRule(
    id: 'to-with',
    particle: 'と',
    job: 'who it is done with',
    example: '友達【と】話す',
    english: 'talk with a friend',
    note: 'と marks a partner in the action: with someone.',
  ),
  ParticleRule(
    id: 'ga-exists',
    particle: 'が',
    job: 'what exists or is there',
    example: '猫【が】いる',
    english: 'there is a cat',
    note: 'With いる and ある, what exists is marked with が.',
  ),
  ParticleRule(
    id: 'ga-likes',
    particle: 'が',
    job: 'what is liked, wanted, understood',
    example: '犬【が】好き · 日本語【が】わかる',
    english: 'like dogs · understand Japanese',
    note:
        '好き, 嫌い, 欲しい, わかる, できる take their object with が, '
        'not を.',
  ),
  ParticleRule(
    id: 'wa-topic',
    particle: 'は',
    job: 'the topic: as for…',
    example: '私【は】学生です',
    english: 'I am a student',
    note: 'は (read わ) sets the topic — what the rest is about.',
  ),
  ParticleRule(
    id: 'mo-also',
    particle: 'も',
    job: 'also, too',
    example: '私【も】行く',
    english: 'I am going too',
    note: 'も means "also" and replaces は, が or を.',
  ),
  ParticleRule(
    id: 'no-of',
    particle: 'の',
    job: "of, 's",
    example: '私【の】本',
    english: 'my book',
    note: 'の joins two nouns: the first owns or describes the second.',
  ),
  ParticleRule(
    id: 'kara-from',
    particle: 'から',
    job: 'from (a place or time)',
    example: '九時【から】働く',
    english: 'work from nine',
    note: 'から marks a starting point, in place or time.',
  ),
  ParticleRule(
    id: 'made-until',
    particle: 'まで',
    job: 'until, as far as',
    example: '五時【まで】働く',
    english: 'work until five',
    note: 'まで marks an end point, in place or time.',
  ),
];

ParticleRule particleRule(String id) =>
    kParticleRules.firstWhere((r) => r.id == id);

/// The particles a gap's choices are drawn from.
const kParticles = ['を', 'に', 'で', 'へ', 'と', 'が', 'は', 'も', 'の', 'から', 'まで'];

/// One gap to fill: [before]＿[after].
class ParticleGap {
  const ParticleGap({
    required this.ruleId,
    required this.before,
    required this.after,
    required this.english,
  });

  final String ruleId;
  final String before;
  final String after;
  final String english;

  ParticleRule get rule => particleRule(ruleId);

  /// Right answers: the rule's particle and any it allows.
  Set<String> get answers => {rule.particle, ...rule.alsoRight};

  @override
  String toString() => '$before＿$after';
}

/// Gaps that aren't a verb's to decide, written by hand: one or two per
/// rule, so every rule can be practised before any verbs are saved.
const List<ParticleGap> kFixedGaps = [
  ParticleGap(
    ruleId: 'wo-through',
    before: '公園',
    after: '歩く',
    english: 'walk through the park',
  ),
  ParticleGap(
    ruleId: 'wo-through',
    before: '家',
    after: '出る',
    english: 'leave the house',
  ),
  ParticleGap(
    ruleId: 'de-means',
    before: '箸',
    after: '食べる',
    english: 'eat with chopsticks',
  ),
  ParticleGap(
    ruleId: 'de-means',
    before: 'バス',
    after: '行く',
    english: 'go by bus',
  ),
  ParticleGap(
    ruleId: 'de-means',
    before: '日本語',
    after: '話す',
    english: 'speak in Japanese',
  ),
  ParticleGap(
    ruleId: 'he-direction',
    before: '東京',
    after: '向かう',
    english: 'head for Tokyo',
  ),
  ParticleGap(
    ruleId: 'ga-exists',
    before: '猫',
    after: 'いる',
    english: 'there is a cat',
  ),
  ParticleGap(
    ruleId: 'ga-exists',
    before: '時間',
    after: 'ある',
    english: 'there is time',
  ),
  ParticleGap(
    ruleId: 'ga-likes',
    before: '犬',
    after: '好き',
    english: 'like dogs',
  ),
  ParticleGap(
    ruleId: 'ga-likes',
    before: '日本語',
    after: 'わかる',
    english: 'understand Japanese',
  ),
  ParticleGap(
    ruleId: 'ga-likes',
    before: '水',
    after: '欲しい',
    english: 'want water',
  ),
  ParticleGap(
    ruleId: 'wa-topic',
    before: '私',
    after: '学生です',
    english: 'I am a student',
  ),
  ParticleGap(
    ruleId: 'wa-topic',
    before: '今日',
    after: '暑い',
    english: "today, it's hot",
  ),
  ParticleGap(
    ruleId: 'mo-also',
    before: '私',
    after: '行く',
    english: 'I am going too',
  ),
  ParticleGap(
    ruleId: 'mo-also',
    before: '猫',
    after: '好き',
    english: 'I like cats too',
  ),
  ParticleGap(ruleId: 'no-of', before: '私', after: '本', english: 'my book'),
  ParticleGap(
    ruleId: 'no-of',
    before: '日本',
    after: '車',
    english: 'a Japanese car',
  ),
  ParticleGap(
    ruleId: 'kara-from',
    before: '九時',
    after: '働く',
    english: 'work from nine',
  ),
  ParticleGap(
    ruleId: 'kara-from',
    before: '駅',
    after: '歩く',
    english: 'walk from the station',
  ),
  ParticleGap(
    ruleId: 'made-until',
    before: '五時',
    after: '働く',
    english: 'work until five',
  ),
  ParticleGap(
    ruleId: 'made-until',
    before: '駅',
    after: '歩く',
    english: 'walk as far as the station',
  ),
  ParticleGap(
    ruleId: 'ni-target',
    before: '友達',
    after: '会う',
    english: 'meet a friend',
  ),
  ParticleGap(
    ruleId: 'ni-target',
    before: '先生',
    after: '聞く',
    english: 'ask the teacher',
  ),
  ParticleGap(
    ruleId: 'to-with',
    before: '友達',
    after: '話す',
    english: 'talk with a friend',
  ),
  ParticleGap(
    ruleId: 'to-with',
    before: '母',
    after: '買い物する',
    english: 'go shopping with my mother',
  ),
];

/// Verbs whose particle is fixed by meaning, not by transitivity.
const _motion = {
  '行く',
  '来る',
  '帰る',
  '戻る',
  '入る',
  '着く',
  '出かける',
  '上がる',
  '乗る',
  '向かう',
  '急ぐ',
  '移る',
  '通う',
  '引っ越す',
};
const _existence = {'いる', 'ある', '住む', '泊まる', '残る', '居る', '有る'};

/// Verbs that are poor fits for a place-of-action gap (ここで…): states
/// and happenings, not things someone does somewhere.
const _noPlace = {
  'わかる',
  '分かる',
  'できる',
  '出来る',
  '要る',
  '似る',
  '違う',
  '困る',
  '死ぬ',
  '降る',
  '咲く',
  '始まる',
  '終わる',
  '晴れる',
  '曇る',
};

/// What gaps [entry] — a verb — makes, by its kind.
List<ParticleGap> gapsForVerb(Entry entry) {
  final word = entry.word;
  final pos = [for (final s in entry.senses.take(2)) ...s.partsOfSpeech];
  final isVerb = pos.any(
    (p) =>
        p.contains('verb') && !p.contains('adverb') && !p.contains('auxiliary'),
  );
  if (!isVerb) return const [];
  final english = entry.shortMeaning.replaceFirst(RegExp(r'^to '), '');
  String head(String s) => s.split(';').first.trim();
  final gloss = head(english);
  final out = <ParticleGap>[];
  if (_motion.contains(word)) {
    out.add(
      ParticleGap(
        ruleId: 'ni-destination',
        before: 'そこ',
        after: word,
        english: '$gloss (to) there',
      ),
    );
  } else if (_existence.contains(word)) {
    out.add(
      ParticleGap(
        ruleId: 'ni-existence',
        before: 'ここ',
        after: word,
        english: '$gloss here',
      ),
    );
  } else {
    final transitive = pos.contains('transitive verb');
    if (transitive) {
      out.add(
        ParticleGap(
          ruleId: 'wo-object',
          before: 'それ',
          after: word,
          english: '$gloss that',
        ),
      );
    }
    if (!_noPlace.contains(word)) {
      out.add(
        ParticleGap(
          ruleId: 'de-place',
          before: 'ここ',
          after: word,
          english: '$gloss here',
        ),
      );
    }
  }
  if (!_noPlace.contains(word) || word == '始まる' || word == '終わる') {
    out.add(
      ParticleGap(
        ruleId: 'ni-time',
        before: '七時',
        after: word,
        english: '$gloss at seven',
      ),
    );
  }
  return out;
}

/// The core verbs every drill can draw on, so it works before any are
/// saved — written with their kind, so no dictionary is needed.
List<Entry> get kCoreVerbs => [
  for (final (w, r, m, t) in const [
    ('食べる', 'たべる', 'to eat', true),
    ('飲む', 'のむ', 'to drink', true),
    ('読む', 'よむ', 'to read', true),
    ('書く', 'かく', 'to write', true),
    ('買う', 'かう', 'to buy', true),
    ('見る', 'みる', 'to see; to watch', true),
    ('作る', 'つくる', 'to make', true),
    ('遊ぶ', 'あそぶ', 'to play', false),
    ('働く', 'はたらく', 'to work', false),
    ('寝る', 'ねる', 'to sleep', false),
    ('行く', 'いく', 'to go', false),
    ('来る', 'くる', 'to come', false),
    ('帰る', 'かえる', 'to go home', false),
    ('いる', 'いる', 'to be (people, animals)', false),
    ('ある', 'ある', 'to be (things)', false),
    ('住む', 'すむ', 'to live (somewhere)', false),
  ])
    Entry(
      word: w,
      reading: r,
      senses: [
        Sense(
          glosses: [m],
          partsOfSpeech: [t ? 'transitive verb' : 'intransitive verb'],
        ),
      ],
    ),
];

/// Choices for [gap]: its answer and three that are wrong for it — never
/// another particle that would also be right.
List<String> choicesFor(ParticleGap gap, int seed) {
  final answer = gap.rule.particle;
  // Wrong answers that teach: the particles most confused with this one
  // first, then any.
  const near = {
    'を': ['が', 'に', 'で'],
    'に': ['で', 'を', 'が'],
    'で': ['に', 'を', 'と'],
    'へ': ['で', 'を', 'から'],
    'と': ['に', 'で', 'の'],
    'が': ['を', 'は', 'に'],
    'は': ['が', 'も', 'を'],
    'も': ['は', 'が', 'と'],
    'の': ['が', 'と', 'に'],
    'から': ['まで', 'に', 'で'],
    'まで': ['から', 'に', 'で'],
  };
  // は and も can stand in for almost any particle (犬は好き, それも食べる
  // are fine Japanese), so they're never offered as wrong — only asked
  // for when they're the answer. And は, が, も are never set against each
  // other: 私が学生です is right too, just with a different focus.
  final fine = {'は', 'も', if (answer == 'は' || answer == 'も') 'が'};
  final wrong = <String>{
    for (final p in [...near[answer]!, ...kParticles])
      if (!gap.answers.contains(p) && !fine.contains(p)) p,
  }.take(3).toList();
  final choices = [answer, ...wrong];
  // Shuffled by the seed, so a gap's order is stable while it's shown.
  final order = [0, 1, 2, 3]
    ..sort((a, b) => ((a * 7 + seed) % 11).compareTo((b * 7 + seed) % 11));
  return [for (final i in order) choices[i]];
}
