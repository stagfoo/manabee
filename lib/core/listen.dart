/// Listen mode: the deck as an audio playlist — each word said in
/// Japanese, a pause to recall it, the meaning said in English, a chime,
/// and on to the next. For a walk or a commute, eyes free.
///
/// This is only the plan for one word: what to play, in order, and how
/// long to wait between. The screen plays it. Pure, so the timing is
/// tested without audio.
library;

enum ListenAction {
  japanese,
  meaning,
  pause,
  tone,

  /// Show the meaning on screen without saying it — when meanings are
  /// off, after the think time.
  reveal,
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
}

/// The steps for one word. [japanese] is what's spoken (the reading, so
/// the voice can't guess a kanji wrong); [meaning] is said in English.
List<ListenStep> listenSteps(
  String japanese,
  String meaning,
  ListenSettings s,
) {
  final short = Duration(milliseconds: s.thinkTime.inMilliseconds ~/ 3);
  final speakMeaning = s.sayMeaning && meaning.isNotEmpty;
  final sayJapanese = [
    ListenStep(ListenAction.japanese, text: japanese),
    if (s.repeatJapanese) ...[
      ListenStep.pause(short),
      ListenStep(ListenAction.japanese, text: japanese),
    ],
  ];
  final List<ListenStep> word;
  if (speakMeaning && s.meaningFirst) {
    word = [
      ListenStep(ListenAction.meaning, text: meaning),
      ListenStep.pause(s.thinkTime),
      ...sayJapanese,
      ListenStep.pause(short),
    ];
  } else {
    word = [
      ...sayJapanese,
      ListenStep.pause(s.thinkTime),
      if (speakMeaning) ...[
        ListenStep(ListenAction.meaning, text: meaning),
        ListenStep.pause(short),
      ] else
        const ListenStep(ListenAction.reveal),
    ];
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
