/// The library, held in memory and written to one JSON file.
///
/// One file rather than a database: a personal library is a few dozen
/// manga and a few thousand words, which is well under a megabyte of JSON,
/// and a file you can open and read is worth more than query speed nobody
/// needs. Writes go to a temp file and are renamed over the original, so a
/// crash mid-write leaves the previous library rather than half of one.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../core/srs.dart';
import '../models.dart';

/// Where the library lives. Abstract so widget tests run on memory.
abstract class LibraryStorage {
  /// The directory relative page and cover paths resolve against.
  String get root;
  Future<String?> read();
  Future<void> write(String json);
}

class FileStorage implements LibraryStorage {
  FileStorage(this.root);

  @override
  final String root;

  File get _file => File('$root/library.json');

  @override
  Future<String?> read() async =>
      await _file.exists() ? await _file.readAsString() : null;

  @override
  Future<void> write(String json) async {
    final tmp = File('${_file.path}.tmp');
    await tmp.writeAsString(json, flush: true);
    await tmp.rename(_file.path);
  }
}

class MemoryStorage implements LibraryStorage {
  MemoryStorage([this.content]);

  String? content;

  @override
  String get root => '/memory';

  @override
  Future<String?> read() async => content;

  @override
  Future<void> write(String json) async => content = json;
}

class Library extends ChangeNotifier {
  Library(this.storage);

  final LibraryStorage storage;
  List<Manga> mangas = [];
  List<Word> words = [];
  Settings settings = Settings();
  Timer? _saveTimer;

  String resolve(String relative) => '${storage.root}/$relative';

  Future<void> load() async {
    final raw = await storage.read();
    if (raw != null) {
      try {
        final j = jsonDecode(raw) as Map<String, dynamic>;
        mangas = [
          for (final m in j['mangas'] as List? ?? const [])
            Manga.fromJson(m as Map<String, dynamic>),
        ];
        words = [
          for (final w in j['words'] as List? ?? const [])
            Word.fromJson(w as Map<String, dynamic>),
        ];
        settings = Settings.fromJson(j['settings'] as Map<String, dynamic>?);
      } catch (e) {
        // A corrupt library must not brick the app. Keep the bad file
        // aside rather than overwriting the only copy of someone's work.
        debugPrint('library.json unreadable: $e');
        if (storage is FileStorage) {
          final f = File('${storage.root}/library.json');
          await f.copy('${storage.root}/library.corrupt.json');
        }
      }
    }
    notifyListeners();
  }

  Map<String, dynamic> toJson() => {
    'version': 1,
    'mangas': [for (final m in mangas) m.toJson()],
    'words': [for (final w in words) w.toJson()],
    'settings': settings.toJson(),
  };

  /// Notifies now and saves shortly after. Dragging a bubble or paging
  /// through a chapter changes state many times a second; one write after
  /// it settles is enough.
  void changed() {
    notifyListeners();
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 400), save);
  }

  Future<void> save() async {
    _saveTimer?.cancel();
    _saveTimer = null;
    await storage.write(jsonEncode(toJson()));
  }

  Manga? mangaById(String id) => mangas.where((m) => m.id == id).firstOrNull;

  /// Most recently opened first, then most recently added.
  List<Manga> get recent => [...mangas]
    ..sort((a, b) {
      final ao = a.lastOpened ?? a.added;
      final bo = b.lastOpened ?? b.added;
      return bo.compareTo(ao);
    });

  void upsertManga(Manga m) {
    final i = mangas.indexWhere((x) => x.id == m.id);
    if (i < 0) {
      mangas.add(m);
    } else {
      mangas[i] = m;
    }
    changed();
  }

  Future<void> deleteManga(Manga m) async {
    mangas.removeWhere((x) => x.id == m.id);
    words.removeWhere((w) => w.mangaId == m.id);
    changed();
    final dir = Directory(resolve('manga/${m.id}'));
    if (await dir.exists()) await dir.delete(recursive: true);
  }

  void markRead(Manga m, int chapterIndex, int page) {
    m.lastChapter = chapterIndex;
    m.lastPage = page;
    m.lastOpened = DateTime.now();
    final c = m.chapters[chapterIndex];
    if (page > c.readUpTo) c.readUpTo = page;
    changed();
  }

  List<Bubble> bubblesOn(Manga m, String chapterId, int page) => m.bubbles
      .where((b) => b.chapterId == chapterId && b.page == page)
      .toList();

  int bubbleCount(Manga m, String chapterId) =>
      m.bubbles.where((b) => b.chapterId == chapterId).length;

  /// Reading-order number of [b] on its page, 1-based, for "Bubble #03".
  int bubbleNumber(Manga m, Bubble b) =>
      bubblesOn(m, b.chapterId, b.page).indexWhere((x) => x.id == b.id) + 1;

  void addBubble(Manga m, Bubble b) {
    m.bubbles.add(b);
    changed();
  }

  void removeBubble(Manga m, Bubble b) {
    m.bubbles.removeWhere((x) => x.id == b.id);
    changed();
  }

  List<Word> wordsFor(String? mangaId) => mangaId == null
      ? words
      : words.where((w) => w.mangaId == mangaId).toList();

  bool isSaved(String mangaId, Entry e) =>
      words.any((w) => w.id == Word.idFor(mangaId, e));

  /// Saves [e] as a word from [mangaId]. Returns false if it was already
  /// saved (and leaves the existing card's progress alone).
  bool saveWord(
    String mangaId,
    Entry e, {
    String context = '',
    String? bubbleId,
  }) {
    final id = Word.idFor(mangaId, e);
    if (words.any((w) => w.id == id)) return false;
    words.add(
      Word(
        id: id,
        mangaId: mangaId,
        entry: e,
        context: context,
        bubbleId: bubbleId,
      ),
    );
    changed();
    return true;
  }

  void removeWord(String id) {
    words.removeWhere((w) => w.id == id);
    changed();
  }

  void answer(Word w, {required bool knewIt}) {
    w.review = w.review.answer(knewIt: knewIt, now: DateTime.now());
    changed();
  }

  int learnedCount(String? mangaId) =>
      wordsFor(mangaId).where((w) => w.review.learned).length;

  int dueWords(String? mangaId) =>
      dueCount(wordsFor(mangaId), (w) => w.review, DateTime.now());

  @override
  void dispose() {
    _saveTimer?.cancel();
    super.dispose();
  }
}
