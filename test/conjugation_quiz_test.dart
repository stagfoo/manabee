import 'package:flutter_test/flutter_test.dart';
import 'package:manabee/core/conjugate.dart';
import 'package:manabee/core/conjugation_quiz.dart';

const verbs = [
  Verb('食べる', 'たべる', VerbGroup.ichidan),
  Verb('見る', 'みる', VerbGroup.ichidan),
  Verb('帰る', 'かえる', VerbGroup.godan),
  Verb('書く', 'かく', VerbGroup.godan),
  Verb('泳ぐ', 'およぐ', VerbGroup.godan),
  Verb('話す', 'はなす', VerbGroup.godan),
  Verb('待つ', 'まつ', VerbGroup.godan),
  Verb('読む', 'よむ', VerbGroup.godan),
  Verb('買う', 'かう', VerbGroup.godan),
  Verb('行く', 'いく', VerbGroup.godan, special: 'iku'),
  Verb('する', 'する', VerbGroup.suru),
  Verb('来る', 'くる', VerbGroup.kuru),
];

void main() {
  test('every verb, every form: one right answer among four', () {
    for (final v in verbs) {
      final root = conjugate(v);
      for (final (id, _) in kQuizForms) {
        for (final seed in [0, 3, 7]) {
          final q = conjugationQuestion(v, id, seed);
          final right = root.all.firstWhere((f) => f.id == id).text.written;
          expect(q.answer, right);
          expect(q.choices, hasLength(4), reason: '${v.written} $id');
          expect(q.choices.toSet(), hasLength(4));
          expect(q.choices.where((c) => c == right), hasLength(1));
          // A casual form of the same thing is right too: never offered.
          for (final f in root.all.where(
            (f) => f.id.startsWith('$id/casual'),
          )) {
            expect(q.choices, isNot(contains(f.text.written)));
          }
        }
      }
    }
  });

  test('the wrong choices are the mistakes people make', () {
    Set<String> choices(Verb v, String id) => {
      for (final seed in [0, 1, 2]) ...conjugationQuestion(v, id, seed).choices,
    };
    // 帰る conjugated as if ichidan; 食べる as if godan.
    expect(choices(verbs[2], 'past'), contains('帰た'));
    expect(choices(verbs[2], 'negative'), contains('帰ない'));
    expect(choices(verbs[0], 'past'), contains('食べった'));
    expect(choices(verbs[0], 'negative'), contains('食べらない'));
    // The wrong te/ta row, and the masu-stem with the ending stuck on.
    expect(choices(verbs[3], 'te'), containsAll(['書って', '書んで']));
    expect(choices(verbs[3], 'past'), contains('書きた'));
    // 見れる is casual-right for "can see": never wrong.
    expect(choices(verbs[1], 'potential'), isNot(contains('見れる')));
  });

  test('scheduled per rule: a form for a kind of verb', () {
    expect(conjugationQuestion(verbs[3], 'te', 0).rule, 'conj:〜く:te');
    expect(conjugationQuestion(verbs[0], 'past', 0).rule, 'conj:ichidan:past');
    expect(conjugationQuestion(verbs[9], 'te', 0).rule, 'conj:行く:te');
    expect(verbKindName('〜く'), 'godan 〜く verbs');
  });
}
