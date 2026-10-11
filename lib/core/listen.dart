/// Listen mode: the deck as an audio playlist — each word said in
/// Japanese, a pause to recall it, the meaning said in English, a chime,
/// and on to the next. For a walk or a commute, eyes free.
///
/// This is only the plan for one word: what to play, in order, and how
/// long to wait between. The screen plays it. Pure, so the timing is
/// tested without audio.
library;

import 'dart:math';

enum ListenAction {
  japanese,
  meaning,
  pause,
  tone,

  /// Show the meaning on screen without saying it — when meanings are
  /// off, after the think time.
  reveal,

  /// The sentence the word was found in, in Japanese.
  sentence,
}

class ListenStep {
  const ListenStep(
    this.action, {
    this.text = '',
    this.duration = Duration.zero,
  });

  const ListenStep.pause(Duration d) : this(ListenAction.pause, duration: d);

  final ListenAction action;

  /// What to say, for [ListenAction.japanese] and [ListenAction.meaning].
  final String text;

  /// How long to wait, for [ListenAction.pause].
  final Duration duration;

  @override
  String toString() => switch (action) {
    ListenAction.pause => 'pause(${duration.inMilliseconds}ms)',
    ListenAction.tone => 'tone',
    ListenAction.reveal => 'reveal',
    ListenAction.sentence => 'sentence($text)',
    _ => '${action.name}($text)',
  };
}

class ListenSettings {
  const ListenSettings({
    this.thinkTime = const Duration(milliseconds: 2500),
    this.sayMeaning = true,
    this.repeatJapanese = false,
    this.toneBefore = false,
    this.meaningFirst = false,
    this.saySentence = false,
  });

  /// The pause after the Japanese: time to recall the meaning before it's
  /// said. The other pauses scale from it.
  final Duration thinkTime;

  /// Off, it's Japanese and chimes only — listening without the crutch.
  final bool sayMeaning;

  /// The word twice, for one that's new or hard to catch.
  final bool repeatJapanese;

  /// The chime ahead of each word ("here comes one") rather than after it
  /// ("that was one").
  final bool toneBefore;

  /// The meaning first and the Japanese after: recall how to say it,
  /// rather than what it means.
  final bool meaningFirst;

  /// After the word, the sentence it came from — words are remembered
  /// better in the context they were met in.
  final bool saySentence;
}

/// The steps for one word. [japanese] is what's spoken (the reading, so
/// the voice can't guess a kanji wrong); [meaning] is said in English.
List<ListenStep> listenSteps(
  String japanese,
  String meaning,
  ListenSettings s, {
  String sentence = '',
}) {
  final short = Duration(milliseconds: s.thinkTime.inMilliseconds ~/ 3);
  final speakMeaning = s.sayMeaning && meaning.isNotEmpty;
  final sayJapanese = [
    ListenStep(ListenAction.japanese, text: japanese),
    if (s.repeatJapanese) ...[
      ListenStep.pause(short),
      ListenStep(ListenAction.japanese, text: japanese),
    ],
  ];
  final word = <ListenStep>[];
  if (speakMeaning && s.meaningFirst) {
    word.addAll([
      ListenStep(ListenAction.meaning, text: meaning),
      ListenStep.pause(s.thinkTime),
      ...sayJapanese,
      ListenStep.pause(short),
    ]);
  } else {
    word.addAll([
      ...sayJapanese,
      ListenStep.pause(s.thinkTime),
      if (speakMeaning) ...[
        ListenStep(ListenAction.meaning, text: meaning),
        ListenStep.pause(short),
      ] else
        const ListenStep(ListenAction.reveal),
    ]);
  }
  if (s.saySentence && sentence.isNotEmpty) {
    word.addAll([
      ListenStep(ListenAction.sentence, text: sentence),
      ListenStep.pause(short),
    ]);
  }
  const tone = ListenStep(ListenAction.tone);
  return s.toneBefore
      ? [tone, ListenStep.pause(short), ...word]
      : [...word, tone, ListenStep.pause(short)];
}

/// A meaning short enough to hear: the first sense's first two glosses,
/// without bracketed notes the voice would read out ("(of a person)").
String spokenMeaning(List<String> glosses) => glosses
    .take(2)
    .map((g) => g.replaceAll(RegExp(r'\s*\([^)]*\)'), '').trim())
    .where((g) => g.isNotEmpty)
    .join(', ');

// ---------------------------------------------------------------- playlist

/// How well a word is known, from its flash-card schedule — what the
/// playlist orders, repeats and paces by.
enum Familiarity {
  /// Never studied.
  fresh,

  /// Still in the short learning steps, or forgotten since it was known.
  weak,

