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
              if (r.form != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    'Written: $surface  ·  ${r.form!.label}',
                    style: T.monoBold.copyWith(color: C.textDim, fontSize: 12),
                  ),
                ),
              EntryDetail(e, context_: sentence, surface: surface),
              const SizedBox(height: 16),
              LimeButton(
                label: 'Save to Diary words',
                icon: Icons.add_rounded,
                onPressed: () {
                  final lib = AppScope.read(context);
                  final book = lib.diaryWordBook();
                  final added = lib.saveWord(
                    book.id,
                    e,
                    context: sentence,
                    surface: r.form == null ? '' : surface,
                    form: r.form?.label ?? '',
                  );
                  Navigator.pop(context);
                  toast(
                    context,
                    added
                        ? 'Saved ${e.word} to Diary words.'
                        : '${e.word} is already in Diary words.',
                  );
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
    return GridScaffold(
      onBack: () => Navigator.maybePop(context),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(diaryDate(_entry.written), style: T.monoSm),
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
