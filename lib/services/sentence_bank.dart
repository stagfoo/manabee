/// The bundled sentences, loaded once on first use.
library;

import 'package:flutter/services.dart';

import '../core/sentences.dart';

class SentenceBank {
  static Future<List<Sentence>>? _all;

  static Future<List<Sentence>> load() => _all ??= rootBundle
      .loadString('assets/sentences/sentences.tsv')
      .then(parseSentences);
}
