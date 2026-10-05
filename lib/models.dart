/// The library: manga, their chapters and pages, the bubbles placed on
/// them, and the words learned from them.
///
/// Page and cover paths are stored relative to the app's storage root, not
/// absolute. The absolute documents path is an install detail; a relative
/// path survives it moving.
library;

import 'dart:ui';

import 'core/kana.dart';
import 'core/srs.dart';

String newId() =>
    DateTime.now().microsecondsSinceEpoch.toRadixString(36) +
    (_counter++).toRadixString(36);
int _counter = 0;

class Chapter {
  Chapter({
    required this.id,
    required this.title,
    required this.pages,
    this.readUpTo = -1,
  });

  final String id;
  String title;

  /// Relative paths, in reading order.
  List<String> pages;

  /// The furthest page index reached, or -1 if never opened.
  int readUpTo;

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'pages': pages,
    'readUpTo': readUpTo,
  };

  factory Chapter.fromJson(Map<String, dynamic> j) => Chapter(
    id: j['id'] as String,
    title: j['title'] as String? ?? '',
    pages: [for (final p in j['pages'] as List? ?? const []) p as String],
    readUpTo: (j['readUpTo'] as num?)?.toInt() ?? -1,
  );
}

/// A note placed on a page: what the speech balloon says (from OCR, or
/// typed) and the reader's own translation of it, drawn as a pill at
/// [position].
class Bubble {
  Bubble({
    required this.id,
    required this.chapterId,
    required this.page,
    required this.position,
    this.region,
    this.source = '',
    this.translation = '',
  });

  final String id;
  final String chapterId;
  final int page;

  /// Centre of the pill, normalised to the page image.
  Offset position;

  /// The area the source text was read from, normalised; null for a bubble
  /// placed by hand.
  Rect? region;

  /// The Japanese.
  String source;

  /// The reader's translation.
  String translation;

  Map<String, dynamic> toJson() => {
    'id': id,
    'chapterId': chapterId,
    'page': page,
    'x': position.dx,
    'y': position.dy,
    if (region != null)
      'region': [region!.left, region!.top, region!.right, region!.bottom],
    'source': source,
    'translation': translation,
  };

  factory Bubble.fromJson(Map<String, dynamic> j) {
    final r = j['region'] as List?;
    return Bubble(
      id: j['id'] as String,
      chapterId: j['chapterId'] as String,
      page: (j['page'] as num).toInt(),
      position: Offset(
        (j['x'] as num?)?.toDouble() ?? 0.5,
        (j['y'] as num?)?.toDouble() ?? 0.5,
      ),
      region: r == null || r.length != 4
          ? null
          : Rect.fromLTRB(
              (r[0] as num).toDouble(),
              (r[1] as num).toDouble(),
              (r[2] as num).toDouble(),
              (r[3] as num).toDouble(),
            ),
      source: j['source'] as String? ?? '',
      translation: j['translation'] as String? ?? '',
    );
  }

  /// Adds [text] to the end of the Japanese — for the piece OCR missed.
  /// Returns false when there was nothing to add.
  bool appendSource(String text) {
    final t = text.trim();
    if (t.isEmpty) return false;
    source = joinText(source, t);
    return true;
  }

  /// Folds [other] into this bubble: its Japanese and translation are
  /// appended, and the region grows to cover both. For a balloon OCR read
  /// as two blocks, or one read in two drags. The caller removes [other].
  void mergeFrom(Bubble other) {
    source = joinText(source, other.source);
    translation = joinText(translation, other.translation);
    final a = region;
    final b = other.region;
    region = a == null ? b : (b == null ? a : a.expandToInclude(b));
  }
}

/// [a] and [b] joined the way the script wants: Japanese runs straight on
/// (朝 + 食 = 朝食), anything else gets a space. Empty sides drop out.
String joinText(String a, String b) {
  final x = a.trim();
  final y = b.trim();
  if (x.isEmpty) return y;
  if (y.isEmpty) return x;
  final last = x.runes.last;
  final first = y.runes.first;
  final glue = _tight(last) || _tight(first) ? '' : ' ';
  return '$x$glue$y';
}

bool _tight(int c) =>
    isJapanese(c) ||
    (c >= 0x3000 && c <= 0x303F) || // 、。「」
    (c >= 0xFF01 && c <= 0xFF60) || // ！？
    c == 0x2026; // …

class Manga {
  Manga({
    required this.id,
    required this.title,
    this.cover,
    List<Chapter>? chapters,
    List<Bubble>? bubbles,
    this.lastChapter = 0,
    this.lastPage = 0,
    DateTime? added,
    this.lastOpened,
  }) : chapters = chapters ?? [],
       bubbles = bubbles ?? [],
       added = added ?? DateTime.now();

  final String id;
  String title;

  /// Relative path; null falls back to the first page.
  String? cover;
  List<Chapter> chapters;
  List<Bubble> bubbles;
  int lastChapter;
  int lastPage;
  final DateTime added;
  DateTime? lastOpened;

  int get pageCount => chapters.fold(0, (n, c) => n + c.pages.length);

