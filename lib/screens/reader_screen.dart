/// The reader: pages, the bubbles placed on them, OCR, and the lookup
/// sheet.
///
/// Two modes, because the same finger gesture can't mean two things:
/// - **Reading** (OCR off): swipe turns pages, pinch zooms, long-press on
///   the page places a translation bubble there, long-press-drag on a
///   bubble moves it.
/// - **OCR**: paging and zoom are paused, and a drag draws a box around a
///   speech balloon to read it. SCAN finds every block on the page at
///   once, as outlines to tap.
///
/// Everything placed on a page is stored normalised to the image (see
/// core/geometry.dart), so it lands in the same spot at any zoom or size.
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/geometry.dart';
import '../core/segmenter.dart';
import '../models.dart';
import '../services/jisho.dart';
import '../services/ocr.dart';
import '../services/speech.dart';
import '../theme.dart';
import '../widgets/common.dart';

class ReaderScreen extends StatefulWidget {
  const ReaderScreen({
    super.key,
    required this.mangaId,
    required this.chapterIndex,
    this.initialPage = 0,
  });

  final String mangaId;
  final int chapterIndex;
  final int initialPage;

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  late int _chapterIndex;
  late PageController _pages;
  late int _page;
  bool _ocr = false;
  bool _zoomed = false;
  String? _busy;
  final Map<String, Future<Size>> _sizes = {};
  final Map<String, List<ScannedBlock>> _scanned = {};

  String? _activeBubbleId;
  final _query = TextEditingController();
  List<Entry> _results = const [];
  int _selected = 0;
  bool _looking = false;
  String? _lookupError;
  final _sheet = DraggableScrollableController();

  static const _sheetMin = 0.13;
  static const _sheetMid = 0.5;

  @override
  void initState() {
    super.initState();
    _chapterIndex = widget.chapterIndex;
    _page = widget.initialPage;
    _pages = PageController(initialPage: _page);
    WidgetsBinding.instance.addPostFrameCallback((_) => _markRead());
  }

  @override
  void dispose() {
    _pages.dispose();
    _query.dispose();
    _sheet.dispose();
    super.dispose();
  }

  Manga? get _manga => AppScope.read(context).mangaById(widget.mangaId);

  void _markRead() {
    final m = _manga;
    if (m == null || _chapterIndex >= m.chapters.length) return;
    final c = m.chapters[_chapterIndex];
    if (_page < c.pages.length) {
      AppScope.read(context).markRead(m, _chapterIndex, _page);
    }
  }

  Future<Size> _sizeOf(String absPath) =>
      _sizes[absPath] ??= _readSize(absPath);

  static Future<Size> _readSize(String path) async {
    final buffer = await ui.ImmutableBuffer.fromFilePath(path);
    final desc = await ui.ImageDescriptor.encoded(buffer);
    final size = Size(desc.width.toDouble(), desc.height.toDouble());
    desc.dispose();
    buffer.dispose();
    return size;
  }

  void _goToChapter(int index) {
    final old = _pages;
    setState(() {
      _chapterIndex = index;
      _page = 0;
      _activeBubbleId = null;
      _pages = PageController();
    });
    // The outgoing PageView still holds the old controller until this frame
    // unmounts it; disposing it any sooner throws.
    WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
    _markRead();
  }

