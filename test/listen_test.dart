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
}
