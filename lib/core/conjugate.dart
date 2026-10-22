/// Conjugating a verb into every form worth knowing, as a tree.
///
/// The forward twin of deinflect.dart: that takes 食べられなかった back to
/// 食べる; this builds 食べる → potential 食べられる → negative 食べられない
/// → past 食べられなかった, so the map can show each step and the rule
/// that made it. Japanese builds forms that way — each one hangs off
/// another — so a tree is the honest shape for it, not a table.
///
/// Every form carries its written spelling and its reading. Conjugation
/// only ever touches the kana on the end (食べ|る, 書|く), except 来る,
/// whose 来 is read き, こ or く depending on the form.
///
/// Plain forms are the casual ones; polite forms (ます) and spoken
/// contractions (てる, ちゃう, なきゃ…) are marked, since manga is mostly
/// the last.
///
/// Pure Dart: tested without Flutter.
library;

import '../models.dart';

enum VerbGroup { godan, ichidan, suru, kuru }

/// How a form sounds: plain (casual, but standard), polite (です/ます),
/// or a spoken contraction (食べてる for 食べている).
enum Register { plain, polite, contraction }

/// A dictionary verb, ready to conjugate.
class Verb {
  const Verb(this.written, this.reading, this.group, {this.special = ''});

  final String written;
  final String reading;
  final VerbGroup group;

  /// JMdict's special classes that bend a rule: 'iku' (行って), 'aru'
  /// (ない, not あらない), 'aru-honorific' (いらっしゃいます), 'kureru'
  /// (くれ), 'tou' (問うて).
  final String special;

  /// [e] as a verb, if it is one this can conjugate. A noun that takes
  /// する (勉強) becomes the する verb (勉強する).
  static Verb? fromEntry(Entry e) {
    final pos = [for (final s in e.senses) ...s.partsOfSpeech];
    bool has(String p) => pos.any((x) => x == p);
    final reading = e.reading.isEmpty ? e.word : e.reading;
    // Conjugation changes the kana on the end, so the spelling has to end
    // in the same kana as the reading; a rare all-kanji spelling (為る) is
    // conjugated in kana instead.
    final shared = reading.endsWith('くる') && e.word.endsWith('来る')
        ? true
        : reading.isNotEmpty &&
              e.word.endsWith(reading.substring(reading.length - 1)) &&
              (!reading.endsWith('する') || e.word.endsWith('する'));
    final word = shared ? e.word : reading;
    if (has('Kuru verb - special class')) {
      return Verb(word, reading, VerbGroup.kuru);
    }
    if (has('suru verb - included')) {
      return Verb(word, reading, VerbGroup.suru);
    }
    if (has('Ichidan verb') || has('Ichidan verb - kureru special class')) {
      if (!reading.endsWith('る')) return null;
      return Verb(
        word,
        reading,
        VerbGroup.ichidan,
        special: has('Ichidan verb - kureru special class') ? 'kureru' : '',
      );
    }
    for (final p in pos) {
      if (!p.startsWith('Godan verb')) continue;
      final last = reading.isEmpty ? '' : reading[reading.length - 1];
      if (!_godanRows.containsKey(last)) return null;
      final special = switch (p) {
        'Godan verb - Iku/Yuku special class' => 'iku',
        "Godan verb with 'ru' ending (irregular verb)" => 'aru',
        'Godan verb - -aru special class' => 'aru-honorific',
        "Godan verb with 'u' ending (special class)" => 'tou',
        _ => '',
      };
      return Verb(word, reading, VerbGroup.godan, special: special);
    }
    if (has('noun or participle which takes the aux. verb suru')) {
      return Verb('${e.word}する', '$readingする', VerbGroup.suru);
    }
    return null;
  }

  String get groupName => switch (group) {
    VerbGroup.godan => 'godan (u-verb)',
    VerbGroup.ichidan => 'ichidan (ru-verb)',
    VerbGroup.suru => 'する (irregular)',
    VerbGroup.kuru => 'くる (irregular)',
  };
}

