/// Choosing the focus set: the few words to study now, so the deck being
/// drilled stays a size that can actually be learned — 20, then the next
/// 20 — instead of growing with every word saved.
///
/// Ticks save as they're made. Nothing is deleted or reset: a word left
/// out keeps its progress and comes back when it's chosen again.
library;

import 'package:flutter/material.dart';

import '../core/srs.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/common.dart';

class FocusScreen extends StatefulWidget {
  const FocusScreen({super.key});

  @override
  State<FocusScreen> createState() => _FocusScreenState();
}

class _FocusScreenState extends State<FocusScreen> {
  /// Which book's words are listed; null = every book.
  String? _book;

  /// Text to find a word by: its spelling, reading, romaji or meaning.
  String _query = '';

  /// Only words with this status; null = any.
  WordStatus? _status;

  @override
  Widget build(BuildContext context) {
    final lib = AppScope.library(context);
    final books = [
      for (final m in lib.recent)
        if (lib.wordsFor(m.id).isNotEmpty) m,
    ];
    if (_book != null && !books.any((b) => b.id == _book)) _book = null;
    final shown = [
      for (final w in lib.wordsFor(_book))
        if (focusMatches(w, _query) &&
            (_status == null || wordStatusOf(w.review) == _status))
          w,
    ];
    final focused = lib.focusCount;

    return GridScaffold(
      onBack: () => Navigator.maybePop(context),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Focus',
                    style: T.headlineMd.copyWith(fontSize: 22),
                  ),
                ),
                Text(
                  '$focused chosen',
                  style: T.monoBold.copyWith(color: C.lime, fontSize: 14),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              'Tick the words to study now. Next 20 moves on to the next '
              'words you haven\'t learned yet.',
              style: T.bodyMd.copyWith(color: C.textDim, fontSize: 12),
            ),
          ),
          SizedBox(
            height: 36,
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              children: [
                _BookChip(
                  label: 'All books',
                  on: _book == null,
                  onTap: () => setState(() => _book = null),
                ),
                for (final m in books)
                  _BookChip(
                    label: m.title,
                    on: _book == m.id,
                    onTap: () => setState(() => _book = m.id),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: TextField(
              onChanged: (v) => setState(() => _query = v),
              style: T.bodyLg,
              decoration: const InputDecoration(
                isDense: true,
                hintText: 'Find a word: 食べる, taberu, eat…',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            // Wrapped, not scrolled: four short filters should all be in
            // sight.
            child: Wrap(
              runSpacing: 6,
              children: [
                _BookChip(
                  label: 'Any status',
                  on: _status == null,
                  onTap: () => setState(() => _status = null),
                ),
                for (final st in WordStatus.values)
                  _BookChip(
                    label: switch (st) {
                      WordStatus.fresh => 'New',
                      WordStatus.studying => 'Studying',
                      WordStatus.known => 'Known',
                    },
                    on: _status == st,
                    onTap: () => setState(() => _status = st),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            child: Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: C.lime,
                      foregroundColor: C.onLime,
                      minimumSize: const Size(0, 44),
                    ),
                    // The book's next words, whatever the filter shows.
                    onPressed: lib.wordsFor(_book).isEmpty
                        ? null
                        : () => lib.focusNext(mangaId: _book),
                    icon: const Icon(Icons.skip_next_rounded),
                    label: const Text('Next 20'),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: C.text,
                    side: const BorderSide(color: C.ghostBorder),
                    minimumSize: const Size(0, 44),
                  ),
                  onPressed: focused == 0 ? null : () => lib.setFocus({}),
                  child: const Text('Clear'),
                ),
              ],
            ),
          ),
          Expanded(
            child: shown.isEmpty && (_query.isNotEmpty || _status != null)
                ? Center(
                    child: Text(
                      'No words match.',
                      style: T.bodyMd.copyWith(color: C.textDim),
                    ),
                  )
                : shown.isEmpty
                ? const EmptyState(
                    emoji: '🎯',
                    title: 'No words yet',
                    body:
                        'Save words while reading, or add them to a '
                        'commonplace book.',
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 24),
                    itemCount: shown.length,
                    itemBuilder: (context, i) => _WordTile(
                      word: shown[i],
                      book: _book == null
                          ? lib.mangaById(shown[i].mangaId)?.title
                          : null,
                      onTap: () => lib.toggleFocus(shown[i]),
                      onStatus: (st) => lib.setStatus(shown[i], st),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _BookChip extends StatelessWidget {
  const _BookChip({required this.label, required this.on, required this.onTap});

  final String label;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: ChoiceChip(
      label: Text(label, style: T.pill.copyWith(color: on ? C.onLime : C.text)),
      selected: on,
      showCheckmark: false,
      selectedColor: C.lime,
      backgroundColor: C.surface,
      side: const BorderSide(color: C.border),
      shape: const StadiumBorder(),
      onSelected: (_) => onTap(),
    ),
  );
}

class _WordTile extends StatelessWidget {
  const _WordTile({
    required this.word,
    required this.onTap,
    required this.onStatus,
    this.book,
  });

  final Word word;
  final String? book;
  final VoidCallback onTap;

  /// Set by hand: a word already known needn't be drilled.
  final ValueChanged<WordStatus> onStatus;

  static String label(WordStatus s) => switch (s) {
    WordStatus.fresh => 'new',
    WordStatus.studying => 'studying',
    WordStatus.known => 'known',
  };

  static Color colour(WordStatus s) => switch (s) {
    WordStatus.fresh => C.textDim,
    WordStatus.studying => C.lime,
    WordStatus.known => C.mint,
  };

  @override
  Widget build(BuildContext context) {
    final e = word.entry;
    final status = wordStatusOf(word.review);
    return CheckboxListTile(
      value: word.focus,
      onChanged: (_) => onTap(),
      controlAffinity: ListTileControlAffinity.leading,
      activeColor: C.lime,
      checkColor: C.onLime,
      dense: true,
      title: Text.rich(
        TextSpan(
          children: [
            TextSpan(text: e.word, style: T.jp.copyWith(fontSize: 18)),
            if (e.hasKanji)
              TextSpan(
                text: '  ${e.reading}',
                style: T.bodyMd.copyWith(color: C.textDim),
              ),
          ],
        ),
      ),
      subtitle: Text(
        [e.shortMeaning, ?book].join('  ·  '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: T.bodyMd.copyWith(color: C.textDim, fontSize: 12),
      ),
      secondary: PopupMenuButton<WordStatus>(
        tooltip: 'Change status',
        initialValue: status,
        color: C.elevated,
        onSelected: onStatus,
        itemBuilder: (_) => [
          for (final s in WordStatus.values)
            PopupMenuItem(
              value: s,
              child: Text(switch (s) {
                WordStatus.fresh => 'New — not studied yet',
                WordStatus.studying => 'Studying — learning it now',
                WordStatus.known => 'Known — I know this already',
              }, style: T.bodyMd.copyWith(color: colour(s))),
            ),
        ],
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 4, 4, 4),
          decoration: BoxDecoration(
            border: Border.all(color: colour(status).withValues(alpha: 0.6)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label(status),
                style: T.monoSm.copyWith(color: colour(status)),
              ),
              Icon(
                Icons.arrow_drop_down_rounded,
                color: colour(status),
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Whether [w] matches [query] — by spelling, reading, romaji or any
/// meaning, ignoring case.
bool focusMatches(Word w, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return true;
  final e = w.entry;
  return e.word.contains(q) ||
      e.reading.contains(q) ||
      e.romaji.toLowerCase().contains(q) ||
      e.senses.any((s) => s.glosses.any((g) => g.toLowerCase().contains(q)));
}
