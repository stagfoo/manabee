/// The diary: write a few lines in Japanese, then check them.
///
/// Checking is offline (core/diary_check.dart): it shows the entry split
/// into words with particles coloured, marks what the dictionary doesn't
/// know (usually a typo), doubled particles, and polite and plain style
/// mixed in one entry. Any word can be tapped to look it up and saved to
/// the "Diary words" commonplace book, to study like any other deck.
library;

import 'package:flutter/material.dart';

import '../core/diary_check.dart';
import '../core/scan.dart';
import '../models.dart';
import '../services/store.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/entry_detail.dart';

const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _youbi = ['月', '火', '水', '木', '金', '土', '日'];

/// "Thu 9 Oct 2026 · 10月9日（木）" — the date in both, a small daily
/// reading exercise of its own.
String diaryDate(DateTime d) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${_weekdays[d.weekday - 1]} ${d.day} ${months[d.month - 1]} ${d.year}'
      ' · ${d.month}月${d.day}日（${_youbi[d.weekday - 1]}）';
}

class DiaryScreen extends StatelessWidget {
  const DiaryScreen({super.key});

  void _open(BuildContext context, DiaryEntry e) => Navigator.of(context)
      .push(MaterialPageRoute(builder: (_) => DiaryEntryScreen(entryId: e.id)));

