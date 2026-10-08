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

  Future<void> _newBook(BuildContext context) async {
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
                  'Your own word list, from the dictionary',
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
