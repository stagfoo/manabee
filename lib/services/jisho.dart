/// Dictionary lookups against jisho.org, which serves JMdict.
///
/// Online on purpose. A manga's vocabulary is the whole language, not a
/// JLPT list; the offline alternative is bundling all of JMdict (tens of
/// MB) plus a deinflector. Jisho does both. Saved words keep their full
/// entry, so flash cards and games never need the network.
///
/// [parseJisho] is pure and tested against a captured response; the client
/// around it is a thin wrapper.
library;

import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models.dart';
import 'dictionary.dart';

class LookupException implements Exception {
  LookupException(this.message);
  final String message;
  @override
  String toString() => message;
}

List<Entry> parseJisho(String body) {
  final decoded = jsonDecode(body);
  if (decoded is! Map || decoded['data'] is! List) return const [];
  final out = <Entry>[];
  for (final item in decoded['data'] as List) {
    if (item is! Map) continue;
    final japanese = item['japanese'];
    if (japanese is! List || japanese.isEmpty || japanese.first is! Map) {
      continue;
    }
    final first = japanese.first as Map;
    final reading = (first['reading'] as String?) ?? '';
    final word = (first['word'] as String?) ?? reading;
    if (word.isEmpty) continue;

    final senses = <Sense>[];
    for (final s in item['senses'] as List? ?? const []) {
      if (s is! Map) continue;
      final glosses = [
        for (final g in s['english_definitions'] as List? ?? const []) '$g',
      ];
      final pos = [
        for (final p in s['parts_of_speech'] as List? ?? const []) '$p',
      ];
      // Jisho appends Wikipedia definitions as senses; they're names of
      // films and bands, never what a bubble meant.
      if (pos.contains('Wikipedia definition')) continue;
      if (glosses.isNotEmpty) {
        senses.add(Sense(glosses: glosses, partsOfSpeech: pos));
      }
    }
    if (senses.isEmpty) continue;

    String? jlpt;
    final jlptTags = item['jlpt'];
    if (jlptTags is List && jlptTags.isNotEmpty) {
      // "jlpt-n5" → "N5". An entry can sit on several lists; the easiest
      // level is the one worth showing.
      final levels = [
        for (final t in jlptTags)
          int.tryParse('$t'.replaceAll(RegExp(r'[^0-9]'), '')),
      ].whereType<int>().toList()..sort((a, b) => b.compareTo(a));
      if (levels.isNotEmpty) jlpt = 'N${levels.first}';
    }

    int? wanikani;
    for (final t in item['tags'] as List? ?? const []) {
      final m = RegExp(r'^wanikani(\d+)$').firstMatch('$t');
      if (m != null) wanikani = int.parse(m[1]!);
    }

    out.add(
      Entry(
        word: word,
        reading: reading,
        senses: senses,
        common: item['is_common'] == true,
        jlpt: jlpt,
        wanikani: wanikani,
      ),
    );
  }
  return out;
}

class Jisho implements Dictionary {
  Jisho({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  final Map<String, List<Entry>> _cache = {};

  @override
  Future<List<Entry>> lookup(String query) async {
    final q = query.trim();
    if (q.isEmpty) return const [];
    final cached = _cache[q];
    if (cached != null) return cached;
    final uri = Uri.https('jisho.org', '/api/v1/search/words', {'keyword': q});
    http.Response res;
    try {
      res = await _client.get(uri).timeout(const Duration(seconds: 12));
    } catch (_) {
      throw LookupException(
        'No connection — dictionary lookups need internet.',
      );
    }
    if (res.statusCode != 200) {
      throw LookupException('Dictionary unavailable (${res.statusCode}).');
    }
    final entries = parseJisho(utf8.decode(res.bodyBytes));
    if (_cache.length > 200) _cache.remove(_cache.keys.first);
    _cache[q] = entries;
    return entries;
  }
}
