/// The focus set: a handful of words studied at a time, instead of a deck
/// that only ever grows.
///
/// "Next 20" moves the set along: the next words after the current ones,
/// in the order they were saved, that aren't learned yet. Pure, over ids,
/// so it's tested without the library.
library;

/// The batch after [current] in [ordered] (oldest first): the [count]
/// candidates that follow the last word of the current set, wrapping round
/// to the start, never repeating a word already in [current]. With nothing
/// current, it's simply the first [count].
///
/// [ordered] should already be only the candidates — unlearned words from
/// whichever books are being drawn from.
List<String> nextBatch(List<String> ordered, Set<String> current, int count) {
  if (ordered.isEmpty || count <= 0) return const [];
  var start = 0;
  for (var i = ordered.length - 1; i >= 0; i--) {
    if (current.contains(ordered[i])) {
      start = i + 1;
      break;
    }
  }
  final out = <String>[];
  for (var k = 0; k < ordered.length && out.length < count; k++) {
    final id = ordered[(start + k) % ordered.length];
    if (!current.contains(id)) out.add(id);
  }
  // Fewer than [count] new ones left: top up from the current set rather
  // than hand back a short batch, so "next" never shrinks what's studied.
  for (final id in ordered) {
    if (out.length >= count) break;
    if (current.contains(id) && !out.contains(id)) out.add(id);
  }
  return out;
}