  void _openSheet([double size = _sheetMid]) {
    if (!_sheet.isAttached) return;
    if (_sheet.size < size - 0.01) {
      _sheet.animateTo(
        size,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    }
  }

  Bubble? _activeBubble(Manga m) =>
      m.bubbles.where((b) => b.id == _activeBubbleId).firstOrNull;

  // ---- Lookup ----

  Future<void> _lookup(String q) async {
    final query = q.trim();
    if (query.isEmpty) return;
    _query.text = query;
    setState(() {
      _looking = true;
      _lookupError = null;
    });
    try {
      final results = await AppScope.jishoOf(context).lookup(query);
      if (!mounted || _query.text.trim() != query) return;
      setState(() {
        _results = results;
        _selected = 0;
        if (results.isEmpty) _lookupError = 'No dictionary match for "$query".';
      });
    } on LookupException catch (e) {
      if (mounted) setState(() => _lookupError = e.message);
    } finally {
      if (mounted) setState(() => _looking = false);
    }
  }

  void _toggleSaved(Manga m) {
    if (_results.isEmpty) {
      toast(context, 'Look a word up first.');
      return;
    }
    final lib = AppScope.read(context);
    final e = _results[_selected];
    if (lib.isSaved(m.id, e)) {
      lib.removeWord(Word.idFor(m.id, e));
      toast(context, 'Removed ${e.word} from your deck.');
    } else {
      final b = _activeBubble(m);
      lib.saveWord(m.id, e, context: b?.source ?? '', bubbleId: b?.id);
      HapticFeedback.lightImpact();
      toast(context, 'Added ${e.word} to your deck.');
    }
  }

  // ---- Bubbles ----

  void _selectBubble(Bubble b, {bool lookupFirst = false}) {
    setState(() => _activeBubbleId = b.id);
    if (lookupFirst) {
      final first = lookupCandidates(b.source).firstOrNull;
      if (first != null) _lookup(first);
    }
    _openSheet();
  }

  Future<void> _ocrRegion(Manga m, Chapter c, int page, Rect region) async {
    final lib = AppScope.read(context);
    setState(() => _busy = 'Reading bubble…');
    String text = '';
    try {
      text = await Ocr.instance.readRegion(lib.resolve(c.pages[page]), region);
    } catch (e) {
      if (mounted) toast(context, 'OCR failed: $e');
    } finally {
      if (mounted) setState(() => _busy = null);
    }
    if (!mounted) return;
    if (text.isEmpty) {
      final typed = await promptText(
        context,
        title: 'No text found',
        hint: 'Type the Japanese yourself',
        action: 'Add',
      );
      if (typed == null || typed.trim().isEmpty) return;
      text = typed.trim();
    }
    final b = Bubble(
      id: newId(),
      chapterId: c.id,
      page: page,
      region: region,
      // Just under the balloon, so the pill doesn't cover what it reads.
      position: Offset(
        region.center.dx,
        (region.bottom + 0.02).clamp(0.0, 0.98),
      ),
      source: text,
    );
    lib.addBubble(m, b);
    _selectBubble(b, lookupFirst: true);
  }

  void _adoptBlock(Manga m, Chapter c, int page, ScannedBlock block) {
    final key = c.pages[page];
    setState(() => _scanned[key]?.remove(block));
    final b = Bubble(
      id: newId(),
      chapterId: c.id,
      page: page,
      region: block.region,
      position: Offset(
        block.region.center.dx,
        (block.region.bottom + 0.02).clamp(0.0, 0.98),
      ),
      source: block.text,
    );
    AppScope.read(context).addBubble(m, b);
    _selectBubble(b, lookupFirst: true);
  }

  Future<void> _scanPage(Chapter c) async {
    final lib = AppScope.read(context);
    final rel = c.pages[_page];
    final abs = lib.resolve(rel);
    setState(() => _busy = 'Scanning page…');
    try {
      final size = await _sizeOf(abs);
      final blocks = await Ocr.instance.scanPage(abs, size);
      if (!mounted) return;
      setState(() => _scanned[rel] = blocks);
      toast(
        context,
        blocks.isEmpty
            ? 'No text found on this page.'
            : 'Found ${blocks.length} blocks — tap one to read it.',
      );
    } catch (e) {
      if (mounted) toast(context, 'Scan failed: $e');
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  Future<void> _placeBubble(
    Manga m,
    Chapter c,
    int page,
    Offset position,
  ) async {
    final translation = await promptText(
      context,
      title: 'Your translation',
      hint: 'What does this bubble say?',
      maxLines: 3,
      action: 'Place',
    );
    if (translation == null || translation.trim().isEmpty || !mounted) return;
    final b = Bubble(
      id: newId(),
      chapterId: c.id,
      page: page,
      position: position,
      translation: translation.trim(),
    );
    AppScope.read(context).addBubble(m, b);
    setState(() => _activeBubbleId = b.id);
  }

  Future<void> _editTranslation(Manga m, Chapter c, Bubble? b) async {
    if (b == null) {
      await _placeBubble(m, c, _page, const Offset(0.5, 0.5));
      return;
    }
    final t = await promptText(
      context,
      title: 'Your translation',
      initial: b.translation,
      maxLines: 3,
      hint: b.source.isEmpty ? 'What does this bubble say?' : b.source,
    );
    if (t == null) return;
    b.translation = t.trim();
    if (mounted) AppScope.read(context).changed();
  }

  Future<void> _editSource(Bubble b) async {
    final t = await promptText(
      context,
      title: 'Japanese text',
      initial: b.source,
      maxLines: 4,
      hint: 'Fix what OCR misread',
    );
    if (t == null) return;
    b.source = t.trim();
    if (mounted) AppScope.read(context).changed();
  }

  // ---- Build ----

  @override
  Widget build(BuildContext context) {
    final lib = AppScope.library(context);
    final m = lib.mangaById(widget.mangaId);
    if (m == null || m.chapters.isEmpty) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: EmptyState(emoji: '🫥', title: 'Nothing to read'),
      );
    }
    final chapterIndex = _chapterIndex.clamp(0, m.chapters.length - 1);
    final c = m.chapters[chapterIndex];
    final hasNext = chapterIndex + 1 < m.chapters.length;
    final active = _activeBubble(m);
    final onPage = _page < c.pages.length;

    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          Positioned.fill(
            child: PageView.builder(
              key: ValueKey(c.id),
              controller: _pages,
              reverse: lib.settings.rightToLeft,
              physics: _ocr || _zoomed
                  ? const NeverScrollableScrollPhysics()
                  : const PageScrollPhysics(),
              itemCount: c.pages.length + (hasNext ? 1 : 0),
              onPageChanged: (i) {
                setState(() {
                  _page = i;
                  _zoomed = false;
                  _activeBubbleId = null;
                });
                _markRead();
              },
              itemBuilder: (context, i) {
                if (i >= c.pages.length) {
                  return _ChapterEnd(
                    next: m.chapters[chapterIndex + 1],
                    onNext: () => _goToChapter(chapterIndex + 1),
                  );
                }
                final rel = c.pages[i];
                return _Page(
                  key: ValueKey(rel),
                  absPath: lib.resolve(rel),
                  sizeOf: _sizeOf,
                  ocr: _ocr,
                  bubbles: lib.bubblesOn(m, c.id, i),
                  scanned: _scanned[rel] ?? const [],
                  activeId: _activeBubbleId,
                  bottomInset: MediaQuery.sizeOf(context).height * _sheetMin,
                  onZoom: (z) {
                    if (z != _zoomed) setState(() => _zoomed = z);
                  },
                  onSelectRegion: (r) => _ocrRegion(m, c, i, r),
                  onTapBlock: (b) => _adoptBlock(m, c, i, b),
                  onTapBubble: (b) => _selectBubble(b),
                  onMoveBubble: (b, p) {
                    b.position = p;
                    lib.changed();
                  },
                  onLongPress: (p) => _placeBubble(m, c, i, p),
                );
              },
            ),
          ),
          _TopBar(
            title: m.title,
            page: onPage ? _page + 1 : c.pages.length,
            pageCount: c.pages.length,
            ocr: _ocr,
            onBack: () => Navigator.pop(context),
            onToggleOcr: () => setState(() {
              _ocr = !_ocr;
              if (_ocr) {
                toast(context, 'OCR on — drag a box over a speech bubble.');
              }
            }),
            onScan: _ocr && onPage ? () => _scanPage(c) : null,
          ),
          if (_busy != null)
            Positioned(
              top: MediaQuery.paddingOf(context).top + 64,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: C.lime.withValues(alpha: 0.6)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 10),
                      Text(_busy!, style: T.monoBold.copyWith(color: C.lime)),
                    ],
                  ),
                ),
              ),
            ),
          _sheetWidget(m, c, active),
        ],
      ),
    );
  }

  Widget _sheetWidget(Manga m, Chapter c, Bubble? active) {
    final lib = AppScope.library(context);
    final entry = _results.isEmpty
        ? null
        : _results[_selected.clamp(0, _results.length - 1)];
    final saved = entry != null && lib.isSaved(m.id, entry);

    return DraggableScrollableSheet(
      controller: _sheet,
      initialChildSize: _sheetMin,
      minChildSize: _sheetMin,
      maxChildSize: 0.88,
      snap: true,
      snapSizes: const [_sheetMid],
      builder: (context, scroll) => Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            decoration: const BoxDecoration(
              color: C.sheet,
              borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
              border: Border(top: BorderSide(color: Color(0xFF2A2A30))),
              boxShadow: [
                BoxShadow(
                  color: Color(0xD9000000),
                  blurRadius: 36,
                  offset: Offset(0, -12),
                ),
              ],
            ),
            child: ListView(
              controller: scroll,
              padding: EdgeInsets.fromLTRB(
                20,
                12,
                20,
                24 + MediaQuery.paddingOf(context).bottom,
              ),
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 6,
                    decoration: BoxDecoration(
                      color: const Color(0xFF555560),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                _SearchField(
                  controller: _query,
                  jlpt: entry?.jlpt,
                  onSubmit: _lookup,
                  onFocus: () => _openSheet(0.88),
                ),
                const SizedBox(height: 16),
                if (_looking) const LinearProgressIndicator(minHeight: 2),
                if (_lookupError != null && !_looking)
                  Text(
                    _lookupError!,
                    style: T.bodyMd.copyWith(color: C.textDim),
                  ),
                if (entry != null) ..._entryBlock(entry),
                if (_results.length > 1) _otherMatches(),
                if (active != null) ...[
                  const SizedBox(height: 16),
                  _contextCard(m, active),
                ],
                if (entry == null &&
                    active == null &&
                    !_looking &&
                    _lookupError == null)
                  Text(
                    _ocr
                        ? 'Drag a box over a speech bubble to read it, or tap SCAN to find every block on the page.'
                        : 'Switch OCR on to read a bubble. Long-press the page to place your own translation; long-press a bubble to move it.',
                    style: T.bodyMd.copyWith(color: C.textDim),
                  ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: GhostButton(
                        label: 'Copy Sentence',
                        onPressed: active == null || active.source.isEmpty
                            ? null
                            : () {
                                Clipboard.setData(
                                  ClipboardData(text: active.source),
                                );
                                toast(context, 'Copied.');
                              },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: LimeButton(
                        label: active == null
                            ? 'Add translation'
                            : 'Translate bubble',
                        onPressed: () => _editTranslation(m, c, active),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Positioned(
            right: 16,
            top: -28,
            child: GestureDetector(
              onTap: () => _toggleSaved(m),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: saved ? C.mint : C.lime,
                  boxShadow: [
                    BoxShadow(
                      color: (saved ? C.mint : C.lime).withValues(alpha: 0.45),
                      blurRadius: 16,
                    ),
                  ],
                ),
                child: Icon(
                  saved ? Icons.check_rounded : Icons.add_rounded,
                  color: Colors.black,
                  size: 32,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _entryBlock(Entry e) => [
    Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.end,
            spacing: 8,
            children: [
              Text(
                e.word,
                style: T.jp.copyWith(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  height: 1.2,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '[${e.reading} · ${e.romaji}]',
                  style: T.monoBold.copyWith(
                    color: C.textDim,
                    fontWeight: FontWeight.w400,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
        IconButton.outlined(
          style: IconButton.styleFrom(
            side: const BorderSide(color: C.ghostBorder),
            backgroundColor: C.surface,
          ),
          onPressed: () async {
            final problem = await Speech.instance.say(
              e.reading.isEmpty ? e.word : e.reading,
            );
            if (problem != null && mounted) toast(context, problem);
          },
          icon: const Icon(Icons.volume_up_outlined, color: C.text),
        ),
      ],
    ),
    const SizedBox(height: 4),
    Text(
      e.allMeanings,
      style: T.bodyMd.copyWith(color: const Color(0xFFD4D4DC)),
    ),
  ];

  Widget _otherMatches() => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: SizedBox(
      height: 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _results.length.clamp(0, 8),
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (context, i) {
          final e = _results[i];
          final on = i == _selected;
          return ChoiceChip(
            label: Text(
              e.word,
              style: T.jp.copyWith(
                fontSize: 13,
                color: on ? C.onLime : C.text,
                height: 1.1,
              ),
            ),
            selected: on,
            showCheckmark: false,
            selectedColor: C.lime,
            backgroundColor: C.surface,
            side: const BorderSide(color: C.border),
            shape: const StadiumBorder(),
            onSelected: (_) => setState(() => _selected = i),
          );
        },
      ),
    ),
  );

  Widget _contextCard(Manga m, Bubble b) {
    final lib = AppScope.library(context);
    final n = lib.bubbleNumber(m, b);
    final candidates = lookupCandidates(b.source);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 6, 12),
      decoration: BoxDecoration(
        color: C.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: C.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('PANEL CONTEXT', style: T.monoSm),
              const Spacer(),
              Text(
                'Bubble #${n.toString().padLeft(2, '0')}',
                style: T.monoSm.copyWith(color: C.lime),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: 'Delete bubble',
                onPressed: () async {
                  final ok = await confirm(
                    context,
                    'Delete this bubble?',
                    'Its text and your translation are removed. Saved words stay.',
                  );
                  if (ok) {
                    lib.removeBubble(m, b);
                    setState(() => _activeBubbleId = null);
                  }
                },
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  size: 18,
                  color: C.inactive,
                ),
              ),
            ],
          ),
          if (b.source.isNotEmpty || b.region != null)
            InkWell(
              onTap: () => _editSource(b),
              child: Padding(
                padding: const EdgeInsets.only(right: 8, bottom: 4),
                child: Text(
                  b.source.isEmpty
                      ? 'Tap to type the Japanese'
                      : '「${b.source}」',
                  style: T.jp.copyWith(
                    fontSize: 15,
                    color: b.source.isEmpty ? C.inactive : C.text,
                  ),
                ),
              ),
            ),
          if (b.translation.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 8, bottom: 6),
              child: Text(
                '(${b.translation})',
                style: T.bodyMd.copyWith(color: C.textDim),
              ),
            ),
          if (candidates.isNotEmpty)
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final w in candidates)
                  ActionChip(
                    label: Text(
                      w,
                      style: T.jp.copyWith(fontSize: 14, height: 1.1),
                    ),
                    backgroundColor: Colors.black,
                    side: BorderSide(
                      color: _query.text == w ? C.lime : C.ghostBorder,
                    ),
                    shape: const StadiumBorder(),
                    onPressed: () => _lookup(w),
                  ),
              ],
            ),
          if (b.source.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Tap the text to fix OCR mistakes, a chip to look it up.',
                style: T.bodyMd.copyWith(color: C.inactive, fontSize: 11),
              ),
            ),
        ],
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.onSubmit,
    required this.onFocus,
    this.jlpt,
  });

  final TextEditingController controller;
  final ValueChanged<String> onSubmit;
  final VoidCallback onFocus;
  final String? jlpt;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onSubmitted: onSubmit,
      onTap: onFocus,
      textInputAction: TextInputAction.search,
      style: T.monoBold.copyWith(fontSize: 16),
      decoration: InputDecoration(
        hintText: 'look up a word',
        prefixIcon: const Icon(Icons.search_rounded, color: C.inactive),
        suffixIcon: jlpt == null
            ? null
            : Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Center(
                  widthFactor: 1,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: C.lime.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: C.lime.withValues(alpha: 0.35)),
                    ),
                    child: Text(
                      'JLPT $jlpt',
                      style: T.monoSm.copyWith(color: C.lime, fontSize: 11),
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.title,
    required this.page,
    required this.pageCount,
    required this.ocr,
    required this.onBack,
    required this.onToggleOcr,
    this.onScan,
  });

  final String title;
  final int page;
  final int pageCount;
  final bool ocr;
  final VoidCallback onBack;
  final VoidCallback onToggleOcr;
  final VoidCallback? onScan;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: IgnorePointer(
        ignoring: false,
        child: Container(
          padding: EdgeInsets.fromLTRB(
            14,
            MediaQuery.paddingOf(context).top + 8,
            14,
            16,
          ),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xE6000000), Color(0x80000000), Color(0x00000000)],
            ),
          ),
          child: Row(
            children: [
              _Round(icon: Icons.chevron_left_rounded, onTap: onBack),
              const SizedBox(width: 8),
              Expanded(
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xB3000000),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: const Color(0x1AFFFFFF)),
                    ),
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(text: '$title · '),
                          TextSpan(
                            text: '$page / $pageCount',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              color: C.text,
                            ),
                          ),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: T.bodyMd.copyWith(
                        fontSize: 12,
                        color: const Color(0xFFD4D4D4),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (onScan != null) ...[
                _Pill(label: 'SCAN', on: false, onTap: onScan!),
                const SizedBox(width: 6),
              ],
              _Pill(
                label: ocr ? 'OCR ON' : 'OCR OFF',
                on: ocr,
                onTap: onToggleOcr,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Round extends StatelessWidget {
  const _Round({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: const Color(0x99000000),
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0x1AFFFFFF)),
      ),
      child: Icon(icon, color: C.text),
    ),
  );
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.on, required this.onTap});

  final String label;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: on ? C.lime.withValues(alpha: 0.15) : const Color(0xB3000000),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: on ? C.lime.withValues(alpha: 0.5) : const Color(0x33FFFFFF),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (on) ...[
            Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                color: C.lime,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: T.monoSm.copyWith(
              color: on ? C.lime : C.textDim,
              fontSize: 11,
            ),
          ),
        ],
      ),
    ),
  );
}

