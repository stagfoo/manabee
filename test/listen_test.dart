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
}
