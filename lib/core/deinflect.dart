/// Undoing conjugation, so a word met on the page can be found in the
/// dictionary.
///
/// jisho.org deinflects only some forms and is thrown by a trailing
/// particle: あそべるよ ("you can play!") finds 世, あそべる finds a picture
/// book, and 遊べる finds nothing at all. Speech bubbles are almost entirely
/// conjugated verbs with particles on the end, so this works it back the
/// way Yomichan does: strip a sentence-final particle, then peel endings
/// off — あそべる → あそぶ (potential) — and offer each candidate dictionary
/// form with the chain of forms that led there.
///
/// It over-generates on purpose (つ, う and る all make って). The caller
/// checks each candidate against the dictionary and keeps the first that
/// is a real word, so a wrong guess costs a lookup, never a wrong answer.
///
/// Pure Dart, no plugins: tested with `flutter test` alone.
library;

/// One way [term] could be the dictionary form behind what was seen.
class Deinflection {
  const Deinflection(this.term, this.reasons);

  /// The candidate dictionary form.
  final String term;

  /// What was undone, outermost first: ['potential'], or
  /// ['polite', 'past'] for 食べました.
  final List<String> reasons;

  /// [surface] without the sentence-final particle this stripped, if any:
  /// the word as it stands on the page (あそべるよ → あそべる).
  String wordOnPage(String surface) {
    final first = reasons.isEmpty ? '' : reasons.first;
    if (!first.startsWith('+ ')) return surface;
    final particle = first.substring(2);
    return surface.endsWith(particle)
        ? surface.substring(0, surface.length - particle.length)
        : surface;
  }

  /// "potential", "te-form · progressive" — for showing under the word.
  /// A stripped particle is mentioned only when it's all there was.
  String get label {
    final forms = reasons.where((r) => !r.startsWith('+ ')).toList();
    if (forms.isEmpty) return 'with ${reasons.first.substring(2)}';
    return forms.reversed.join(' · ');
  }

  @override
  String toString() => '$term ($label)';

  @override
  bool operator ==(Object other) =>
      other is Deinflection &&
      other.term == term &&
      other.reasons.join('|') == reasons.join('|');

  @override
  int get hashCode => Object.hash(term, reasons.join('|'));
}

/// What a form is, as far as the rules care: a finished dictionary form
/// (verb ending in u, adjective in い), or a te-form left behind by an
/// auxiliary (遊んでる → 遊んで) that only te-form rules continue from.
enum _Kind { dictionary, teForm }

class _Rule {
  const _Rule(this.from, this.to, this.reason, this.yields, {this.te = false});

  final String from;
  final String to;
  final String reason;

  /// What the result is.
  final _Kind yields;

  /// A te-form rule: the only kind that applies to a te-form an auxiliary
  /// left behind. (It applies to anything else too — 遊んで on the page.)
  final bool te;
}

/// Godan rows: dictionary ending, then its i / a / e / o forms and its
/// te / ta forms.
const _godan = [
  ('う', 'い', 'わ', 'え', 'お', 'って', 'った'),
  ('く', 'き', 'か', 'け', 'こ', 'いて', 'いた'),
  ('ぐ', 'ぎ', 'が', 'げ', 'ご', 'いで', 'いだ'),
  ('す', 'し', 'さ', 'せ', 'そ', 'して', 'した'),
  ('つ', 'ち', 'た', 'て', 'と', 'って', 'った'),
  ('ぬ', 'に', 'な', 'ね', 'の', 'んで', 'んだ'),
  ('ぶ', 'び', 'ば', 'べ', 'ぼ', 'んで', 'んだ'),
  ('む', 'み', 'ま', 'め', 'も', 'んで', 'んだ'),
  ('る', 'り', 'ら', 'れ', 'ろ', 'って', 'った'),
];

/// Endings that attach to a masu-stem (食べ, 書き) and what they mean.
const _onStem = [
  ('ます', 'polite'),
  ('ました', 'polite past'),
  ('ません', 'polite negative'),
  ('ませんでした', 'polite past negative'),
  ('ましょう', 'polite volitional'),
  ('たい', 'want to'),
  ('たかった', 'wanted to'),
  ('たくない', "don't want to"),
  ('なさい', 'command'),
  ('ながら', 'while'),
];

