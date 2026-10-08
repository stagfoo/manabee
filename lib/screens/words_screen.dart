/// One manga's words (lime) and a dictionary search (violet) to add more
/// by hand. A second tab lists the bubbles you've translated, so the
/// translation itself can be reread without paging through the book.
library;

import 'package:flutter/material.dart';

import '../models.dart';
import '../services/jisho.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/entry_detail.dart';
import 'reader_screen.dart';

class WordsScreen extends StatefulWidget {
  const WordsScreen({super.key, required this.mangaId});

  final String mangaId;

  @override
  State<WordsScreen> createState() => _WordsScreenState();
}

class _WordsScreenState extends State<WordsScreen> {
  final _search = TextEditingController();
  List<Entry> _results = const [];
  bool _loading = false;
  String? _error;
  bool _showBubbles = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _lookup(String q) async {
    if (q.trim().isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await AppScope.dictionaryOf(context).lookup(q);
      if (mounted) {
        setState(() {
          _results = r;
          if (r.isEmpty) _error = 'No match for "$q".';
        });
      }
    } on LookupException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showWord(Word w) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              EntryDetail(w.entry, context_: w.context, surface: w.surface),
              const SizedBox(height: 16),
              GhostButton(
                label: 'Remove from deck',
                icon: Icons.delete_outline_rounded,
                onPressed: () {
                  AppScope.read(context).removeWord(w.id);
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lib = AppScope.library(context);
    final m = lib.mangaById(widget.mangaId);
    if (m == null) {
      return GridScaffold(
        onBack: () => Navigator.maybePop(context),
        body: const SizedBox(),
      );
    }
    final words = lib.wordsFor(m.id).reversed.toList();
    final book = m.commonplace;

    final header = Row(
      children: [
        if (book) const Text('📒  ', style: TextStyle(fontSize: 20)),
        Expanded(
          child: Text(
            m.title,
            style: T.headlineMd.copyWith(fontSize: 22),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        GestureDetector(
          onTap: book
              ? null
              : () => setState(() => _showBubbles = !_showBubbles),
          child: CountPill(
            _showBubbles ? m.bubbles.length : words.length,
            light: true,
          ),
        ),
        if (book) _BookMenu(book: m),
      ],
    );

    final wordList = [
      if (words.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Text(
            book
                ? 'Empty so far. Search above — in Japanese or English — and '
                      'tap a result to add it.'
                : 'No words saved yet. Look one up below, or tap + while '
                      'reading.',
            style: T.bodyMd.copyWith(color: C.textDim),
          ),
        ),
      for (final w in words) WordRow(w.entry, onTap: () => _showWord(w)),
    ];

    final dictionary = [
      Text('Dictionary', style: T.headlineMd.copyWith(fontSize: 22)),
      const SizedBox(height: 10),
      TextField(
        controller: _search,
        textAlign: TextAlign.center,
        textInputAction: TextInputAction.search,
        style: T.bodyLg,
        decoration: InputDecoration(
          hintText: book ? '月曜日, Monday…' : 'kore, これ, this…',
          fillColor: Colors.transparent,
        ),
        onSubmitted: _lookup,
      ),
      const SizedBox(height: 10),
      if (_loading) const LinearProgressIndicator(minHeight: 2),
      if (_error != null)
        Text(_error!, style: T.bodyMd.copyWith(color: C.textDim)),
      for (final e in _results.take(12))
        WordRow(
          e,
          // Mint once it's in this book, so a set like the days of the
          // week shows how far along it is.
          color: lib.isSaved(m.id, e) ? C.mint : C.violet,
          onTap: () {
            final added = lib.saveWord(m.id, e);
            toast(
              context,
              added
                  ? 'Added ${e.word}.'
                  : '${e.word} is already in this ${book ? 'book' : 'deck'}.',
            );
          },
        ),
    ];

    return GridScaffold(
      onBack: () => Navigator.maybePop(context),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 24),
        children: book
            // A commonplace book is built from the dictionary, so the
            // search comes first and its words follow.
            ? [
                header,
                const SizedBox(height: 12),
                ...dictionary,
                const SizedBox(height: 20),
                Text(
                  'In this book',
                  style: T.headlineMd.copyWith(fontSize: 22),
                ),
                const SizedBox(height: 6),
                ...wordList,
              ]
            : [
                header,
                const SizedBox(height: 4),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: false, label: Text('Words')),
                    ButtonSegment(value: true, label: Text('Bubbles')),
                  ],
                  selected: {_showBubbles},
                  showSelectedIcon: false,
                  style: SegmentedButton.styleFrom(
                    selectedBackgroundColor: C.lime,
                    selectedForegroundColor: C.onLime,
                    foregroundColor: C.textDim,
                    side: const BorderSide(color: C.ghostBorder),
                  ),
                  onSelectionChanged: (s) =>
                      setState(() => _showBubbles = s.first),
                ),
                const SizedBox(height: 10),
                if (_showBubbles) ..._bubbleList(m) else ...wordList,
                const SizedBox(height: 20),
                ...dictionary,
              ],
      ),
    );
  }

  List<Widget> _bubbleList(Manga m) {
    final lib = AppScope.read(context);
    if (m.bubbles.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Text(
            'No bubbles yet. Read a page with OCR on, or long-press a page to place one.',
            style: T.bodyMd.copyWith(color: C.textDim),
          ),
        ),
      ];
    }
    final order = {
      for (var i = 0; i < m.chapters.length; i++) m.chapters[i].id: i,
    };
    final sorted = [...m.bubbles]
      ..sort((a, b) {
        final c = (order[a.chapterId] ?? 0).compareTo(order[b.chapterId] ?? 0);
        return c != 0 ? c : a.page.compareTo(b.page);
      });
    return [
      for (final b in sorted)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Material(
            color: C.surface,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                final ci = order[b.chapterId];
                if (ci == null) return;
                Navigator.of(context, rootNavigator: true).push(
                  MaterialPageRoute(
                    builder: (_) => ReaderScreen(
                      mangaId: m.id,
                      chapterIndex: ci,
                      initialPage: b.page,
                    ),
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${m.chapters[order[b.chapterId] ?? 0].title} · p${b.page + 1} · #${lib.bubbleNumber(m, b).toString().padLeft(2, '0')}',
                      style: T.monoSm,
                    ),
                    if (b.source.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(b.source, style: T.jp.copyWith(fontSize: 15)),
                    ],
                    const SizedBox(height: 2),
                    Text(
                      b.translation.isEmpty
                          ? 'not translated yet'
                          : b.translation,
                      style: T.bodyMd.copyWith(
                        color: b.translation.isEmpty ? C.inactive : C.lime,
                        fontStyle: b.translation.isEmpty
                            ? FontStyle.italic
                            : null,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
    ];
  }
}

/// Rename and delete, for a commonplace book.
class _BookMenu extends StatelessWidget {
  const _BookMenu({required this.book});

  final Manga book;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert_rounded, color: C.text),
      color: C.elevated,
      onSelected: (v) async {
        final lib = AppScope.read(context);
        if (v == 'rename') {
          final name = await promptText(
            context,
            title: 'Rename',
            initial: book.title,
          );
          if (name != null && name.trim().isNotEmpty) {
            book.title = name.trim();
            lib.changed();
          }
        } else if (v == 'delete') {
          final n = lib.wordsFor(book.id).length;
          final ok = await confirm(
            context,
            'Delete ${book.title}?',
            n == 0
                ? 'The book is empty.'
                : 'Its $n word${n == 1 ? '' : 's'} and their flash-card '
                      'progress are removed too.',
          );
          if (ok && context.mounted) {
            Navigator.pop(context);
            await lib.deleteManga(book);
          }
        }
      },
      itemBuilder: (_) => const [
        PopupMenuItem(value: 'rename', child: Text('Rename')),
        PopupMenuItem(
          value: 'delete',
          child: Text('Delete', style: TextStyle(color: C.danger)),
        ),
      ],
    );
  }
}