/// Godan rows: dictionary ending → i, a, e, o, te, ta.
const Map<String, (String, String, String, String, String, String)> _godanRows =
    {
      'う': ('い', 'わ', 'え', 'お', 'って', 'った'),
      'く': ('き', 'か', 'け', 'こ', 'いて', 'いた'),
      'ぐ': ('ぎ', 'が', 'げ', 'ご', 'いで', 'いだ'),
      'す': ('し', 'さ', 'せ', 'そ', 'して', 'した'),
      'つ': ('ち', 'た', 'て', 'と', 'って', 'った'),
      'ぬ': ('に', 'な', 'ね', 'の', 'んで', 'んだ'),
      'ぶ': ('び', 'ば', 'べ', 'ぼ', 'んで', 'んだ'),
      'む': ('み', 'ま', 'め', 'も', 'んで', 'んだ'),
      'る': ('り', 'ら', 'れ', 'ろ', 'って', 'った'),
    };

/// A spelling and its reading, side by side.
class Kana {
  const Kana(this.written, this.reading);

  final String written;
  final String reading;

  Kana operator +(String suffix) => Kana('$written$suffix', '$reading$suffix');

  /// Both without their last [n] characters.
  Kana drop(int n) => Kana(
    written.substring(0, written.length - n),
    reading.substring(0, reading.length - n),
  );

  bool endsWith(String s) => reading.endsWith(s);

  @override
  bool operator ==(Object other) =>
      other is Kana && other.written == written && other.reading == reading;

  @override
  int get hashCode => Object.hash(written, reading);

  @override
  String toString() => written == reading ? written : '$written［$reading］';
}

/// One form on the map.
class VerbForm {
  VerbForm({
    required this.id,
    required this.label,
    required this.meaning,
    required this.text,
    this.register = Register.plain,
    this.children = const [],
  });

  /// Path-unique: 'potential/negative/past'.
  final String id;

  /// What the form is called: "negative", "te-form".
  final String label;

  /// What it does to the verb: "not do", "did".
  final String meaning;
  final Kana text;
  final Register register;
  final List<VerbForm> children;

  VerbForm? parent;

  /// The change from the form it hangs off: "る → ない". Empty for the
  /// dictionary form.
  String get rule {
    final p = parent;
    if (p == null) return '';
    return changeRule(p.text.reading, text.reading);
  }

  /// This form and everything below it, depth first.
  Iterable<VerbForm> get all sync* {
    yield this;
    for (final c in children) {
      yield* c.all;
    }
  }

  /// From the dictionary form down to this one.
  List<VerbForm> get path {
    final out = <VerbForm>[];
    VerbForm? f = this;
    while (f != null) {
      out.insert(0, f);
      f = f.parent;
    }
    return out;
  }

  /// The form spelled [s] (written or read), nearest the top first, and
  /// among equals the one earlier on the map — 食べられる is potential
  /// before passive.
  VerbForm? find(String s) {
    var level = [this];
    while (level.isNotEmpty) {
      for (final f in level) {
        if (f.text.written == s || f.text.reading == s) return f;
      }
      level = [for (final f in level) ...f.children];
    }
    return null;
  }

  @override
  String toString() => '$id: ${text.written}';
}

/// What changed from [from] to [to], as a swap of endings: たべる →
/// たべない is "る → ない"; たべている → たべてる is "てい → て"… read the
/// longest shared start off both.
String changeRule(String from, String to) {
  var i = 0;
  while (i < from.length && i < to.length && from[i] == to[i]) {
    i++;
  }
  // A swap needs something to swap: keep one character of the stem when
  // nothing would be left of the old ending (たべ → たべない reads better
  // as "べ → べない" than "→ ない").
  if (i == from.length && i > 0) i--;
  final a = from.substring(i);
  final b = to.substring(i);
  return '$a → $b';
}

class _Builder {
  _Builder(this.v);

  final Verb v;

  Kana get dict => Kana(v.written, v.reading);

  /// The verb without its conjugating ending, for kuru as 来 / ''.
  Kana _kuruStem() {
    final w = v.written;
    final r = v.reading;
    // 来る / くる, alone or on the end of a compound (持って来る).
    final written = w.endsWith('来る')
        ? w.substring(0, w.length - 1)
        : w.substring(0, w.length - 2);
    return Kana(written, r.substring(0, r.length - 2));
  }

