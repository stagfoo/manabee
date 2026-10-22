import 'package:flutter_test/flutter_test.dart';
import 'package:manabee/core/conjugate.dart';
import 'package:manabee/core/deinflect.dart';

Map<String, String> forms(Verb v) => {
  for (final f in conjugate(v).all) f.id: f.text.written,
};

void main() {
  const taberu = Verb('食べる', 'たべる', VerbGroup.ichidan);
  const kaku = Verb('書く', 'かく', VerbGroup.godan);
  const yomu = Verb('読む', 'よむ', VerbGroup.godan);
  const kau = Verb('買う', 'かう', VerbGroup.godan);
  const iku = Verb('行く', 'いく', VerbGroup.godan, special: 'iku');
  const suru = Verb('する', 'する', VerbGroup.suru);
  const benkyou = Verb('勉強する', 'べんきょうする', VerbGroup.suru);
  const kuru = Verb('来る', 'くる', VerbGroup.kuru);
  const kuruKana = Verb('くる', 'くる', VerbGroup.kuru);
  const aru = Verb('ある', 'ある', VerbGroup.godan, special: 'aru');
  const irassharu = Verb(
    'いらっしゃる',
    'いらっしゃる',
    VerbGroup.godan,
    special: 'aru-honorific',
  );

  test('ichidan: 食べる', () {
    final f = forms(taberu);
    expect(f['polite'], '食べます');
    expect(f['negative'], '食べない');
    expect(f['negative/past'], '食べなかった');
    expect(f['negative/if/must'], '食べなきゃ');
    expect(f['negative/must'], '食べなくちゃ');
    expect(f['negative/n'], '食べん');
    expect(f['past'], '食べた');
    expect(f['past/if'], '食べたら');
    expect(f['te'], '食べて');
    expect(f['te/progressive'], '食べている');
    expect(f['te/progressive/casual'], '食べてる');
    expect(f['te/progressive/casual/past'], '食べてた');
    expect(f['te/shimau/casual'], '食べちゃう');
    expect(f['te/shimau/casual/past'], '食べちゃった');
    expect(f['te/oku/casual'], '食べとく');
    expect(f['te/dame/casual'], '食べちゃだめ');
    expect(f['potential'], '食べられる');
    expect(f['potential/casual'], '食べれる');
    expect(f['potential/negative'], '食べられない');
    expect(f['passive'], '食べられる');
    expect(f['causative'], '食べさせる');
    expect(f['causative/passive'], '食べさせられる');
    expect(f['volitional'], '食べよう');
    expect(f['conditional'], '食べれば');
    expect(f['imperative'], '食べろ');
    expect(f["imperative/don't"], '食べるな');
    expect(f['polite/want'], '食べたい');
    expect(f['polite/want/past'], '食べたかった');
    expect(f['polite/while'], '食べながら');
  });

  test('godan: 書く, 読む (で), 買う (わ)', () {
    final k = forms(kaku);
    expect(k['polite'], '書きます');
    expect(k['negative'], '書かない');
    expect(k['te'], '書いて');
    expect(k['past'], '書いた');
    expect(k['potential'], '書ける');
    expect(k['passive'], '書かれる');
    expect(k['causative'], '書かせる');
    expect(k['volitional'], '書こう');
    expect(k['conditional'], '書けば');
    expect(k['imperative'], '書け');
    expect(k.containsKey('potential/casual'), isFalse);

    final y = forms(yomu);
    expect(y['te'], '読んで');
    expect(y['te/progressive/casual'], '読んでる');
    expect(y['te/shimau/casual'], '読んじゃう');
    expect(y['te/shimau/casual/past'], '読んじゃった');
    expect(y['te/oku/casual'], '読んどく');
    expect(y['te/dame/casual'], '読んじゃだめ');

    expect(forms(kau)['negative'], '買わない');
    expect(forms(kau)['te'], '買って');
  });

  test('the exceptions: 行く, ある, いらっしゃる', () {
    expect(forms(iku)['te'], '行って');
    expect(forms(iku)['past'], '行った');
    expect(forms(iku)['te/shimau/casual'], '行っちゃう');
    expect(forms(aru)['negative'], 'ない');
    expect(forms(aru)['negative/past'], 'なかった');
    expect(forms(aru).containsKey('negative/n'), isFalse);
    expect(forms(irassharu)['polite'], 'いらっしゃいます');
    expect(forms(irassharu)['imperative'], 'いらっしゃい');
  });

  test('する, 勉強する', () {
    final s = forms(suru);
    expect(s['polite'], 'します');
    expect(s['negative'], 'しない');
    expect(s['negative/n'], 'せん');
    expect(s['te'], 'して');
    expect(s['potential'], 'できる');
    expect(s['passive'], 'される');
    expect(s['causative'], 'させる');
    expect(s['volitional'], 'しよう');
    expect(s['conditional'], 'すれば');
    expect(s['imperative'], 'しろ');
    final b = forms(benkyou);
    expect(b['potential'], '勉強できる');
    expect(b['negative'], '勉強しない');
    expect(b['te/progressive/casual'], '勉強してる');
  });

  test('来る: the kanji stays, the reading changes', () {
    final root = conjugate(kuru);
    final neg = root.all.firstWhere((f) => f.id == 'negative');
    expect(neg.text.written, '来ない');
    expect(neg.text.reading, 'こない');
    final f = forms(kuru);
    expect(f['polite'], '来ます');
    expect(f['volitional'], '来よう');
    expect(f['conditional'], '来れば');
    expect(f['imperative'], '来い');
    expect(f['potential'], '来られる');
    expect(f['potential/casual'], '来れる');
    final k = forms(kuruKana);
    expect(k['negative'], 'こない');
    expect(k['te'], 'きて');
    expect(k['volitional'], 'こよう');
    expect(k['conditional'], 'くれば');
  });

  test('rules and paths', () {
    final root = conjugate(taberu);
    final past = root.find('食べられなかった')!;
    expect(past.path.map((f) => f.label), [
      'dictionary form',
      'potential',
      'negative',
      'past',
    ]);
    expect(root.children.firstWhere((f) => f.id == 'negative').rule, 'る → ない');
    expect(root.find('食べてる')!.register, Register.contraction);
    expect(root.find('食べます')!.register, Register.polite);
    expect(changeRule('かく', 'かかない'), 'く → かない');
    expect(changeRule('たべて', 'たべている'), 'て → ている');
  });

  test('every form on the map traces back to its verb when tapped', () {
    // So whatever the map teaches, the reader can look up.
    final missing = <String>[];
    for (final v in [
      taberu,
      kaku,
      yomu,
      kau,
      iku,
      suru,
      benkyou,
      kuru,
      kuruKana,
      const Verb('話す', 'はなす', VerbGroup.godan),
      const Verb('待つ', 'まつ', VerbGroup.godan),
      const Verb('死ぬ', 'しぬ', VerbGroup.godan),
      const Verb('泳ぐ', 'およぐ', VerbGroup.godan),
      const Verb('遊ぶ', 'あそぶ', VerbGroup.godan),
      const Verb('帰る', 'かえる', VerbGroup.godan),
      const Verb('見る', 'みる', VerbGroup.ichidan),
    ]) {
      for (final f in conjugate(v).all.skip(1)) {
        for (final s in {f.text.written, f.text.reading}) {
          final found = deinflect(s)
              .any((d) => d.term == v.written || d.term == v.reading);
          if (!found) missing.add('${v.written} ${f.id}: $s');
        }
      }
    }
    expect(missing, isEmpty, reason: missing.join('\n'));
  });
}
