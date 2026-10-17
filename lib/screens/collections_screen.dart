/// The Words tab: every manga as a cover with how many words it has given
/// you, plus commonplace books — word lists of your own, with no pages —
/// and a tile to start a new one. Tap any of them for its words and the
/// dictionary.
library;

import 'package:flutter/material.dart';

import '../theme.dart';
import '../widgets/common.dart';
import 'words_screen.dart';

class CollectionsScreen extends StatelessWidget {
  const CollectionsScreen({super.key});

  /// A new book: an empty one of your own, or a JLPT level's words.
  Future<void> _newBook(BuildContext context) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.edit_note_rounded, color: C.lime),
                title: const Text('Empty commonplace book'),
                subtitle: const Text('Add words yourself from the dictionary'),
                onTap: () => Navigator.pop(context, ''),
              ),
              const Divider(color: C.ghostBorder),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('JLPT PACKS', style: T.monoSm),
                ),
              ),
              for (final (level, about) in _levels)
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: C.elevated,
                    child: Text(level, style: T.monoSm.copyWith(color: C.lime)),
                  ),
                  title: Text('JLPT $level'),
                  subtitle: Text(about),
                  onTap: () => Navigator.pop(context, level),
                ),
            ],
          ),
        ),
      ),
    );
    if (choice == null || !context.mounted) return;
    if (choice.isEmpty) return _emptyBook(context);
    await _pack(context, choice);
  }

  static const _levels = [
    ('N5', 'The basics — about 900 words'),
    ('N4', 'About 800 words'),
    ('N3', 'About 2,400 words'),
    ('N2', 'About 1,800 words'),
    ('N1', 'About 2,800 words'),
  ];

  Future<void> _pack(BuildContext context, String level) async {
    final lib = AppScope.read(context);
    final dictionary = AppScope.dictionaryOf(context);
    final entries = await dictionary.jlptWords(level);
    if (!context.mounted) return;
    if (entries.isEmpty) {
      toast(context, 'No $level words found in the dictionary.');
      return;
    }
    final before = lib.wordsFor('jlpt-$level').length;
    final book = lib.addJlptPack(level, entries);
    final added = lib.wordsFor(book.id).length - before;
    toast(
      context,
      added == 0
          ? 'JLPT $level is already complete.'
          : 'Added $added $level words. Pick some for focus to study them.',
    );
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => WordsScreen(mangaId: book.id)));
  }

  Future<void> _emptyBook(BuildContext context) async {
    final title = await promptText(
      context,
      title: 'New commonplace book',
      hint: 'Days of the week, food, words from a song…',
      action: 'Create',
    );
    if (title == null || !context.mounted) return;
    final name = title.trim().isEmpty ? 'Commonplace book' : title.trim();
    final book = AppScope.read(context).addCommonplaceBook(name);
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => WordsScreen(mangaId: book.id)));
  }

  @override
  Widget build(BuildContext context) {
    final lib = AppScope.library(context);
    final books = lib.recent;
    return GridScaffold(
      body: GridView.builder(
        padding: const EdgeInsets.fromLTRB(22, 8, 22, 24),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 0.66,
        ),
        itemCount: books.length + 1,
        itemBuilder: (context, i) {
          if (i == books.length) {
            return _NewBookTile(onTap: () => _newBook(context));
          }
          final m = books[i];
          return GestureDetector(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => WordsScreen(mangaId: m.id)),
            ),
            child: Cover(
              m,
              radius: 12,
              badge: CountPill(lib.wordsFor(m.id).length),
            ),
          );
        },
      ),
    );
  }
}

class _NewBookTile extends StatelessWidget {
  const _NewBookTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: C.surface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: const BorderSide(color: C.ghostBorder, width: 1.5),
    ),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        // Scales down rather than overflowing on a narrow phone or with a
        // large system font.
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: SizedBox(
            width: 130,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.add_rounded, size: 44, color: C.lime),
                const SizedBox(height: 8),
                Text(
                  'Commonplace book',
                  textAlign: TextAlign.center,
                  style: T.bodyLg.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  'Your own word list, or a JLPT pack',
                  textAlign: TextAlign.center,
                  style: T.bodyMd.copyWith(color: C.textDim, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