  /// 来 read as [kana]: き, こ or く. A kana-only くる just takes the kana.
  Kana _kuru(String kana) {
    final s = _kuruStem();
    final kanji = s.written.endsWith('来');
    return Kana(kanji ? s.written : '${s.written}$kana', '${s.reading}$kana');
  }

  /// The stem a set of endings attaches to.
  Kana base(String which) {
    switch (v.group) {
      case VerbGroup.ichidan:
        return dict.drop(1) +
            switch (which) {
              'te' => 'て',
              'ta' => 'た',
              'e' => 'れ',
              _ => '',
            };
      case VerbGroup.suru:
        final s = dict.drop(2);
        return s +
            switch (which) {
              'i' || 'a' => 'し',
              'a-sa' => 'さ',
              'e' => 'すれ',
              'o' => 'しよ',
              'te' => 'して',
              'ta' => 'した',
              _ => 'する',
            };
      case VerbGroup.kuru:
        return switch (which) {
          'i' => _kuru('き'),
          'a' || 'a-sa' => _kuru('こ'),
          'o' => _kuru('こ') + 'よ',
          'e' => _kuru('く') + 'れ',
          'te' => _kuru('き') + 'て',
          'ta' => _kuru('き') + 'た',
          _ => dict,
        };
      case VerbGroup.godan:
        final end = v.reading[v.reading.length - 1];
        final (i, a, e, o, te, ta) = _godanRows[end]!;
        final stem = dict.drop(1);
        return switch (which) {
          'i' => stem + (v.special == 'aru-honorific' ? 'い' : i),
          'a' || 'a-sa' => stem + a,
          'e' => stem + e,
          'o' => stem + o,
          'te' =>
            stem +
                (v.special == 'iku'
                    ? 'って'
                    : v.special == 'tou'
                    ? 'うて'
                    : te),
          'ta' =>
            stem +
                (v.special == 'iku'
                    ? 'った'
                    : v.special == 'tou'
                    ? 'うた'
                    : ta),
          _ => dict,
        };
    }
  }

  Kana get negative => v.special == 'aru'
      ? Kana(v.written == '有る' ? '無い' : 'ない', 'ない')
      : base('a') + 'ない';

  Kana get potential => switch (v.group) {
    VerbGroup.godan => base('e') + 'る',
    VerbGroup.ichidan => base('') + 'られる',
    VerbGroup.suru =>
      v.reading == 'する' ? const Kana('できる', 'できる') : dict.drop(2) + 'できる',
    VerbGroup.kuru => _kuru('こ') + 'られる',
  };

  Kana get passive => switch (v.group) {
    VerbGroup.godan => base('a') + 'れる',
    VerbGroup.ichidan => base('') + 'られる',
    VerbGroup.suru => base('a-sa') + 'れる',
    VerbGroup.kuru => _kuru('こ') + 'られる',
  };

  Kana get causative => switch (v.group) {
    VerbGroup.godan => base('a') + 'せる',
    VerbGroup.ichidan => base('') + 'させる',
    VerbGroup.suru => base('a-sa') + 'せる',
    VerbGroup.kuru => _kuru('こ') + 'させる',
  };

  Kana get volitional => switch (v.group) {
    VerbGroup.godan => base('o') + 'う',
    VerbGroup.ichidan => base('') + 'よう',
    VerbGroup.suru || VerbGroup.kuru => base('o') + 'う',
  };

  Kana get conditional => base('e') + 'ば';

  Kana get imperative => switch (v.group) {
    VerbGroup.godan => v.special == 'aru-honorific' ? base('i') : base('e'),
    VerbGroup.ichidan => v.special == 'kureru' ? base('') : base('') + 'ろ',
    VerbGroup.suru => dict.drop(2) + 'しろ',
    VerbGroup.kuru => _kuru('こ') + 'い',
  };

  Kana get te => base('te');
  Kana get ta => base('ta');

  /// て or で — 読んで takes で, and so do its contractions (じゃう).
  bool get _de => te.reading.endsWith('で');

  /// [k] with its final て/で swapped for [t] / [d].
  Kana _swapTe(Kana k, String t, String d) => k.drop(1) + (_de ? d : t);

  // --- Builders for derived words, which conjugate in turn. ---

