import 'package:flutter_test/flutter_test.dart';
import 'package:manabee/core/conjugate.dart';
import 'package:manabee/core/joining.dart';
import 'package:manabee/core/particles.dart';
import 'package:manabee/models.dart';

Entry verb(String w, String r, String pos) => Entry(
  word: w,
  reading: r,
  senses: [
    Sense(glosses: ['to x'], partsOfSpeech: [pos]),
  ],
);

void main() {
  group('particles', () {
    test('every rule exists once, and has gaps to practise', () {
      final ids = kParticleRules.map((r) => r.id).toList();
      expect(ids.toSet(), hasLength(ids.length));
      final practised = {
        for (final g in kFixedGaps) g.ruleId,
        for (final v in kCoreVerbs) ...gapsForVerb(v).map((g) => g.ruleId),
      };
      expect(practised, containsAll(ids));
    });

    test('the verb decides the particle', () {
      String rules(Entry e) =>
          gapsForVerb(e).map((g) => '${g.ruleId}:$g').join(' ');
      // Transitive: an object with を, and a place of action with で.
      expect(
        rules(verb('食べる', 'たべる', 'transitive verb')),
        'wo-object:それ＿食べる de-place:ここ＿食べる ni-time:七時＿食べる',
      );
      // Intransitive action: no object.
      expect(
        rules(verb('遊ぶ', 'あそぶ', 'intransitive verb')),
        'de-place:ここ＿遊ぶ ni-time:七時＿遊ぶ',
      );
      // Motion: a destination with に (へ also right).
      expect(
        rules(verb('行く', 'いく', 'intransitive verb')),
        startsWith('ni-destination:そこ＿行く'),
      );
      // Existence: a location with に, never で.
      expect(
        rules(verb('住む', 'すむ', 'intransitive verb')),
        startsWith('ni-existence:ここ＿住む'),
      );
      expect(
        rules(verb('住む', 'すむ', 'intransitive verb')),
        isNot(contains('de-place')),
      );
      // Not a verb: nothing.
      expect(gapsForVerb(verb('学校', 'がっこう', 'noun (common)')), isEmpty);
    });

    test('choices: the answer and three wrong ones, never a second right', () {
      final all = [
        ...kFixedGaps,
        for (final v in kCoreVerbs) ...gapsForVerb(v),
      ];
      for (final g in all) {
        for (var seed = 0; seed < 5; seed++) {
          final c = choicesFor(g, seed);
          expect(c, hasLength(4));
          expect(c.toSet(), hasLength(4));
          expect(c.where(g.answers.contains), [g.rule.particle], reason: '$g');
        }
      }
      // は and も would be fine Japanese in any gap: offered only as answers.
      for (final g in all) {
        final c = choicesFor(g, 0);
        if (g.rule.particle != 'は') expect(c, isNot(contains('は')));
        if (g.rule.particle != 'も') expect(c, isNot(contains('も')));
      }
      // A destination: へ is right too, so it's never offered as wrong.
      final dest = gapsForVerb(kCoreVerbs.firstWhere((e) => e.word == '行く'))
          .first;
      expect(choicesFor(dest, 0), isNot(contains('へ')));
    });
  });

  group('joining', () {
    const taberu = Verb('食べる', 'たべる', VerbGroup.ichidan);
    const kaku = Verb('書く', 'かく', VerbGroup.godan);
    const yomu = Verb('読む', 'よむ', VerbGroup.godan);
    const suru = Verb('する', 'する', VerbGroup.suru);

    test('each joiner on its form', () {
      String j(Verb v, String id) => joined(v, joiner(id));
      expect(j(taberu, 'kara'), '食べるから');
      expect(j(taberu, 'nagara'), '食べながら');
      expect(j(kaku, 'nagara'), '書きながら');
      expect(j(taberu, 'te'), '食べて');
      expect(j(yomu, 'tekara'), '読んでから');
      expect(j(yomu, 'temo'), '読んでも');
      expect(j(kaku, 'temo'), '書いても');
      expect(j(taberu, 'tara'), '食べたら');
      expect(j(yomu, 'tara'), '読んだら');
      expect(j(yomu, 'tari'), '読んだり');
      expect(j(taberu, 'ba'), '食べれば');
      expect(j(kaku, 'ba'), '書けば');
      expect(j(suru, 'nagara'), 'しながら');
      expect(j(suru, 'maeni'), 'する前に');
    });

    test('questions: one right answer, a rival, wrong forms', () {
      for (final v in [taberu, kaku, yomu, suru]) {
        for (final jn in kJoiners) {
          final q = joinQuestion(v, jn, 3);
          expect(q.choices, contains(q.answer));
          expect(q.choices.toSet(), hasLength(q.choices.length));
          expect(q.choices.length, greaterThanOrEqualTo(3), reason: '$jn');
        }
      }
      // Real Japanese is never offered as a mistake.
      for (final seed in [0, 1, 2, 3]) {
        expect(
          joinQuestion(yomu, joiner('kara'), seed).choices,
          isNot(contains('読んだから')),
        );
        expect(
          joinQuestion(yomu, joiner('tara'), seed).choices,
          isNot(contains('読んでたら')),
        );
      }
      final q = joinQuestion(kaku, joiner('temo'), 1);
      expect(q.answer, '書いても');
      expect(q.choices, contains('書いたら').or(contains('書くのに')));
    });
  });
}

extension on Matcher {
  Matcher or(Matcher other) => anyOf(this, other);
}
