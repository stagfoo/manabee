/// Sentence shadowing: whole sentences, by level or built around your
/// focus words.
///
/// Word shadowing drills a word alone; this puts it in a sentence a native
/// speaker wrote (Tatoeba — see core/sentences.dart), where the rhythm and
/// the particles around it are what's practised. Pick the focus words and
/// each comes in up to three sentences, easiest first, with the word lit;
/// or pick a level and work through it, shortest first. Same loop as word
/// shadowing — hear it, record, compare, grade — on its own schedule.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/sentences.dart';
import '../core/srs.dart';
import '../models.dart';
import '../services/sentence_bank.dart';
import '../services/shadow_audio.dart';
import '../services/store.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/srs_widgets.dart';
import 'shadow_screen.dart';

/// 'focus', or a level.
const kFocusMode = 'focus';

class SentenceShadowScreen extends StatefulWidget {
  const SentenceShadowScreen({super.key, this.sentences, this.audio});

  /// For tests: sentences instead of the bundled ones.
  final List<Sentence>? sentences;

  /// For tests: audio that doesn't need a microphone.
  final ShadowAudio? audio;

  @override
  State<SentenceShadowScreen> createState() => _SentenceShadowScreenState();
}

class _SentenceShadowScreenState extends State<SentenceShadowScreen> {
  late final ShadowAudio _audio = widget.audio ?? DeviceShadowAudio();
  List<Sentence>? _all;
  String _mode = kFocusMode;
  List<Sentence> _pool = [];
  StudySession? _session;
  int _answered = 0;
  bool _recording = false;

  /// The card on screen, held until it's graded. The session's idea of
  /// "current" changes as learning cards fall due — asked afresh on every
  /// repaint, a card could be swapped out from under you as you tapped
  /// Show answer.
  String? _shown;
  String? _recordedFor;
  String? _autoPlayedFor;

  @override
  void initState() {
    super.initState();
    final given = widget.sentences;
    if (given != null) {
      _ready(given);
    } else {
      SentenceBank.load().then((all) {
        if (mounted) setState(() => _ready(all));
      });
    }
  }

  @override
  void dispose() {
    _audio.stopAll();
    _audio.dispose();
    super.dispose();
  }

  List<Entry> get _focus => [
    for (final w in AppScope.read(context).wordsFor(kFocusDeck)) w.entry,
  ];

  void _ready(List<Sentence> all) {
    _all = all;
    // Focus words when there are some with sentences; otherwise the start.
    _mode = sentencesFor(all, _focus).isNotEmpty ? kFocusMode : 'N5';
    _start();
  }

  void _start() {
    final all = _all!;
    final lib = AppScope.read(context);
    _pool = _mode == kFocusMode
        ? sentencesFor(all, _focus)
        : sentencesAt(all, _mode);
    _session = StudySession(
      {
        for (final s in _pool)
          s.key: lib.sentenceSpeaking[s.key] ?? const ReviewState(),
      },
      DateTime.now(),
      newLimit: lib.newSentenceAllowanceToday(),
    );
    _answered = 0;
    _recording = false;
    _recordedFor = null;
    _shown = null;
  }

  void _pick(String mode) {
    if (_recording) _audio.stopRecording();
    setState(() {
      _mode = mode;
      _start();
    });
  }

  Future<void> _native(Sentence s) async {
    final problem = await _audio.playNative(s.japanese);
    if (problem != null && mounted) toast(context, problem);
  }

  Future<void> _toggleRecord(String key) async {
    if (_recording) {
      final ok = await _audio.stopRecording();
      if (!mounted) return;
      setState(() {
        _recording = false;
        if (ok) _recordedFor = key;
      });
      if (ok) await _audio.playYours();
      return;
    }
    final ok = await _audio.startRecording();
    if (!mounted) return;
    if (!ok) {
      toast(context, 'Couldn\'t use the microphone — allow it in Settings.');
      return;
    }
    HapticFeedback.selectionClick();
    setState(() => _recording = true);
  }

  void _grade(String key, Grade g) {
    if (_recording) _audio.stopRecording();
    final state = _session!.answer(key, g, DateTime.now());
    AppScope.read(context).setSentenceSpeaking(key, state);
    HapticFeedback.selectionClick();
    setState(() {
      _answered++;
      _recording = false;
      _recordedFor = null;
      _shown = null;
    });
  }