  /// An ichidan verb made by a form (食べられる, 食べさせる, 食べている):
  /// its own short branch.
  List<VerbForm> _ichidanBranch(String id, Kana k, {bool polite = true}) {
    final stem = k.drop(1);
    return [
      _f(
        '$id/negative',
        'negative',
        'not',
        stem + 'ない',
        children: [_f('$id/negative/past', 'past', 'did not', stem + 'なかった')],
      ),
      _f('$id/past', 'past', 'did', stem + 'た'),
      if (polite)
        _f(
          '$id/polite',
          'polite',
          'polite',
          stem + 'ます',
          register: Register.polite,
        ),
      _f('$id/te', 'te-form', 'and…', stem + 'て'),
    ];
  }

  /// An い-adjective-shaped ending (ない, たい): past, te, if.
  List<VerbForm> _adjectiveBranch(String id, Kana k, {bool casual = false}) {
    final stem = k.drop(1);
    return [
      _f('$id/past', 'past', 'did not', stem + 'かった'),
      _f('$id/te', 'te-form', 'not, and…', stem + 'くて'),
      _f(
        '$id/if',
        'conditional',
        'if not',
        stem + 'ければ',
        children: [
          if (casual)
            _f(
              '$id/if/must',
              'have to',
              'have to',
              stem + 'きゃ',
              register: Register.contraction,
            ),
        ],
      ),
    ];
  }

  VerbForm _f(
    String id,
    String label,
    String meaning,
    Kana text, {
    Register register = Register.plain,
    List<VerbForm> children = const [],
  }) => VerbForm(
    id: id,
    label: label,
    meaning: meaning,
    text: text,
    register: register,
    children: children,
  );