  /// Known, on day-long intervals, not yet learned.
  review,

  /// Learned: a week or more between reviews.
  known,
}

/// The order a playlist plays in.
enum ListenOrder {
  /// The order the words were saved.
  saved,

  /// Shuffled — interleaving similar words is what tells them apart.
  shuffled,

  /// The weakest first: forgotten and still-learning words, then new
  /// ones, then reviews, learned words last — each group shuffled.
  weakest,
}

/// One play of one word. A word repeated in-session (see
/// [buildPlaylist]) appears more than once, with [repeat] 1, 2…
class PlaylistEntry {
  const PlaylistEntry(this.word, {this.repeat = 0});

  /// Index into the words given to [buildPlaylist].
  final int word;
  final int repeat;

  @override
  bool operator ==(Object other) =>
      other is PlaylistEntry && other.word == word && other.repeat == repeat;

  @override
  int get hashCode => Object.hash(word, repeat);

  @override
  String toString() => repeat == 0 ? '$word' : '$word+$repeat';
}

/// How many items later a repeated word comes back: soon, then later —
/// Pimsleur's graduated-interval recall, scaled to a playlist. Each
/// return is a retrieval just as it's about to slip.
const List<int> kRepeatGaps = [2, 6];

/// The play order for words of the given [familiarity].
///
/// With [repeats], new and weak words come back after [kRepeatGaps]
/// items — 2 items after the first play, then 6 after that repeat
/// (counting every play) — so a new word is heard three times at
/// widening gaps. A repeat is only played back to back with the same
/// word when nothing else is left to play.
List<PlaylistEntry> buildPlaylist(
  List<Familiarity> familiarity,
  ListenOrder order,
  Random random, {
  bool repeats = false,
}) {
  final base = List.generate(familiarity.length, (i) => i);
  switch (order) {
    case ListenOrder.saved:
      break;
    case ListenOrder.shuffled:
      base.shuffle(random);
    case ListenOrder.weakest:
      const rank = {
        Familiarity.weak: 0,
        Familiarity.fresh: 1,
        Familiarity.review: 2,
        Familiarity.known: 3,
      };
      base.shuffle(random);
      // Stable sort over a shuffled list: groups in order, shuffled within.
      final keyed = [for (var k = 0; k < base.length; k++) (k, base[k])];
      keyed.sort((a, b) {
        final r = rank[familiarity[a.$2]]!.compareTo(rank[familiarity[b.$2]]!);
        return r != 0 ? r : a.$1.compareTo(b.$1);
      });
      base
        ..clear()
        ..addAll(keyed.map((e) => e.$2));
  }
  if (!repeats) return [for (final w in base) PlaylistEntry(w)];

  final out = <PlaylistEntry>[];
  // (due position in [out], entry)
  final pending = <(int, PlaylistEntry)>[];
  // Schedules the next repeat of a word just played, if it has one left:
  // each gap counts from the play before it, so they widen.
  void scheduleAfter(PlaylistEntry played) {
    if (played.repeat >= kRepeatGaps.length) return;
    pending.add((
      out.length - 1 + kRepeatGaps[played.repeat] + 1,
      PlaylistEntry(played.word, repeat: played.repeat + 1),
    ));
  }

  void play(PlaylistEntry e) {
    out.add(e);
    final f = familiarity[e.word];
    if (e.repeat > 0 || f == Familiarity.fresh || f == Familiarity.weak) {
      scheduleAfter(e);
    }
  }

  var next = 0;
  while (next < base.length || pending.isNotEmpty) {
    pending.sort((a, b) => a.$1.compareTo(b.$1));
    final due = pending.isNotEmpty && pending.first.$1 <= out.length;
    final lastWord = out.isEmpty ? -1 : out.last.word;
    if (due && pending.first.$2.word != lastWord) {
      play(pending.removeAt(0).$2);
    } else if (next < base.length) {
      play(PlaylistEntry(base[next++]));
    } else {
      // Only repeats left: the earliest that isn't the word just played,
      // or that word if it's all there is.
      final i = pending.indexWhere((p) => p.$2.word != lastWord);
      play(pending.removeAt(i < 0 ? 0 : i).$2);
    }
  }
  return out;
}

/// The think time for a word, when it adapts: longer for what's new,
/// shorter for what's learned, so recall is effortful but within reach.
Duration adaptiveThinkTime(Duration base, Familiarity f) {
  final scale = switch (f) {
    Familiarity.fresh => 1.5,
    Familiarity.weak => 1.25,
    Familiarity.review => 1.0,
    Familiarity.known => 0.7,
  };
  return Duration(milliseconds: (base.inMilliseconds * scale).round());
}
