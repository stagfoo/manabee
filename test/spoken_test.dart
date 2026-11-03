import 'package:flutter_test/flutter_test.dart';
import 'package:manabee/models.dart';
import 'package:manabee/services/dictionary.dart';

Entry e(String w, String r, {int? spoken}) => Entry(
  word: w,
  reading: r,
  senses: const [
    Sense(glosses: ['x']),
  ],
  spoken: spoken,
);

class Local implements Dictionary {
  Local(this.ranks);

  final Map<String, int> ranks;

  @override
  Future<List<Entry>> lookup(String q) async => [
    if (ranks.containsKey(q)) e(q, 'r$q', spoken: ranks[q]),
  ];

  @override
  Future<List<Entry>> jlptWords(String level) async => const [];
}

void main() {
  test('spoken rank as five dots', () {
    expect(e('a', 'a', spoken: 1).spokenDots, 5);
    expect(e('a', 'a', spoken: 300).spokenDots, 5);
    expect(e('a', 'a', spoken: 301).spokenDots, 4);
    expect(e('a', 'a', spoken: 5000).spokenDots, 3);
    expect(e('a', 'a', spoken: 12000).spokenDots, 2);
    expect(e('a', 'a', spoken: 40000).spokenDots, 1);
    expect(e('a', 'a').spokenDots, 0);
    expect(e('a', 'a', spoken: 10).spokenLabel, 'very common in speech');
  });

  test('the rank is read from the dictionary row and kept when saved', () {
    final row = entryFromRow(
      '{"k":["帰る"],"r":["かえる"],"s":[{"g":["to go home"],"p":["v5r"]}],"f":42}',
      '帰る',
      const {},
    );
    expect(row.spoken, 42);
    expect(Entry.fromJson(row.toJson()).spoken, 42);
  });

  test(
    'English results: most-said first, the unranked after in order',
    () async {
      final jisho = [
        e('疲弊', 'rひへい'), // literary, never came up
        e('疲れる', 'rつかれる'),
        e('倦怠', 'rけんたい'),
        e('くたびれる', 'rくたびれる'),
      ];
      final sorted = await bySpoken(jisho, Local({'疲れる': 800, 'くたびれる': 9000}));
      expect(sorted.map((x) => x.word), ['疲れる', 'くたびれる', '疲弊', '倦怠']);
      expect(sorted.first.spoken, 800);
    },
  );
}