  VerbForm build() {
    final stem = base('i');
    final neg = negative;
    final teK = te;
    final teForms = <VerbForm>[
      _f(
        'te/progressive',
        'progressive',
        'is doing',
        teK + 'いる',
        children: [
          ..._ichidanBranch('te/progressive', teK + 'いる'),
          _f(
            'te/progressive/casual',
            'casual',
            'is doing',
            teK + 'る',
            register: Register.contraction,
            children: [
              _f(
                'te/progressive/casual/past',
                'past',
                'was doing',
                teK + 'た',
                register: Register.contraction,
              ),
              _f(
                'te/progressive/casual/negative',
                'negative',
                "isn't doing",
                teK + 'ない',
                register: Register.contraction,
              ),
            ],
          ),
        ],
      ),
      _f(
        'te/shimau',
        'completely',
        'end up doing / do it all',
        teK + 'しまう',
        children: [
          _f('te/shimau/past', 'past', 'ended up doing', teK + 'しまった'),
          _f(
            'te/shimau/casual',
            'casual',
            'end up doing',
            _swapTe(teK, 'ちゃう', 'じゃう'),
            register: Register.contraction,
            children: [
              _f(
                'te/shimau/casual/past',
                'past',
                'ended up doing',
                _swapTe(teK, 'ちゃった', 'じゃった'),
                register: Register.contraction,
              ),
            ],
          ),
        ],
      ),
      _f(
        'te/oku',
        'in advance',
        'do ahead of time',
        teK + 'おく',
        children: [
          _f(
            'te/oku/casual',
            'casual',
            'do ahead of time',
            _swapTe(teK, 'とく', 'どく'),
            register: Register.contraction,
          ),
        ],
      ),
      _f('te/miru', 'try', 'try doing', teK + 'みる'),
      _f(
        'te/kudasai',
        'please',
        'please do',
        teK + 'ください',
        register: Register.polite,
      ),
      _f('te/ii', 'may', 'it’s fine to do', teK + 'もいい'),
      _f(
        'te/dame',
        'must not',
        'must not do',
        teK + 'はいけない',
        children: [
          _f(
            'te/dame/casual',
            'casual',
            'mustn’t do',
            _swapTe(teK, 'ちゃだめ', 'じゃだめ'),
            register: Register.contraction,
          ),
        ],
      ),
    ];

    final potentialK = potential;
    final root = _f(
      '',
      'dictionary form',
      'plain, present',
      dict,
      children: [
        _f(
          'polite',
          'polite',
          'polite',
          stem + 'ます',
          register: Register.polite,
          children: [
            _f(
              'polite/past',
              'past',
              'did',
              stem + 'ました',
              register: Register.polite,
            ),
            _f(
              'polite/negative',
              'negative',
              'not',
              stem + 'ません',
              register: Register.polite,
              children: [
                _f(
                  'polite/negative/past',
                  'past',
                  'did not',
                  stem + 'ませんでした',
                  register: Register.polite,
                ),
              ],
            ),
            _f(
              'polite/volitional',
              "let's",
              "let's do",
              stem + 'ましょう',
              register: Register.polite,
            ),
            _f(
              'polite/want',
              'want',
              'want to do',
              stem + 'たい',
              children: [
                _f(
                  'polite/want/negative',
                  'negative',
                  "don't want to",
                  stem + 'たくない',
                ),
                _f('polite/want/past', 'past', 'wanted to', stem + 'たかった'),
              ],
            ),
            _f('polite/while', 'while', 'while doing', stem + 'ながら'),
            _f('polite/command', 'command', 'do it (firm, kind)', stem + 'なさい'),
          ],
        ),
        _f(
          'negative',
          'negative',
          'not',
          neg,
          children: [
            ..._adjectiveBranch('negative', neg, casual: true),
            _f(
              'negative/must',
              'have to',
              'have to do',
              neg.drop(1) + 'くちゃ',
              register: Register.contraction,
            ),
            if (v.special != 'aru')
              _f(
                'negative/n',
                'blunt',
                "won't / don't",
                v.group == VerbGroup.suru
                    ? dict.drop(2) + 'せん'
                    : neg.drop(2) + 'ん',
                register: Register.contraction,
              ),
          ],
        ),
        _f(
          'past',
          'past',
          'did',
          ta,
          children: [
            _f('past/if', 'if / when', 'if / when (it happens)', ta + 'ら'),
            _f('past/tari', 'things like', 'do things like', ta + 'り'),
          ],
        ),
        _f('te', 'te-form', 'and… / joins', teK, children: teForms),
        _f(
          'potential',
          'potential',
          'can do',
          potentialK,
          children: [
            ..._ichidanBranch('potential', potentialK),
            // 見られる → 見れる: the ら dropped in speech.
            if (v.group == VerbGroup.ichidan || v.group == VerbGroup.kuru)
              _f(
                'potential/casual',
                'casual',
                'can do',
                potentialK.drop(3) + 'れる',
                register: Register.contraction,
              ),
          ],
        ),
        _f(
          'passive',
          'passive',
          'is done (to)',
          passive,
          children: _ichidanBranch('passive', passive),
        ),
        _f(
          'causative',
          'causative',
          'make / let do',
          causative,
          children: [
            _f(
              'causative/passive',
              'made to',
              'be made to do',
              causative.drop(1) + 'られる',
            ),
            ..._ichidanBranch('causative', causative),
          ],
        ),
        _f('volitional', 'volitional', "let's / I'll", volitional),
        _f('conditional', 'conditional', 'if', conditional),
        _f(
          'imperative',
          'command',
          'do it! (rough)',
          imperative,
          children: [
            _f("imperative/don't", "don't", "don't! (rough)", dict + 'な'),
          ],
        ),
      ],
    );
    _link(root);
    return root;
  }

  void _link(VerbForm f) {
    for (final c in f.children) {
      c.parent = f;
      _link(c);
    }
  }
}

/// [v]'s forms, as a tree rooted at its dictionary form.
VerbForm conjugate(Verb v) => _Builder(v).build();

/// [f], a form of [verb], as a dictionary-style entry to study on its own
/// card: 食べちゃった, read たべちゃった, meaning "食べる (to eat) ·
/// te-form → completely → casual → past: ended up doing".
Entry formEntry(VerbForm f, Entry verb) {
  final steps = [for (final s in f.path.skip(1)) s.label].join(' → ');
  return Entry(
    word: f.text.written,
    reading: f.text.reading,
    jlpt: verb.jlpt,
    common: verb.common,
    senses: [
      Sense(
        glosses: ['${verb.word} (${verb.shortMeaning}) · $steps: ${f.meaning}'],
        partsOfSpeech: ['verb form'],
      ),
    ],
  );
}
