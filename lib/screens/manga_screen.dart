/// One manga: cover, the last page read (tap to resume), and every chapter
/// with its reading state and how many bubbles have been placed in it.
library;

import 'package:flutter/material.dart';

import '../models.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'import_screen.dart';
import 'reader_screen.dart';
import 'words_screen.dart';

class MangaScreen extends StatelessWidget {
  const MangaScreen({super.key, required this.mangaId});

  final String mangaId;

  void _read(BuildContext context, Manga m, int chapter, int page) {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        builder: (_) => ReaderScreen(
          mangaId: m.id,
          chapterIndex: chapter,
          initialPage: page,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lib = AppScope.library(context);
    final m = lib.mangaById(mangaId);
    if (m == null) {
      return GridScaffold(
        onBack: () => Navigator.maybePop(context),
        body: const EmptyState(emoji: '🫥', title: 'This manga was removed'),
      );
    }
    final w = MediaQuery.sizeOf(context).width;
    final hasPages =
        m.chapters.isNotEmpty &&
        m
            .chapters[m.lastChapter.clamp(0, m.chapters.length - 1)]
            .pages
            .isNotEmpty;
    final lastChapter = m.chapters.isEmpty
        ? null
        : m.chapters[m.lastChapter.clamp(0, m.chapters.length - 1)];
    final lastPagePath = hasPages
        ? lastChapter!.pages[m.lastPage.clamp(0, lastChapter.pages.length - 1)]
        : null;
    final read = pagesRead(m);

    return GridScaffold(
      onBack: () => Navigator.maybePop(context),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          SizedBox(
            height: w * 0.5 * 1.5,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: w * 0.48, child: Cover(m, radius: 4)),
                const SizedBox(width: 10),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          m.title,
                          style: T.headlineMd.copyWith(fontSize: 22),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'Last Page Read',
                          style: T.bodyMd.copyWith(
                            fontSize: 11,
                            color: C.textDim,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: GestureDetector(
                            onTap: hasPages
                                ? () => _read(
                                    context,
                                    m,
                                    m.lastChapter,
                                    m.lastPage,
                                  )
                                : null,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  LibraryImage(
                                    lastPagePath,
                                    cacheWidth: 500,
                                    alignment: Alignment.topCenter,
                                  ),
                                  if (hasPages)
                                    const Positioned(
                                      right: 6,
                                      bottom: 6,
                                      child: CircleAvatar(
                                        radius: 16,
                                        backgroundColor: C.lime,
                                        child: Icon(
                                          Icons.play_arrow_rounded,
                                          color: C.onLime,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Page $read of ${m.pageCount} Read',
                          style: T.bodyMd.copyWith(fontSize: 12),
                        ),
                        const SizedBox(height: 6),
                        ProgressBar(
                          m.pageCount == 0 ? 0 : read / m.pageCount,
                          color: C.violet,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 20, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'All Chapters',
                    style: T.headlineMd.copyWith(fontSize: 22),
                  ),
                ),
                IconButton(
                  tooltip: 'Words from this manga',
                  icon: const Icon(Icons.translate_rounded, color: C.text),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => WordsScreen(mangaId: m.id),
                    ),
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert_rounded, color: C.text),
                  color: C.elevated,
                  onSelected: (v) async {
                    if (v == 'edit') {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ImportScreen(mangaId: m.id),
                        ),
                      );
                    } else if (v == 'delete') {
                      final ok = await confirm(
                        context,
                        'Delete ${m.title}?',
                        'Its pages, bubbles and saved words are removed from this device.',
                      );
                      if (ok && context.mounted) {
                        Navigator.pop(context);
                        await lib.deleteManga(m);
                      }
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: 'edit',
                      child: Text('Edit chapters & cover'),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Text('Delete', style: TextStyle(color: C.danger)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          for (var i = 0; i < m.chapters.length; i++)
            _ChapterTile(
              chapter: m.chapters[i],
              bubbles: lib.bubbleCount(m, m.chapters[i].id),
              onTap: () {
                final c = m.chapters[i];
                final status = statusOf(c);
                // Resume where this chapter was left; a finished one
                // starts over.
                final page = status == ChapterStatus.reading
                    ? (i == m.lastChapter ? m.lastPage : c.readUpTo)
                    : 0;
                _read(context, m, i, page);
              },
            ),
        ],
      ),
    );
  }
}

class _ChapterTile extends StatelessWidget {
  const _ChapterTile({
    required this.chapter,
    required this.bubbles,
    required this.onTap,
  });

  final Chapter chapter;
  final int bubbles;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
      child: Material(
        color: C.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: Color(0xFFDDDDDD), width: 1),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
            child: Row(
              children: [
                _StatusDot(statusOf(chapter)),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    chapter.title,
                    style: T.bodyMd,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                CountPill(bubbles),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Solid lime = complete, half-filled = in progress, hollow ring = unread.
class _StatusDot extends StatelessWidget {
  const _StatusDot(this.status);

  final ChapterStatus status;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 22,
    height: 22,
    child: CustomPaint(painter: _DotPainter(status)),
  );
}

class _DotPainter extends CustomPainter {
  _DotPainter(this.status);

  final ChapterStatus status;

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.width / 2;
    final c = Offset(r, r);
    final rect = Rect.fromCircle(center: c, radius: r);
    switch (status) {
      case ChapterStatus.complete:
        canvas.drawCircle(c, r, Paint()..color = C.lime);
      case ChapterStatus.reading:
        canvas.drawCircle(c, r, Paint()..color = Colors.white);
        canvas.drawArc(rect, 3.14159, 3.14159, true, Paint()..color = C.lime);
      case ChapterStatus.unread:
        canvas.drawCircle(
          c,
          r - 1,
          Paint()
            ..color = C.lime
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
    }
  }

  @override
  bool shouldRepaint(_DotPainter old) => old.status != status;
}