  String? get coverOrFirstPage =>
      cover ??
      chapters
          .where((c) => c.pages.isNotEmpty)
          .map((c) => c.pages.first)
          .firstOrNull;

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    if (cover != null) 'cover': cover,
    'chapters': [for (final c in chapters) c.toJson()],
    'bubbles': [for (final b in bubbles) b.toJson()],
    'lastChapter': lastChapter,
    'lastPage': lastPage,
    'added': added.toIso8601String(),
    if (lastOpened != null) 'lastOpened': lastOpened!.toIso8601String(),
  };

  factory Manga.fromJson(Map<String, dynamic> j) => Manga(
    id: j['id'] as String,
    title: j['title'] as String? ?? 'Untitled',
    cover: j['cover'] as String?,
    chapters: [
      for (final c in j['chapters'] as List? ?? const [])
        Chapter.fromJson(c as Map<String, dynamic>),
    ],
    bubbles: [
      for (final b in j['bubbles'] as List? ?? const [])
        Bubble.fromJson(b as Map<String, dynamic>),
    ],
    lastChapter: (j['lastChapter'] as num?)?.toInt() ?? 0,
    lastPage: (j['lastPage'] as num?)?.toInt() ?? 0,
    added: DateTime.tryParse(j['added'] as String? ?? ''),
    lastOpened: DateTime.tryParse(j['lastOpened'] as String? ?? ''),
  );
}

class Sense {
  const Sense({required this.glosses, this.partsOfSpeech = const []});

  final List<String> glosses;
  final List<String> partsOfSpeech;

  Map<String, dynamic> toJson() => {'glosses': glosses, 'pos': partsOfSpeech};

  factory Sense.fromJson(Map<String, dynamic> j) => Sense(
    glosses: [for (final g in j['glosses'] as List? ?? const []) '$g'],
    partsOfSpeech: [for (final p in j['pos'] as List? ?? const []) '$p'],
  );
}

/// A dictionary entry, as looked up — before or after being saved.
class Entry {
  const Entry({
    required this.word,
    required this.reading,
    required this.senses,
    this.common = false,
    this.jlpt,
    this.wanikani,
  });

  /// The written form: kanji where it has them, otherwise the kana.
  final String word;

  /// Kana reading.
  final String reading;
  final List<Sense> senses;
  final bool common;

  /// e.g. "N5". Null when the word isn't on a JLPT list.
  final String? jlpt;
  final int? wanikani;

  String get romaji => toRomaji(reading.isEmpty ? word : reading);

  bool get hasKanji => containsKanji(word);

  /// A short meaning, for a chip or a quiz option.
  String get shortMeaning {
    if (senses.isEmpty || senses.first.glosses.isEmpty) return '';
    return senses.first.glosses.take(2).join('; ');
  }

  String get allMeanings => senses.expand((s) => s.glosses).take(5).join('; ');

  Map<String, dynamic> toJson() => {
    'word': word,
    'reading': reading,
    'senses': [for (final s in senses) s.toJson()],
    'common': common,
    if (jlpt != null) 'jlpt': jlpt,
    if (wanikani != null) 'wanikani': wanikani,
  };

  factory Entry.fromJson(Map<String, dynamic> j) => Entry(
    word: j['word'] as String? ?? '',
    reading: j['reading'] as String? ?? '',
    senses: [
      for (final s in j['senses'] as List? ?? const [])
        Sense.fromJson(s as Map<String, dynamic>),
    ],
    common: j['common'] as bool? ?? false,
    jlpt: j['jlpt'] as String?,
    wanikani: (j['wanikani'] as num?)?.toInt(),
  );
}

/// A word saved to study, from a particular manga.
class Word {
  Word({
    required this.id,
    required this.mangaId,
    required this.entry,
    this.context = '',
    this.bubbleId,
    this.review = const ReviewState(),
    DateTime? added,
  }) : added = added ?? DateTime.now();

  /// Stable per manga and dictionary form, so saving the same word twice
  /// from the same book is a no-op rather than a duplicate card.
  static String idFor(String mangaId, Entry e) =>
      '$mangaId|${e.word}|${e.reading}';

  final String id;
  final String mangaId;
  final Entry entry;

  /// The sentence it was found in.
  final String context;
  final String? bubbleId;
  ReviewState review;
  final DateTime added;

  Map<String, dynamic> toJson() => {
    'id': id,
    'mangaId': mangaId,
    'entry': entry.toJson(),
    'context': context,
    if (bubbleId != null) 'bubbleId': bubbleId,
    'review': review.toJson(),
    'added': added.toIso8601String(),
  };

  factory Word.fromJson(Map<String, dynamic> j) => Word(
    id: j['id'] as String,
    mangaId: j['mangaId'] as String,
    entry: Entry.fromJson(j['entry'] as Map<String, dynamic>),
    context: j['context'] as String? ?? '',
    bubbleId: j['bubbleId'] as String?,
    review: ReviewState.fromJson(j['review'] as Map<String, dynamic>?),
    added: DateTime.tryParse(j['added'] as String? ?? ''),
  );
}

class Settings {
  Settings({this.rightToLeft = true, this.speechRate = 0.45});

  /// Manga reads right to left; swiping to the next page goes the same way.
  bool rightToLeft;
  double speechRate;

  Map<String, dynamic> toJson() => {
    'rightToLeft': rightToLeft,
    'speechRate': speechRate,
  };

  factory Settings.fromJson(Map<String, dynamic>? j) => Settings(
    rightToLeft: j?['rightToLeft'] as bool? ?? true,
    speechRate: (j?['speechRate'] as num?)?.toDouble() ?? 0.45,
  );
}

enum ChapterStatus { unread, reading, complete }

ChapterStatus statusOf(Chapter c) {
  if (c.readUpTo < 0) return ChapterStatus.unread;
  if (c.pages.isNotEmpty && c.readUpTo >= c.pages.length - 1) {
    return ChapterStatus.complete;
  }
  return ChapterStatus.reading;
}

/// Pages read across the whole manga, counting each chapter up to its
/// furthest page.
int pagesRead(Manga m) => m.chapters.fold(
  0,
  (n, c) =>
      n + (c.readUpTo < 0 ? 0 : (c.readUpTo + 1).clamp(0, c.pages.length)),
);

int chaptersComplete(Manga m) =>
    m.chapters.where((c) => statusOf(c) == ChapterStatus.complete).length;