class _ChapterEnd extends StatelessWidget {
  const _ChapterEnd({required this.next, required this.onNext});

  final Chapter next;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: const GridPainter(),
    child: EmptyState(
      emoji: '🎉',
      title: 'Chapter complete',
      body: 'Up next: ${next.title}',
      action: LimeButton(
        label: 'Next chapter',
        icon: Icons.arrow_forward_rounded,
        onPressed: onNext,
      ),
    ),
  );
}

/// One page: the image fitted to the screen with its bubbles and OCR
/// regions laid over it, all inside one InteractiveViewer so they zoom
/// together.
class _Page extends StatefulWidget {
  const _Page({
    super.key,
    required this.absPath,
    required this.sizeOf,
    required this.ocr,
    required this.bubbles,
    required this.scanned,
    required this.activeId,
    required this.bottomInset,
    required this.onZoom,
    required this.onSelectRegion,
    required this.onTapBlock,
    required this.onTapBubble,
    required this.onMoveBubble,
    required this.onLongPress,
  });

  final String absPath;
  final Future<Size> Function(String) sizeOf;
  final bool ocr;
  final List<Bubble> bubbles;
  final List<ScannedBlock> scanned;
  final String? activeId;
  final double bottomInset;
  final ValueChanged<bool> onZoom;
  final ValueChanged<Rect> onSelectRegion;
  final ValueChanged<ScannedBlock> onTapBlock;
  final ValueChanged<Bubble> onTapBubble;
  final void Function(Bubble, Offset) onMoveBubble;
  final ValueChanged<Offset> onLongPress;

