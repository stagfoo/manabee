import 'package:flutter_test/flutter_test.dart';
import 'package:manabee/core/kana.dart';

void main() {
  group('toRomaji', () {
    test('plain hiragana', () {
      expect(toRomaji('わかい'), 'wakai');
      expect(toRomaji('これ'), 'kore');
      expect(toRomaji('しちふつ'), 'shichifutsu');
      expect(toRomaji('じぢづ'), 'jijizu');
    });

    test('digraphs', () {
      expect(toRomaji('きょう'), 'kyou');
      expect(toRomaji('しゃしん'), 'shashin');
      expect(toRomaji('ちゃ'), 'cha');
      expect(toRomaji('りょこう'), 'ryokou');
    });

    test('small tsu doubles the next consonant', () {
      expect(toRomaji('がっこう'), 'gakkou');
      expect(toRomaji('ずっと'), 'zutto');
      expect(toRomaji('いっしょ'), 'issho');
    });

    test('small tsu before ch becomes t', () {
      expect(toRomaji('まっちゃ'), 'matcha');
      expect(toRomaji('こっち'), 'kotchi');
    });

    test('small tsu with nothing to double is dropped', () {
      expect(toRomaji('ばかっ'), 'baka');
      expect(toRomaji('あっ!'), 'a!');
    });

    test("n before a vowel or y is n'", () {
      expect(toRomaji('きんえん'), "kin'en");
      expect(toRomaji('こんや'), "kon'ya");
      expect(toRomaji('ほん'), 'hon');
      expect(toRomaji('さんぽ'), 'sanpo');
    });

    test('katakana, long vowel mark', () {
      expect(toRomaji('ラーメン'), 'raamen');
      expect(toRomaji('コーヒー'), 'koohii');
      expect(toRomaji('スーパー'), 'suupaa');
    });

    test('katakana loanword combinations', () {
      expect(toRomaji('ファン'), 'fan');
      expect(toRomaji('パーティー'), 'paatii');
      expect(toRomaji('ヴァイオリン'), 'vaiorin');
      expect(toRomaji('ウェブ'), 'webu');
      expect(toRomaji('チェック'), 'chekku');
    });

    test('non-kana passes through', () {
      expect(toRomaji('漢字'), '漢字');
      expect(toRomaji('ABCです'), 'ABCdesu');
      expect(toRomaji(''), '');
    });

    test('long mark at the start has no vowel to repeat', () {
      expect(toRomaji('ーあ'), 'a');
    });
  });

  group('script detection', () {
    test('kanji, including the repetition mark', () {
      expect(containsKanji('若い'), isTrue);
      expect(containsKanji('人々'), isTrue);
      expect(containsKanji('わかい'), isFalse);
    });

    test('katakana folds onto hiragana, leaving ー', () {
      expect(katakanaToHiragana('カタカナー'), 'かたかなー');
    });

    test('japanese detection', () {
      expect(containsJapanese('hello'), isFalse);
      expect(containsJapanese('hello世界'), isTrue);
    });
  });
}