  void _undo() {
    final undone = _session!.undo();
    if (undone == null) return;
    AppScope.read(context).setSentenceSpeaking(undone.$1, undone.$2);
    setState(() {
      if (_answered > 0) _answered--;
      _autoPlayedFor = undone.$1;
      _shown = undone.$1;
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = _session;
    final now = DateTime.now();
    final key = session == null ? null : _shown ??= session.current(now);
    final sentence = key == null
        ? null
        : _pool.where((s) => s.key == key).firstOrNull;
    final total = session == null
        ? 0
        : _answered +
              session.newCount +
              session.learningCount +
              session.reviewCount;

    if (sentence != null && _autoPlayedFor != sentence.key) {
      _autoPlayedFor = sentence.key;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _native(sentence);
      });
    }

    return Scaffold(
      backgroundColor: C.ground,
      appBar: AppBar(
        backgroundColor: C.ground,
        foregroundColor: C.text,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          tooltip: 'Close',
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: Text(
          sentence == null ? 'Sentences' : '$_answered / $total',
          style: T.headlineMd,
        ),
        actions: [
          IconButton(
            tooltip: 'Undo',
            onPressed: session?.canUndo ?? false ? _undo : null,
            icon: const Icon(Icons.undo_rounded),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(
            value: total == 0 ? 1 : _answered / total,
            minHeight: 4,
            backgroundColor: C.track,
            color: C.lime,
          ),
        ),
      ),
      body: _all == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _modes(),
                Expanded(
                  child: sentence == null
                      ? _done()
                      : _card(sentence, session!, now),
                ),
              ],
            ),
    );
  }

  Widget _modes() {
    Widget chip(String mode, String label) => Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: _mode == mode,
        onSelected: (_) => _pick(mode),
        selectedColor: C.lime,
        labelStyle: T.pill.copyWith(color: _mode == mode ? C.onLime : C.text),
        backgroundColor: C.surface,
        side: const BorderSide(color: C.border),
        showCheckmark: false,
      ),
    );
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        children: [
          chip(kFocusMode, '🎯 Focus words'),
          for (final l in kSentenceLevels) chip(l, l),
        ],
      ),
    );
  }

  /// The sentence, with a focus word in it lit.
  Widget _sentence(Sentence s) {
    (int, int)? lit;
    if (_mode == kFocusMode) {
      for (final e in _focus) {
        if (usesWord(s, e)) {
          lit = wordSpanIn(s, e);
          break;
        }
      }
    }
    final text = s.japanese;
    return Text.rich(
      TextSpan(
        children: lit == null
            ? [TextSpan(text: text)]
            : [
                TextSpan(text: text.substring(0, lit.$1)),
                TextSpan(
                  text: text.substring(lit.$1, lit.$2),
                  style: const TextStyle(color: C.lime),
                ),
                TextSpan(text: text.substring(lit.$2)),
              ],
      ),
      textAlign: TextAlign.center,
      style: T.jp.copyWith(fontSize: 26, fontWeight: FontWeight.w700),
    );
  }

  Widget _card(Sentence s, StudySession session, DateTime now) {
    final recorded = _recordedFor == s.key;
    final state = session.states[s.key]!;
    return Column(
      children: [
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('SAY THE SENTENCE · ${s.level}', style: T.monoSm),
                  const SizedBox(height: 16),
                  _sentence(s),
                  const SizedBox(height: 12),
                  Text(
                    s.english,
                    textAlign: TextAlign.center,
                    style: T.bodyMd.copyWith(color: C.textDim),
                  ),
                  const SizedBox(height: 28),
                  MicButton(
                    recording: _recording,
                    onTap: () => _toggleRecord(s.key),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _recording
                        ? 'Recording — tap to stop'
                        : recorded
                        ? 'Tap to try again'
                        : 'Tap to record yourself',
                    style: T.bodyMd.copyWith(color: C.textDim, fontSize: 12),
                  ),
                  const SizedBox(height: 16),
                  // CC BY: the sentence's source and author, always shown.
                  Text(
                    s.source,
                    style: T.monoSm.copyWith(fontSize: 10, color: C.inactive),
                  ),
                ],
              ),
            ),
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: PlayButton(
                        label: 'You',
                        icon: Icons.person_rounded,
                        onPressed: recorded && !_recording
                            ? _audio.playYours
                            : null,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: PlayButton(
                        label: 'Native',
                        icon: Icons.record_voice_over_rounded,
                        onPressed: _recording ? null : () => _native(s),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                SrsCounts(
                  newCards: session.newCount,
                  learning: session.learningCount,
                  review: session.reviewCount,
                  current: state,
                ),
                const SizedBox(height: 10),
                GradeRow(
                  previews: previewAll(state, now),
                  now: now,
                  onGrade: (g) => _grade(s.key, g),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _done() {
    final next = _session?.nextLearningDue;
    if (next != null) {
      return DoneMessage(
        icon: Icons.hourglass_top_rounded,
        title: 'Learning cards coming up',
        body:
            'The next is due in ${formatInterval(next.difference(DateTime.now()))}. '
            'Stay here and it appears on its own.',
      );
    }
    final focusEmpty = _mode == kFocusMode && _pool.isEmpty;
    return DoneMessage(
      icon: focusEmpty
          ? Icons.search_off_rounded
          : Icons.check_circle_outline_rounded,
      title: focusEmpty
          ? 'No sentences for your focus words'
          : _answered > 0
          ? '$_answered spoken'
          : 'Nothing to shadow now',
      body: focusEmpty
          ? (_focus.isEmpty
                ? 'Pick some focus words in Study, or choose a level above.'
                : 'None of the checked sentences use them yet — choose a '
                      'level above.')
          : 'That\'s today\'s new sentences. Come back tomorrow, or choose '
                'another set above.',
      actions: [
        BigButton(label: 'Back', onPressed: () => Navigator.maybePop(context)),
      ],
    );
  }
}
