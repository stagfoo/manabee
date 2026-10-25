/// Shadowing: hear it, say it, compare, grade yourself.
///
/// Each card plays the phone's Japanese voice saying the word. Tap the mic to record yourself, then play yours and
/// the native one as often as you like, and grade it with Again / Hard /
/// Good / Easy. Speaking has its own spaced-repetition schedule
/// (Word.speaking), apart from flash cards: being able to say a word is a
/// different skill from recognising it.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/srs.dart';
import '../models.dart';
import '../services/shadow_audio.dart';
import '../services/store.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/confetti.dart';
import '../widgets/srs_widgets.dart';

/// What gets shadowed for [w]: the word, read in kana so the voice can't
/// guess a kanji wrong.
///
/// Only the word, never the bubble it came from: bubble text comes from
/// OCR or is typed by hand, and nothing has checked it — shadowing a
/// misread sentence would drill the mistake.
String shadowText(Word w) {
  final e = w.entry;
  return e.reading.isEmpty ? e.word : e.reading;
}

class ShadowScreen extends StatefulWidget {
  const ShadowScreen({super.key, this.mangaId, this.audio});

  final String? mangaId;

  /// For tests: audio that doesn't need a microphone.
  final ShadowAudio? audio;

  @override
  State<ShadowScreen> createState() => _ShadowScreenState();
}

class _ShadowScreenState extends State<ShadowScreen> {
  late final ShadowAudio _audio = widget.audio ?? DeviceShadowAudio();
  late StudySession _session;
  int _answered = 0;

  bool _recording = false;

  /// Whether the card in front of you has a recording yet.
  String? _recordedFor;
  String? _autoPlayedFor;

  @override
  void initState() {
    super.initState();
    final lib = AppScope.read(context);
    _session = StudySession(
      {for (final w in lib.wordsFor(widget.mangaId)) w.id: w.speaking},
      DateTime.now(),
      newLimit: lib.newSpeakingAllowanceToday(),
    );
  }

  @override
  void dispose() {
    _audio.stopAll();
    _audio.dispose();
    super.dispose();
  }

  Future<void> _native(Word w) async {
    final problem = await _audio.playNative(shadowText(w));
    if (problem != null && mounted) toast(context, problem);
  }

  Future<void> _toggleRecord() async {
    if (_recording) {
      final ok = await _audio.stopRecording();
      if (!mounted) return;
      setState(() {
        _recording = false;
        if (ok) _recordedFor = _currentId;
      });
      // Straight back to you, so the comparison is immediate.
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

  String? get _currentId => _session.current(DateTime.now());

  void _grade(String id, Grade g) {
    if (_recording) _audio.stopRecording();
    final state = _session.answer(id, g, DateTime.now());
    AppScope.read(context).setSpeaking(id, state);
    HapticFeedback.selectionClick();
    setState(() {
      _answered++;
      _recording = false;
      _recordedFor = null;
    });
  }

  void _undo() {
    final undone = _session.undo();
    if (undone == null) return;
    AppScope.read(context).setSpeaking(undone.$1, undone.$2);
    setState(() {
      if (_answered > 0) _answered--;
      _autoPlayedFor = undone.$1; // don't replay on undo
    });
  }

  @override
  Widget build(BuildContext context) {
    final lib = AppScope.library(context);
    final byId = {for (final w in lib.wordsFor(widget.mangaId)) w.id: w};
    final now = DateTime.now();
    final id = _session.current(now);
    final word = id == null ? null : byId[id];
    final total =
        _answered +
        _session.newCount +
        _session.learningCount +
        _session.reviewCount;

    // Each new card speaks once on its own: shadowing starts by listening.
    if (word != null && _autoPlayedFor != word.id) {
      _autoPlayedFor = word.id;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _native(word);
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
          word == null ? 'Shadowing' : '$_answered / $total',
          style: T.headlineMd,
        ),
        actions: [
          IconButton(
            tooltip: 'Undo',
            onPressed: _session.canUndo ? _undo : null,
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
      body: word == null ? _done(lib) : _card(word),
    );
  }

  Widget _card(Word word) {
    final e = word.entry;
    final recorded = _recordedFor == word.id;
    final now = DateTime.now();
    return Column(
      children: [
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('SAY THE WORD', style: T.monoSm),
                  const SizedBox(height: 16),
                  Text(e.word, textAlign: TextAlign.center, style: Jp.word),
                  if (e.hasKanji) Text(e.reading, style: Jp.reading),
                  const SizedBox(height: 12),
                  Text(
                    e.shortMeaning,
                    textAlign: TextAlign.center,
                    style: T.bodyMd.copyWith(color: C.textDim),
                  ),
                  const SizedBox(height: 32),
                  MicButton(recording: _recording, onTap: _toggleRecord),
                  const SizedBox(height: 8),
                  Text(
                    _recording
                        ? 'Recording — tap to stop'
                        : recorded
                        ? 'Tap to try again'
                        : 'Tap to record yourself',
                    style: T.bodyMd.copyWith(color: C.textDim, fontSize: 12),
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
                        onPressed: _recording ? null : () => _native(word),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                SrsCounts(
                  newCards: _session.newCount,
                  learning: _session.learningCount,
                  review: _session.reviewCount,
                  current: word.speaking,
                ),
                const SizedBox(height: 10),
                GradeRow(
                  previews: previewAll(word.speaking, now),
                  now: now,
                  onGrade: (g) => _grade(word.id, g),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _done(Library lib) {
    final next = _session.nextLearningDue;
    if (next != null) {
      return DoneMessage(
        icon: Icons.hourglass_top_rounded,
        title: 'Learning cards coming up',
        body:
            'The next is due in ${formatInterval(next.difference(DateTime.now()))}. '
            'Stay here and it appears on its own.',
      );
    }
    final message = DoneMessage(
      icon: Icons.check_circle_outline_rounded,
      title: _answered > 0 ? '$_answered spoken' : 'Nothing to shadow now',
      body: lib.wordsFor(widget.mangaId).isEmpty
          ? 'Save some words first.'
          : 'Congratulations! You have finished this deck for now.',
      actions: [
        BigButton(label: 'Back', onPressed: () => Navigator.maybePop(context)),
      ],
    );
    if (_answered == 0) return message;
    return Stack(
      children: [
        message,
        const Positioned.fill(child: Confetti()),
      ],
    );
  }
}

class MicButton extends StatelessWidget {
  const MicButton({super.key, required this.recording, required this.onTap});

  final bool recording;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 96,
      height: 96,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: recording ? Srs.again : C.lime,
        boxShadow: [
          BoxShadow(
            color: (recording ? Srs.again : C.lime).withValues(alpha: 0.45),
            blurRadius: recording ? 28 : 16,
          ),
        ],
      ),
      child: Icon(
        recording ? Icons.stop_rounded : Icons.mic_rounded,
        size: 48,
        color: recording ? Colors.white : C.onLime,
        semanticLabel: recording ? 'Stop recording' : 'Record',
      ),
    ),
  );
}

class PlayButton extends StatelessWidget {
  const PlayButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    style: OutlinedButton.styleFrom(
      foregroundColor: C.text,
      disabledForegroundColor: C.inactive,
      minimumSize: const Size(0, 52),
      side: const BorderSide(color: C.ghostBorder, width: 1.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      textStyle: T.pill.copyWith(fontSize: 15),
    ),
    onPressed: onPressed,
    icon: Icon(icon, size: 20),
    label: FittedBox(fit: BoxFit.scaleDown, child: Text('▶  $label')),
  );
}
