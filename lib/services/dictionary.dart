/// The dictionary: JMdict, offline, with jisho.org only for searching by
/// English meaning.
///
/// Everything the reader asks — "is this exact text a word?", for every
/// prefix of a tapped stretch and every deinflected guess — goes to a
/// SQLite index shipped in the app (assets/dict/jmdict.db, built by
/// tool/build_dictionary.py). That's tens of questions per tap, answered
/// in well under a millisecond each, offline.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../core/kana.dart';
import '../core/scan.dart';
import '../models.dart';
import 'jisho.dart';

abstract class Dictionary {
  Future<List<Entry>> lookup(String query);
}

/// One JMdict row as an [Entry], shaped by what was looked up: a query
/// that is one of the kanji spellings shows that spelling, and a kana
/// query shows that reading. Pure, so it tests without a database.
Entry entryFromRow(String data, String query, Map<String, String> pos) {
  final j = jsonDecode(data) as Map<String, dynamic>;
  final kanji = [for (final k in j['k'] as List) k as String];
  final kana = [for (final k in j['r'] as List) k as String];
  // A word usually written in kana, met in kana, stays in kana: ここ, not
  // the dictionary's 此処.
  final usuallyKana = j['u'] == 1 && kana.contains(query);
  final word = kanji.contains(query) || usuallyKana
      ? query
      : (kanji.isNotEmpty ? kanji.first : kana.first);
  final hira = katakanaToHiragana(query);
  final reading = kana.contains(query)
      ? query
      : kana.firstWhere(
          (r) => katakanaToHiragana(r) == hira,
          orElse: () => kana.first,
        );
  return Entry(
    word: word,
    reading: reading,
    common: j['c'] == 1,
    jlpt: j['j'] as String?,
    senses: [
      for (final s in j['s'] as List)
        Sense(
          glosses: [for (final g in s['g'] as List) g as String],
          partsOfSpeech: [
            for (final p in s['p'] as List) pos[p as String] ?? p,
          ],
        ),
    ],
  );
}

class LocalDictionary implements Dictionary {
  LocalDictionary._(this._db, this._pos, this.meta);

  final Database _db;
  final Map<String, String> _pos;

  /// What the build recorded: JMdict version, entry count. For Settings.
  final Map<String, String> meta;

  static Future<LocalDictionary>? _opening;

  static Future<LocalDictionary> open() => _opening ??= _open();

  static Future<LocalDictionary> _open() async {
    final dir = await getApplicationSupportDirectory();
    final path = '${dir.path}/jmdict.db';
    final versionFile = File('${dir.path}/jmdict.version');
    final bundled = (await rootBundle.loadString('assets/dict/version.txt'))
        .trim();
    // Copied out of the APK on first run and whenever a new build ships a
    // new dictionary. The version file is checked, not the database: the
    // database is 44 MB, and loading it to compare would cost every launch
    // what the copy costs once.
    final current = await versionFile.exists()
        ? (await versionFile.readAsString()).trim()
        : '';
    if (current != bundled || !await File(path).exists()) {
      final data = await rootBundle.load('assets/dict/jmdict.db');
      await File(path).writeAsBytes(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        flush: true,
      );
      await versionFile.writeAsString(bundled);
    }
    return fromDatabase(await openDatabase(path, readOnly: true));
  }

  /// A dictionary over an already-open database — the app's copy, or the
  /// build output itself in tests.
  static Future<LocalDictionary> fromDatabase(Database db) async {
    final pos = {
      for (final r in await db.query('pos'))
        r['code']! as String: r['text']! as String,
    };
    final meta = {
      for (final r in await db.query('meta'))
        r['key']! as String: r['value']! as String,
    };
    return LocalDictionary._(db, pos, meta);
  }

  @override
  Future<List<Entry>> lookup(String query) async {
    final q = query.trim();
    if (q.isEmpty) return const [];
    for (final form in [q, ...spellingVariants(q)]) {
      final rows = await _db.rawQuery(
        'SELECT e.data FROM form f JOIN entry e ON e.id = f.entry '
        'WHERE f.text = ? ORDER BY f.rank, f.entry LIMIT 12',
        [form],
      );
      if (rows.isNotEmpty) {
        return [
          for (final r in rows) entryFromRow(r['data']! as String, form, _pos),
        ];
      }
    }
    return const [];
  }
}

/// What the app uses: Japanese to the offline dictionary, English to
/// jisho.org (the offline index has no English search).
class AppDictionary implements Dictionary {
  AppDictionary({Jisho? jisho, Future<Dictionary> Function()? local})
    : _jisho = jisho ?? Jisho(),
      _local = local ?? LocalDictionary.open;

  final Jisho _jisho;
  final Future<Dictionary> Function() _local;

  @override
  Future<List<Entry>> lookup(String query) async {
    if (!containsJapanese(query)) return _jisho.lookup(query);
    return (await _local()).lookup(query);
  }
}
