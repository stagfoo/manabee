import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:manabee/core/listen.dart';

String plan(List<ListenStep> s) => s.join(' ');

void main() {
  test('Japanese, think time, meaning, tone', () {
    final s = listenSteps('わかい', 'young, youthful', const ListenSettings());
    expect(
      plan(s),
      'japanese(わかい) pause(2500ms) meaning(young, youthful) pause(833ms) '
      'tone pause(833ms)',
    );
  });

  test('the Japanese twice, when asked for', () {
    final s = listenSteps(
      'わかい',
      'young',
      const ListenSettings(
        repeatJapanese: true,
        thinkTime: Duration(seconds: 3),
      ),
    );
    expect(
      plan(s),
      'japanese(わかい) pause(1000ms) japanese(わかい) pause(3000ms) '
      'meaning(young) pause(1000ms) tone pause(1000ms)',
    );
  });

  test('meaning off: Japanese and chimes only', () {
    final s = listenSteps(
      'わかい',
      'young',
      const ListenSettings(sayMeaning: false),
    );
    expect(s.where((x) => x.action == ListenAction.meaning), isEmpty);
    expect(s.last.action, ListenAction.pause);
    expect(s[s.length - 2].action, ListenAction.tone);
  });

  test('every word ends with the tone', () {
    for (final settings in const [
      ListenSettings(),
      ListenSettings(sayMeaning: false),
      ListenSettings(repeatJapanese: true),
    ]) {
      expect(
        listenSteps(
          'あ',
          'x',
          settings,
        ).where((s) => s.action == ListenAction.tone),
        hasLength(1),
      );
    }
  });

  test('spoken meanings drop bracketed notes and keep two glosses', () {
    expect(
      spokenMeaning(['to play (games, sports)', 'to enjoy oneself', 'x']),
      'to play, to enjoy oneself',
    );
    expect(spokenMeaning(['young', 'youthful']), 'young, youthful');
    expect(spokenMeaning(['(of a person)']), '');
  });

  test('chime before each word', () {
    final s = listenSteps(
      'わかい',
      'young',
      const ListenSettings(toneBefore: true),
    );
    expect(
      plan(s),
      'tone pause(833ms) japanese(わかい) pause(2500ms) meaning(young) '
      'pause(833ms)',
    );
  });

  test('meaning first: English, think, then the Japanese', () {
    final s = listenSteps(
      'わかい',
      'young',
      const ListenSettings(meaningFirst: true),
    );
    expect(
      plan(s),
      'meaning(young) pause(2500ms) japanese(わかい) pause(833ms) '
      'tone pause(833ms)',
    );
  });

  test('meaning first with the chime before and the Japanese twice', () {
    final s = listenSteps(
      'わかい',
      'young',
      const ListenSettings(
        meaningFirst: true,
        toneBefore: true,
        repeatJapanese: true,
      ),
    );
    expect(
      plan(s),
      'tone pause(833ms) meaning(young) pause(2500ms) japanese(わかい) '
      'pause(833ms) japanese(わかい) pause(833ms)',
    );
  });

  test('meanings off: the meaning is shown after the think time', () {
    final s = listenSteps(
      'わかい',
      'young',
      const ListenSettings(sayMeaning: false, meaningFirst: true),
    );
    // Meaning-first needs a spoken meaning; without one it's Japanese first.
    expect(plan(s), 'japanese(わかい) pause(2500ms) reveal tone pause(833ms)');
  });

  test('exactly one chime per word, in every combination', () {
    for (final before in [false, true]) {
      for (final first in [false, true]) {
        for (final meaning in [false, true]) {
          final s = listenSteps(
            'あ',
            'x',
            ListenSettings(
              toneBefore: before,
              meaningFirst: first,
              sayMeaning: meaning,
            ),
          );
          expect(
            s.where((x) => x.action == ListenAction.tone),
            hasLength(1),
            reason: 'before=$before first=$first meaning=$meaning',
          );
          expect(
            s.first.action,
            before ? ListenAction.tone : isNot(ListenAction.tone),
          );
        }
      }
    }
  });

  test('the sentence comes after the word, before the chime', () {
    final s = listenSteps(
      'わかい',
      'young',
      const ListenSettings(saySentence: true),
      sentence: '若い頃の記憶',
    );
    expect(
      plan(s),
      'japanese(わかい) pause(2500ms) meaning(young) pause(833ms) '
      'sentence(若い頃の記憶) pause(833ms) tone pause(833ms)',
    );
    // No sentence, or the option off: no sentence step.
    expect(
      plan(
        listenSteps('わかい', 'young', const ListenSettings(saySentence: true)),
      ),
      isNot(contains('sentence')),
    );
  });

  group('playlist', () {
    const f = Familiarity.fresh, w = Familiarity.weak;
    const r = Familiarity.review, k = Familiarity.known;

    test('as saved', () {
      expect(
        buildPlaylist([r, r, r], ListenOrder.saved, Random(1)).join(' '),
        '0 1 2',
      );
    });

    test('shuffled plays everything once', () {
      final p = buildPlaylist(
        List.filled(20, r),
        ListenOrder.shuffled,
        Random(2),
      );
      expect(p.map((e) => e.word).toSet().length, 20);
      expect(p.map((e) => e.word).toList(), isNot(List.generate(20, (i) => i)));
    });

    test('weakest first: weak, new, review, learned', () {
      final fam = [k, r, f, w, k, w, f, r];
      final p = buildPlaylist(fam, ListenOrder.weakest, Random(3));
      final groups = p.map((e) => fam[e.word]).toList();
      expect(groups, [w, w, f, f, r, r, k, k]);
    });

    test('repeats: new and weak words come back 2 and 6 items later', () {
      final p = buildPlaylist(
        [f, r, r, r, r, r, r, r, r, r],
        ListenOrder.saved,
        Random(4),
        repeats: true,
      );
      final plays = [
        for (var i = 0; i < p.length; i++)
          if (p[i].word == 0) i,
      ];
      expect(plays, [0, 3, 10]); // first, +2 items between, then +6
      expect(p.where((e) => e.word == 1), hasLength(1)); // reviews once
    });

    test('back to back only when nothing else is left', () {
      for (var seed = 0; seed < 30; seed++) {
        final p = buildPlaylist(
          List.filled(5, f),
          ListenOrder.shuffled,
          Random(seed),
          repeats: true,
        );
        expect(p, hasLength(15));
        for (var i = 1; i < p.length; i++) {
          if (p[i].word != p[i - 1].word) continue;
          expect(
            p.skip(i).every((e) => e.word == p[i].word),
            isTrue,
            reason: 'seed $seed: $p',
          );
        }
      }
    });

    test('a single new word still gets its repeats', () {
      final p = buildPlaylist([f], ListenOrder.saved, Random(5), repeats: true);
      expect(p.join(' '), '0 0+1 0+2');
    });

    test('adaptive think time: longer for new, shorter for learned', () {
      const base = Duration(seconds: 2);
      expect(adaptiveThinkTime(base, f), const Duration(seconds: 3));
      expect(adaptiveThinkTime(base, r), base);
      expect(adaptiveThinkTime(base, k), const Duration(milliseconds: 1400));
    });
  });
}