  @override
  Widget build(BuildContext context) {
    final lib = AppScope.library(context);
    final entries = lib.diary.reversed.toList();
    return GridScaffold(
      onBack: () => Navigator.maybePop(context),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          Text('Diary', style: T.headlineMd.copyWith(fontSize: 22)),
          const SizedBox(height: 12),
          LimeButton(
            label: 'New entry',
            icon: Icons.edit_rounded,
            onPressed: () => _open(context, lib.newDiaryEntry()),
          ),
          const SizedBox(height: 16),
          if (entries.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 24),
              child: Text(
                'Write a few lines in Japanese — what you did today. Check '
                'it for typos and mixed styles, and tap any word to look '
                'it up.',
                textAlign: TextAlign.center,
                style: T.bodyMd.copyWith(color: C.textDim),
              ),
            ),
          for (final e in entries)
            Card(
              color: C.surface,
              elevation: 0,
              margin: const EdgeInsets.only(bottom: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: C.border),
              ),
              child: ListTile(
                onTap: () => _open(context, e),
                onLongPress: () async {
                  final ok = await confirm(
                    context,
                    'Delete this entry?',
                    diaryDate(e.written),
                  );
                  if (ok) lib.deleteDiaryEntry(e);
                },
                title: Text(diaryDate(e.written), style: T.monoSm),
                subtitle: Text(
                  e.text.trim().isEmpty
                      ? '(empty)'
                      : e.text.trim().split('\n').first,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: T.jp.copyWith(
                    fontSize: 16,
                    color: e.text.trim().isEmpty ? C.inactive : C.text,
                  ),
                ),
                trailing: Text(
                  '${e.text.trim().runes.length}字',
                  style: T.monoSm,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class DiaryEntryScreen extends StatefulWidget {
  const DiaryEntryScreen({super.key, required this.entryId});

  final String entryId;

  @override
  State<DiaryEntryScreen> createState() => _DiaryEntryScreenState();
}

class _DiaryEntryScreenState extends State<DiaryEntryScreen> {
  late final DiaryEntry _entry = AppScope.read(context).diary
      .firstWhere((d) => d.id == widget.entryId);
  late final TextEditingController _text = TextEditingController(
    text: _entry.text,
  );

  bool _checking = false;
  bool _busy = false;
  List<WordSpan> _words = const [];
  List<Finding> _findings = const [];

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _changed(String v) {
    _entry
      ..text = v
      ..updated = DateTime.now();
    AppScope.read(context).changed();
  }

  Future<void> _check() async {
    final dictionary = AppScope.dictionaryOf(context);
    setState(() => _busy = true);
    final text = _text.text;
    final words = await segmentSentence(text, dictionary.lookup);
    final findings = await checkJapanese(text, dictionary.lookup);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _checking = true;
      _words = words;
      _findings = findings;
    });
  }

  Future<void> _lookUp(int i) async {
    final text = _text.text;
    final dictionary = AppScope.dictionaryOf(context);
    final r = await scanWord(text, i, dictionary.lookup);
    if (!mounted) return;
    if (r == null || r.entries.isEmpty) {
      toast(context, 'No dictionary word starts at 「${text[i]}」.');
      return;
    }
    final e = r.entries.first;
    final surface = r.surfaceOf(text);
    final sentence =
        sentences(text)
            .where((s) => s.$1 <= i && i < s.$2)
            .map((s) => text.substring(s.$1, s.$2).trim())
            .firstOrNull ??
        '';
    _wordSheet(
      e,
      sentence: sentence,
      surface: r.form == null ? '' : surface,
      form: r.form?.label ?? '',
      written: r.form == null ? '' : 'Written: $surface  ·  ${r.form!.label}',
    );
  }

  /// A word's sheet: the entry, and what to do with it — add it to a book
  /// and study it, or, when it's saved already, study that card; and for
  /// a word looked up while writing, put it in the entry.
  void _wordSheet(
    Entry e, {
    String sentence = '',
    String surface = '',
    String form = '',
    String written = '',
    bool insertable = false,
  }) {
    final lib = AppScope.read(context);
    var bookId = kDiaryBookId;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheet) => StatefulBuilder(
        builder: (sheet, setSheet) {
          final saved = lib.savedWord(e);
          final books = [
            if (!lib.mangas.any((m) => m.id == kDiaryBookId))
              (kDiaryBookId, 'Diary words'),
            for (final m in lib.recent) (m.id, m.title),
          ];
          void add({required bool study}) {
            final book = bookId == kDiaryBookId
                ? lib.diaryWordBook()
                : lib.mangaById(bookId)!;
            lib.saveWord(
              book.id,
              e,
              context: sentence,
              surface: surface,
              form: form,
            );
            final w = lib.savedWord(e);
            if (study && w != null) lib.addFocus([w.id]);
            Navigator.pop(sheet);
            toast(
              context,
              study
                  ? 'Added ${e.word} to ${book.title} and your focus words.'
                  : 'Added ${e.word} to ${book.title}.',
            );
          }

          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (written.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        written,
                        style: T.monoBold.copyWith(
                          color: C.textDim,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  EntryDetail(e, context_: sentence, surface: surface),
                  const SizedBox(height: 16),
                  if (insertable) ...[
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(sheet);
                        _insert(e.word);
                      },
                      icon: const Icon(Icons.text_increase_rounded),
                      label: Text('Insert「${e.word}」into the entry'),
                    ),
                    const SizedBox(height: 10),
                  ],
                  if (saved != null) ...[
                    Text(
                      'Saved in '
                      '${lib.mangaById(saved.mangaId)?.title ?? 'a book'}'
                      '${saved.focus ? ' · in your focus words' : ''}',
                      style: T.bodyMd.copyWith(color: C.textDim),
                    ),
                    const SizedBox(height: 8),
                    LimeButton(
                      label: saved.focus ? 'Studying it' : 'Study it',
                      icon: saved.focus
                          ? Icons.check_rounded
                          : Icons.center_focus_strong_rounded,
                      onPressed: saved.focus
                          ? null
                          : () {
                              lib.addFocus([saved.id]);
                              Navigator.pop(sheet);
                              toast(
                                context,
                                '${e.word} is in your focus words.',
                              );
                            },
                    ),
                  ] else ...[
                    DropdownButtonFormField<String>(
                      initialValue: bookId,
                      decoration: const InputDecoration(labelText: 'Book'),
                      dropdownColor: C.elevated,
                      items: [
                        for (final (id, title) in books)
                          DropdownMenuItem(value: id, child: Text(title)),
                      ],
                      onChanged: (v) => setSheet(() => bookId = v ?? bookId),
                    ),
                    const SizedBox(height: 12),
                    LimeButton(
                      label: 'Add & study',
                      icon: Icons.center_focus_strong_rounded,
                      onPressed: () => add(study: true),
                    ),
                    TextButton(
                      onPressed: () => add(study: false),
                      child: const Text('Add only'),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// Writes [word] into the entry at the cursor (or the end).
  void _insert(String word) {
    final value = _text.value;
    final sel = value.selection;
    final at = sel.isValid ? sel.start : value.text.length;
    final end = sel.isValid ? sel.end : value.text.length;
    final text = value.text.replaceRange(at, end, word);
    _text.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: at + word.length),
    );
    _changed(text);
    if (_checking) _check();
  }

  /// Look up a word by English or Japanese — for a word you want to write
  /// but don't know yet.
  Future<void> _search() async {
    final dictionary = AppScope.dictionaryOf(context);
    final query = TextEditingController();
    List<Entry> results = const [];
    String? problem;
    var loading = false;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheet) => StatefulBuilder(
        builder: (sheet, setSheet) {
          Future<void> run(String q) async {
            if (q.trim().isEmpty) return;
            setSheet(() {
              loading = true;
              problem = null;
            });
            try {
              final found = await dictionary.lookup(q.trim());
              setSheet(() {
                results = found;
                problem = found.isEmpty ? 'Nothing found for "$q".' : null;
              });
            } on Exception catch (_) {
              setSheet(
                () => problem =
                    'Couldn\'t search — English goes to jisho.org, so it '
                    'needs the internet. Japanese works offline.',
              );
            } finally {
              setSheet(() => loading = false);
            }
          }

          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(sheet).viewInsets.bottom,
            ),
            child: SafeArea(
              child: SizedBox(
                height: MediaQuery.of(sheet).size.height * 0.7,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      child: TextField(
                        controller: query,
                        autofocus: true,
                        textInputAction: TextInputAction.search,
                        style: T.bodyLg,
                        decoration: const InputDecoration(
                          hintText: 'English or Japanese: tired, つかれる…',
                          prefixIcon: Icon(Icons.search_rounded),
                        ),
                        onSubmitted: run,
                      ),
                    ),
                    if (loading) const LinearProgressIndicator(minHeight: 2),
                    if (problem != null)
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          problem!,
                          style: T.bodyMd.copyWith(color: C.textDim),
                        ),
                      ),
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        children: [
                          for (final e in results.take(12))
                            WordRow(
                              e,
                              onTap: () {
                                Navigator.pop(sheet);
                                _wordSheet(e, insertable: true);
                              },
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
    query.dispose();
  }

  /// Every word written in the entry — particles aside — into the focus
  /// set: saved to Diary words if new, the existing card if not.
  Future<void> _studyEntryWords() async {
    final lib = AppScope.read(context);
    final dictionary = AppScope.dictionaryOf(context);
    final text = _text.text;
    setState(() => _busy = true);
    final found = <String, (Entry, String, String)>{};
    for (final w in _words) {
      if (w.particle || w.corrected != null) continue;
      final r = await scanWord(text, w.start, dictionary.lookup);
      final e = r?.entries.firstOrNull;
      if (r == null || e == null || r.end != w.end) continue;
      final surface = r.surfaceOf(text);
      found.putIfAbsent(
        '${e.word}|${e.reading}',
        () => (e, r.form == null ? '' : surface, r.form?.label ?? ''),
      );
    }
    if (!mounted) return;
    setState(() => _busy = false);
    if (found.isEmpty) {
      toast(context, 'No dictionary words found in this entry.');
      return;
    }
    final entries = found.values.toList();
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text('Study ${entries.length} words?'),
        content: Text(
          '${entries.map((x) => x.$1.word).join('、')}\n\n'
          'New ones are saved to Diary words; all go into your focus '
          'words, for flash cards, listening and shadowing.',
          style: T.bodyMd,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text('Study them'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final book = lib.diaryWordBook();
    final ids = <String>[];
    for (final (e, surface, form) in entries) {
      var w = lib.savedWord(e);
      if (w == null) {
        final sentence =
            sentences(text)
                .map((s) => text.substring(s.$1, s.$2).trim())
                .where((s) => s.contains(surface.isEmpty ? e.word : surface))
                .firstOrNull ??
            '';
        lib.saveWord(
          book.id,
          e,
          context: sentence,
          surface: surface,
          form: form,
        );
        w = lib.savedWord(e);
      }
      if (w != null) ids.add(w.id);
    }
    lib.addFocus(ids);
    toast(context, '${ids.length} words are in your focus words.');
  }

  @override
  Widget build(BuildContext context) {
    return GridScaffold(
      onBack: () => Navigator.maybePop(context),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(diaryDate(_entry.written), style: T.monoSm),
                ),
                TextButton.icon(
                  onPressed: _search,
                  icon: const Icon(Icons.search_rounded, size: 18),
                  label: const Text('Look up'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(
                  value: false,
                  label: Text('Write'),
                  icon: Icon(Icons.edit_rounded),
                ),
                ButtonSegment(
                  value: true,
                  label: Text('Check'),
                  icon: Icon(Icons.spellcheck_rounded),
                ),
              ],
              selected: {_checking},
              showSelectedIcon: false,
              style: SegmentedButton.styleFrom(
                selectedBackgroundColor: C.lime,
                selectedForegroundColor: C.onLime,
                foregroundColor: C.textDim,
                side: const BorderSide(color: C.ghostBorder),
              ),
              onSelectionChanged: (s) {
                if (s.first) {
                  _check();
                } else {
                  setState(() => _checking = false);
                }
              },
            ),
            const SizedBox(height: 12),
            if (_busy) const LinearProgressIndicator(minHeight: 2),
            Expanded(child: _checking ? _checked() : _editor()),
          ],
        ),
      ),
    );
  }

  Widget _editor() => TextField(
    controller: _text,
    onChanged: _changed,
    maxLines: null,
    expands: true,
    textAlignVertical: TextAlignVertical.top,
    keyboardType: TextInputType.multiline,
    style: T.jp.copyWith(fontSize: 19, height: 1.8),
    decoration: InputDecoration(
      hintText: '今日は…',
      fillColor: C.surface,
      contentPadding: const EdgeInsets.all(16),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: C.ghostBorder, width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: C.lime, width: 1.5),
      ),
    ),
  );

  Widget _checked() {
    final text = _text.text;
    if (text.trim().isEmpty) {
      return Center(
        child: Text(
          'Nothing written yet.',
          style: T.bodyMd.copyWith(color: C.textDim),
        ),
      );
    }
    return ListView(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: C.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: C.border),
          ),
          child: _CheckedText(
            text: text,
            words: _words,
            findings: _findings,
            onTap: _lookUp,
          ),
        ),
        const SizedBox(height: 14),
        if (_findings.isEmpty)
          Row(
            children: [
              const Icon(Icons.check_circle_outline_rounded, color: C.mint),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Nothing caught: every word is in the dictionary, no '
                  'doubled particles, one style throughout.',
                  style: T.bodyMd.copyWith(color: C.textDim),
                ),
              ),
            ],
          ),
        for (final f in _findings)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(_icon(f.kind), color: _colour(f.kind), size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text(f.message, style: T.bodyMd)),
              ],
            ),
          ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _busy ? null : _studyEntryWords,
          icon: const Icon(Icons.center_focus_strong_rounded),
          label: const Text('Study the words in this entry'),
        ),
        const SizedBox(height: 8),
        Text(
          'Tap any word to look it up. Purple are particles; red is a word '
          'the dictionary doesn\'t know, amber a doubled particle, blue a '
          'sentence in a different style. Checks are offline and catch '
          'mistakes, not unnatural phrasing.',
          style: T.bodyMd.copyWith(color: C.inactive, fontSize: 11),
        ),
      ],
    );
  }

  static IconData _icon(FindingKind k) => switch (k) {
    FindingKind.notAWord => Icons.help_outline_rounded,
    FindingKind.doubledParticle => Icons.repeat_rounded,
    FindingKind.mixedStyle => Icons.swap_horiz_rounded,
  };

  static Color _colour(FindingKind k) => switch (k) {
    FindingKind.notAWord => C.danger,
    FindingKind.doubledParticle => const Color(0xFFFFB74D),
    FindingKind.mixedStyle => const Color(0xFF64B5F6),
  };
}

