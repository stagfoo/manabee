/// Choosing the focus set: the few words to study now, so the deck being
/// drilled stays a size that can actually be learned — 20, then the next
/// 20 — instead of growing with every word saved.
///
/// Ticks save as they're made. Nothing is deleted or reset: a word left
/// out keeps its progress and comes back when it's chosen again.
library;

import 'package:flutter/material.dart';

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

  @override
  Widget build(BuildContext context) {
    final lib = AppScope.library(context);
    final books = [
      for (final m in lib.recent)
        if (lib.wordsFor(m.id).isNotEmpty) m,
    ];
    if (_book != null && !books.any((b) => b.id == _book)) _book = null;
    final shown = lib.wordsFor(_book);
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
                    onPressed: shown.isEmpty
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
            child: shown.isEmpty
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
  const _WordTile({required this.word, required this.onTap, this.book});

  final Word word;
  final String? book;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final e = word.entry;
    final r = word.review;
    final (status, colour) = r.learned
        ? ('learned', C.mint)
        : r.isNew
        ? ('new', C.textDim)
        : ('studying', C.lime);
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
      secondary: Text(status, style: T.monoSm.copyWith(color: colour)),
    );
  }
}