/// Endings on the negative (a-row) base.
const _onNegative = [
  ('ない', 'negative'),
  ('なかった', 'past negative'),
  ('なくて', 'negative te-form'),
  ('なければ', 'negative conditional'),
  ('ず', 'negative (literary)'),
  ('れる', 'passive'),
  ('せる', 'causative'),
  ('せられる', 'causative passive'),
];

List<_Rule> _buildRules() {
  final rules = <_Rule>[];
  void add(
    String from,
    String to,
    String reason,
    _Kind yields, {
    bool te = false,
  }) => rules.add(_Rule(from, to, reason, yields, te: te));

  // Ichidan, する and くる first: where a godan rule reads the same ending
  // (食べ|られる as ら + れる), the ichidan reading is the better label.
  // Ichidan verbs (食べる): everything hangs off the stem.
  for (final (end, why) in _onStem) {
    add(end, 'る', why, _Kind.dictionary);
  }
  for (final (end, why) in [
    ('ない', 'negative'),
    ('なかった', 'past negative'),
    ('なくて', 'negative te-form'),
    ('なければ', 'negative conditional'),
    ('られる', 'potential / passive'),
    ('れる', 'potential (colloquial)'),
    ('させる', 'causative'),
    ('させられる', 'causative passive'),
    ('よう', 'volitional'),
    ('れば', 'conditional'),
    ('ろ', 'command'),
    ('た', 'past'),
    ('たら', 'conditional (tara)'),
    ('たり', 'tari'),
  ]) {
    add(end, 'る', why, _Kind.dictionary);
  }
  add('て', 'る', 'te-form', _Kind.dictionary, te: true);

  // する and くる.
  for (final (from, why) in [
    ('します', 'polite'),
    ('しました', 'polite past'),
    ('しません', 'polite negative'),
    ('しない', 'negative'),
    ('しなかった', 'past negative'),
    ('した', 'past'),
    ('したい', 'want to'),
    ('しよう', 'volitional'),
    ('しろ', 'command'),
    ('させる', 'causative'),
    ('される', 'passive'),
    ('できる', 'potential'),
    ('すれば', 'conditional'),
    ('したら', 'conditional (tara)'),
  ]) {
    add(from, 'する', why, _Kind.dictionary);
  }
  add('して', 'する', 'te-form', _Kind.dictionary, te: true);
  for (final (from, why) in [
    ('きます', 'polite'),
    ('きました', 'polite past'),
    ('こない', 'negative'),
    ('こなかった', 'past negative'),
    ('きた', 'past'),
    ('こられる', 'potential / passive'),
    ('こよう', 'volitional'),
    ('こい', 'command'),
  ]) {
    add(from, 'くる', why, _Kind.dictionary);
  }
  add('きて', 'くる', 'te-form', _Kind.dictionary, te: true);

  // Godan verbs.
  for (final (u, i, a, e, o, te, ta) in _godan) {
    for (final (end, why) in _onStem) {
      add('$i$end', u, why, _Kind.dictionary);
    }
    for (final (end, why) in _onNegative) {
      // う-verbs take わ for the negative: 買わない.
      add('$a$end', u, why, _Kind.dictionary);
    }
    add('$eる', u, 'potential', _Kind.dictionary);
    add('$eば', u, 'conditional', _Kind.dictionary);
    add(e, u, 'command', _Kind.dictionary);
    add('$oう', u, 'volitional', _Kind.dictionary);
    add(te, u, 'te-form', _Kind.dictionary, te: true);
    add(ta, u, 'past', _Kind.dictionary);
    add('$taら', u, 'conditional (tara)', _Kind.dictionary);
    add('$taり', u, 'tari', _Kind.dictionary);
  }
  // 行く is the one irregular godan te-form.
  add('って', 'く', 'te-form', _Kind.dictionary, te: true);
  add('った', 'く', 'past', _Kind.dictionary);

  // い-adjectives.
  for (final (from, why) in [
    ('く', 'adverb'),
    ('かった', 'past'),
    ('くない', 'negative'),
    ('くなかった', 'past negative'),
    ('くて', 'te-form'),
    ('ければ', 'conditional'),
    ('かったら', 'conditional (tara)'),
    ('さ', 'noun (-sa)'),
    ('そう', 'looks'),
    ('すぎる', 'too'),
  ]) {
    add(from, 'い', why, _Kind.dictionary);
  }

  // Auxiliaries that leave a te-form or a masu-stem for the rules above.
  for (final (from, to, why) in [
    ('ている', 'て', 'progressive'),
    ('てる', 'て', 'progressive'),
    ('ていた', 'て', 'was …ing'),
    ('てた', 'て', 'was …ing'),
    ('ています', 'て', 'progressive (polite)'),
    ('てください', 'て', 'please'),
    ('てくれ', 'て', 'do for me'),
    ('てしまう', 'て', 'completely / regrettably'),
    ('てしまった', 'て', 'completely / regrettably'),
    ('ちゃう', 'て', 'completely / regrettably'),
    ('ちゃった', 'て', 'completely / regrettably'),
    ('ておく', 'て', 'in advance'),
    ('とく', 'て', 'in advance'),
    ('てみる', 'て', 'try'),
    ('てあげる', 'て', 'for someone'),
    ('てもらう', 'て', 'have done'),
    ('でいる', 'で', 'progressive'),
    ('でる', 'で', 'progressive'),
    ('でいた', 'で', 'was …ing'),
    ('じゃう', 'で', 'completely / regrettably'),
    ('じゃった', 'で', 'completely / regrettably'),
  ]) {
    rules.add(_Rule(from, to, why, _Kind.teForm));
  }
  return rules;
}