  @override
  State<_Page> createState() => _PageState();
}

class _PageState extends State<_Page> {
  final _transform = TransformationController();
  Size? _imageSize;
  Offset? _dragStart;
  Offset? _dragNow;
  Offset? _moveOrigin;

  @override
  void initState() {
    super.initState();
    widget
        .sizeOf(widget.absPath)
        .then(
          (s) {
            if (mounted) setState(() => _imageSize = s);
          },
          onError: (_) {
            if (mounted) setState(() => _imageSize = Size.zero);
          },
        );
    _transform.addListener(() {
      widget.onZoom(_transform.value.getMaxScaleOnAxis() > 1.01);
    });
  }

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = _imageSize;
    if (size == null) return const Center(child: CircularProgressIndicator());
    return LayoutBuilder(
      builder: (context, box) {
        // The page fits above the collapsed sheet, below the status bar.
        final top = MediaQuery.paddingOf(context).top + 52;
        final area = Size(
          box.maxWidth,
          box.maxHeight - top - widget.bottomInset,
        );
        final fitted = size.isEmpty
            ? Rect.fromLTWH(0, 0, area.width, area.height)
            : containRect(size, area);
        final imageRect = fitted.shift(Offset(0, top));

        final content = SizedBox(
          width: box.maxWidth,
          height: box.maxHeight,
          child: Stack(
            children: [
              Positioned.fromRect(
                rect: imageRect,
                child: Image.file(
                  File(widget.absPath),
                  fit: BoxFit.fill,
                  filterQuality: FilterQuality.medium,
                  gaplessPlayback: true,
                  errorBuilder: (_, _, _) => const Center(
                    child: Icon(
                      Icons.broken_image_outlined,
                      color: C.inactive,
                      size: 48,
                    ),
                  ),
                ),
              ),
              // Reading mode: long-press empty page to place a bubble.
              // OCR mode: drag to select a region.
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onLongPressStart: widget.ocr
                      ? null
                      : (d) {
                          final n = toNormalized(d.localPosition, imageRect);
                          if (n != null) widget.onLongPress(n);
                        },
                  onPanStart: widget.ocr
                      ? (d) => setState(() {
                          _dragStart = d.localPosition;
                          _dragNow = d.localPosition;
                        })
                      : null,
                  onPanUpdate: widget.ocr
                      ? (d) => setState(() => _dragNow = d.localPosition)
                      : null,
                  onPanEnd: widget.ocr
                      ? (_) {
                          final a = _dragStart;
                          final b = _dragNow;
                          setState(() {
                            _dragStart = null;
                            _dragNow = null;
                          });
                          if (a == null || b == null) return;
                          final r = normalizedSelection(a, b, imageRect);
                          if (isUsableSelection(r)) widget.onSelectRegion(r);
                        }
                      : null,
                ),
              ),
              if (widget.ocr)
                for (final b in widget.bubbles)
                  if (b.region != null)
                    Positioned.fromRect(
                      rect: denormalizeRect(b.region!, imageRect),
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: C.lime.withValues(alpha: 0.7),
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                    ),
              if (widget.ocr)
                for (final s in widget.scanned)
                  Positioned.fromRect(
                    rect: denormalizeRect(s.region, imageRect).inflate(3),
                    child: GestureDetector(
                      onTap: () => widget.onTapBlock(s),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: C.mint.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: C.mint, width: 1.5),
                        ),
                      ),
                    ),
                  ),
              if (_dragStart != null && _dragNow != null)
                Positioned.fromRect(
                  rect: Rect.fromPoints(_dragStart!, _dragNow!),
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: C.lime.withValues(alpha: 0.12),
                        border: Border.all(color: C.lime, width: 2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
              for (final b in widget.bubbles) _positionedPill(b, imageRect),
            ],
          ),
        );

        // In OCR mode the page is frozen at whatever zoom it had — zoom in
        // first to box a small balloon. A plain Transform rather than a
        // disabled InteractiveViewer: the viewer's scale recogniser would
        // still compete with the selection drag and sometimes win.
        if (widget.ocr) {
          return ClipRect(
            child: Transform(transform: _transform.value, child: content),
          );
        }
        return InteractiveViewer(
          transformationController: _transform,
          minScale: 1,
          maxScale: 5,
          child: content,
        );
      },
    );
  }

  Widget _positionedPill(Bubble b, Rect imageRect) {
    final p = fromNormalized(b.position, imageRect);
    final active = b.id == widget.activeId;
    final label = b.translation.isNotEmpty
        ? b.translation
        : (b.source.isNotEmpty ? b.source : '…');
    return Positioned(
      left: p.dx,
      top: p.dy,
      child: FractionalTranslation(
        translation: const Offset(-0.5, -0.5),
        child: GestureDetector(
          onTap: () => widget.onTapBubble(b),
          onLongPressStart: (_) {
            _moveOrigin = b.position;
            HapticFeedback.selectionClick();
          },
          onLongPressMoveUpdate: (d) {
            final o = _moveOrigin;
            if (o == null || imageRect.isEmpty) return;
            final moved = Offset(
              (o.dx + d.localOffsetFromOrigin.dx / imageRect.width).clamp(
                0.0,
                1.0,
              ),
              (o.dy + d.localOffsetFromOrigin.dy / imageRect.height).clamp(
                0.0,
                1.0,
              ),
            );
            widget.onMoveBubble(b, moved);
          },
          onLongPressEnd: (_) => _moveOrigin = null,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: imageRect.width * 0.6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xF2000000),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: active
                      ? C.lime.withValues(alpha: 0.85)
                      : const Color(0xCC404040),
                ),
                boxShadow: active
                    ? [
                        BoxShadow(
                          color: C.lime.withValues(alpha: 0.35),
                          blurRadius: 12,
                        ),
                      ]
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: active ? C.lime : C.inactive,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: T.monoBold.copyWith(
                        fontSize: 11,
                        fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                        letterSpacing: 0,
                        color: active ? C.lime : const Color(0xFFE5E5E5),
                        fontStyle: b.translation.isEmpty
                            ? FontStyle.italic
                            : null,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
