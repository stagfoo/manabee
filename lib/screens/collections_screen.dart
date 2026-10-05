/// The Words tab: every manga as a cover with how many words it has given
/// you. Tap one for its word list and dictionary.
library;

import 'package:flutter/material.dart';

import '../widgets/common.dart';
import 'words_screen.dart';

class CollectionsScreen extends StatelessWidget {
  const CollectionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final lib = AppScope.library(context);
    final mangas = lib.recent;
    return GridScaffold(
      body: mangas.isEmpty
          ? const EmptyState(
              emoji: '💬',
              title: 'No words yet',
              body: 'Words you save while reading collect here, one deck per manga.',
            )
          : GridView.builder(
              padding: const EdgeInsets.fromLTRB(22, 8, 22, 24),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 0.66,
              ),
              itemCount: mangas.length,
              itemBuilder: (context, i) {
                final m = mangas[i];
                return GestureDetector(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => WordsScreen(mangaId: m.id),
                    ),
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