final List<_Rule> _rules = _buildRules();

/// Sentence-final particles stripped before anything else. Longest first.
const _finalParticles = [
  'よね',
  'のよ',
  'わよ',
  'だよ',
  'かな',
  'かしら',
  'よ',
  'ね',
  'な',
  'わ',
  'ぞ',
  'ぜ',
  'さ',
  'か',
  'の',
];

const int _maxDepth = 4;

/// Candidate dictionary forms for [surface], most likely first: fewer
/// steps before more, and a longer matched ending before a shorter one.
/// [surface] itself is not included.
List<Deinflection> deinflect(String surface) {
  final start = surface.trim();
  if (start.isEmpty) return const [];

  final seen = <String>{start};
  final out = <Deinflection>[];
  // (text, reasons, kind of form it is, longest ending matched so far)
  var frontier = <(String, List<String>, _Kind?, int)>[
    (start, const [], null, 0),
  ];

  // A trailing particle comes off first, as its own step.
  for (final p in _finalParticles) {
    if (start.length > p.length + 1 && start.endsWith(p)) {
      final bare = start.substring(0, start.length - p.length);
      if (seen.add(bare)) {
        out.add(Deinflection(bare, ['+ $p']));
        frontier.add((bare, ['+ $p'], null, 0));
      }
    }
  }

  for (var depth = 0; depth < _maxDepth && frontier.isNotEmpty; depth++) {
    final next = <(String, List<String>, _Kind?, int)>[];
    final level = <(Deinflection, int)>[];
    for (final (text, reasons, kind, _) in frontier) {
      for (final r in _rules) {
        if (kind == _Kind.teForm && !r.te) continue;
        if (!text.endsWith(r.from)) continue;
        final stem = text.substring(0, text.length - r.from.length);
        final term = '$stem${r.to}';
        // A one-character "dictionary form" is never the word (する and
        // くる are whole words; よ is not a verb).
        if (term.runes.length < 2) continue;
        final why = [...reasons, r.reason];
        if (r.yields == _Kind.dictionary) {
          if (seen.add(term)) {
            level.add((Deinflection(term, why), r.from.length));
          }
        }
        next.add((
          term,
          why,
          r.yields == _Kind.dictionary ? null : r.yields,
          r.from.length,
        ));
      }
    }
    // Within one depth, the longer ending is the better reading of it.
    level.sort((a, b) => b.$2.compareTo(a.$2));
    out.addAll(level.map((e) => e.$1));
    frontier = next;
  }
  return out;
}
