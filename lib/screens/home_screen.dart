/// Library home: a carousel of covers with the focused manga's progress
/// under it, and how many of its words have stuck.
library;

import 'package:flutter/material.dart';

import '../models.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'study_screen.dart';
import 'import_screen.dart';
import 'manga_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _pages = PageController(viewportFraction: 0.56);
  int _focused = 0;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _openImport() =>
      Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => const ImportScreen()));

  @override
  Widget build(BuildContext context) {
    final lib = AppScope.library(context);
    final mangas = lib.shelf;

    if (mangas.isEmpty) {
      return GridScaffold(
        body: EmptyState(
          emoji: '📚',
          title: 'Your shelf is empty',
          body:
              'Import a manga — page images or a .cbz — then read it, '
              'OCR the bubbles, and turn the words into flash cards.',
          action: LimeButton(label: '+ import a manga', onPressed: _openImport),
        ),
      );
    }

    final focused = _focused < mangas.length ? mangas[_focused] : null;
    final width = MediaQuery.sizeOf(context).width;
    final coverH = width * 0.52 * 1.5;

    return GridScaffold(
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          const SizedBox(height: 8),
          SizedBox(
            height: coverH + 28,
            child: PageView.builder(
              controller: _pages,
              padEnds: false,
              itemCount: mangas.length + 1,
              onPageChanged: (i) => setState(() => _focused = i),
              itemBuilder: (context, i) {
                final isFocused = i == _focused;
                if (i == mangas.length) {
                  return _Slot(
                    height: coverH,
                    caption: 'Add manga',
                    child: _AddTile(onTap: _openImport),
                  );
                }
                final m = mangas[i];
                return _Slot(
                  height: coverH,
                  caption: isFocused ? null : '${m.chapters.length} Chapters',
                  child: GestureDetector(
                    onTap: () {
                      if (!isFocused) {
                        _pages.animateToPage(
                          i,
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOutCubic,
                        );
                        return;
                      }
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => MangaScreen(mangaId: m.id),
                        ),
                      );
                    },
                    child: Cover(m, radius: 6),
                  ),
                );
              },
            ),
          ),
          if (focused != null) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    focused.title,
                    style: T.headlineLg,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Chapter ${chaptersComplete(focused)} of ${focused.chapters.length} Completed',
                    style: T.bodyMd,
                  ),
                  const SizedBox(height: 12),
                  ProgressBar(
                    focused.pageCount == 0
                        ? 0
                        : pagesRead(focused) / focused.pageCount,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _LearningCard(manga: focused),
          ],
        ],
      ),
    );
  }
}

class _Slot extends StatelessWidget {
  const _Slot({required this.height, required this.child, this.caption});

  final double height;
  final Widget child;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: height, width: double.infinity, child: child),
          if (caption != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                caption!,
                style: T.bodyMd.copyWith(color: C.textDim, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }
}

class _AddTile extends StatelessWidget {
  const _AddTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: C.violet,
    borderRadius: BorderRadius.circular(6),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: const Center(
        child: Icon(Icons.add_rounded, size: 72, color: Colors.black87),
      ),
    ),
  );
}

class _LearningCard extends StatelessWidget {
  const _LearningCard({required this.manga});

  final Manga manga;

  @override
  Widget build(BuildContext context) {
    final lib = AppScope.library(context);
    final total = lib.wordsFor(manga.id).length;
    final learned = lib.learnedCount(manga.id);
    final pct = total == 0 ? 0 : (learned * 100 / total).round();

    return InkWell(
      onTap: total == 0 ? null : () => openFlashcards(context, manga.id),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: SizedBox(
          height: 140,
          child: Row(
            children: [
              SizedBox(width: 96, height: 140, child: Cover(manga, radius: 0)),
              const SizedBox(width: 24),
              Expanded(
                child: total == 0
                    ? Text(
                        'Open a page, switch OCR on and drag over a speech '
                        'bubble to start collecting words.',
                        style: T.bodyMd.copyWith(color: C.textDim),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            manga.title,
                            style: T.bodyMd,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '$learned/$total words',
                            style: T.bodyLg.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text('words learned', style: T.bodyMd),
                          Row(
                            children: [
                              Text(
                                '$pct%',
                                style: T.headlineXl.copyWith(height: 1.0),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                pct >= 50 ? '🎉' : '📖',
                                style: const TextStyle(fontSize: 40),
                              ),
                            ],
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