/// The entry as words: spaced apart, particles purple, findings tinted,
/// each character tappable to look up the word starting there.
class _CheckedText extends StatelessWidget {
  const _CheckedText({
    required this.text,
    required this.words,
    required this.findings,
    required this.onTap,
  });

  final String text;
  final List<WordSpan> words;
  final List<Finding> findings;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final groups = <Widget>[];
    var i = 0;
    while (i < text.length) {
      if (text[i] == '\n') {
        groups.add(const SizedBox(width: double.infinity));
        i++;
        continue;
      }
      final word = words.where((w) => w.start == i).firstOrNull;
      final end = word?.end ?? i + 1;
      groups.add(
        Padding(
          padding: EdgeInsets.only(right: word != null ? 6 : 0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var k = i; k < end; k++)
                _char(k, particle: word?.particle ?? false),
            ],
          ),
        ),
      );
      i = end;
    }
    return Wrap(runSpacing: 4, children: groups);
  }

  Widget _char(int i, {required bool particle}) {
    final f = findings.where((f) => f.start <= i && i < f.end).firstOrNull;
    final tint = f == null
        ? null
        : _DiaryEntryScreenState._colour(f.kind).withValues(alpha: 0.22);
    final underline = f == null ? null : _DiaryEntryScreenState._colour(f.kind);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onTap(i),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 1, vertical: 2),
        decoration: BoxDecoration(
          color: tint,
          border: underline == null
              ? null
              : Border(bottom: BorderSide(color: underline, width: 2)),
        ),
        child: Text(
          text[i],
          style: T.jp.copyWith(
            fontSize: 20,
            height: 1.3,
            color: particle ? const Color(0xFFB39DFF) : C.text,
          ),
        ),
      ),
    );
  }
}
