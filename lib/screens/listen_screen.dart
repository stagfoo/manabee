/// Listen mode: a deck as an audio playlist.
///
/// Each word is said in Japanese, then a pause to recall it, then its
/// meaning in English, then a chime — and on to the next. The plan for
/// each word is core/listen.dart's; this screen plays it, shows the word
/// as it goes, and reveals the meaning when it's spoken.
///
/// Practice only, like Quiz and Match: it never moves a card's schedule.
library;

import 'dart:math';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import '../core/listen.dart';
import '../models.dart';
import '../services/speech.dart';
import '../theme.dart';
import '../widgets/common.dart';

class ListenScreen extends StatefulWidget {
  const ListenScreen({super.key, this.mangaId, this.playTone});

  final String? mangaId;

  /// Plays the chime and returns when it has rung out. Injectable so tests
  /// can hear the order of things; the app uses the bundled tone.wav.
  final Future<void> Function()? playTone;

  @override
  State<ListenScreen> createState() => _ListenScreenState();
}

class _ListenScreenState extends State<ListenScreen> {
  late List<Word> _queue;
  int _index = 0;
  bool _playing = false;
  bool _revealed = false;

  /// Bumped to stop whatever is playing: every await in the loop checks
  /// it, so pause, skip and leaving the screen all cut in cleanly.
  int _run = 0;

  /// Created on first use, not up front: a screen that's opened and
  /// closed without playing never touches the audio plugin.
  AudioPlayer? _player;
  bool _warnedEnglish = false;

  @override
  void initState() {
    super.initState();
    _queue = [...AppScope.read(context).wordsFor(widget.mangaId)];
  }

  @override
  void dispose() {
    _run++;
    Speech.instance.stop();
    _player?.dispose();
    super.dispose();
  }

  /// Read fresh for every word, so changing an option mid-playlist takes
  /// effect from the next word.
  static ListenSettings _settingsFrom(Settings s) {
    return ListenSettings(
      thinkTime: Duration(milliseconds: (s.listenThinkSeconds * 1000).round()),
      sayMeaning: s.listenSayMeaning,
      repeatJapanese: s.listenTwice,
    );
  }

  Future<void> _play() async {
    if (_queue.isEmpty) return;
    final run = ++_run;
    final lib = AppScope.read(context);
    setState(() => _playing = true);
    bool stopped() => !mounted || run != _run;

    while (!stopped()) {
      if (_index >= _queue.length) {
        if (!lib.settings.listenLoop) break;
        setState(() => _index = 0);
      }
      final w = _queue[_index];
      final e = w.entry;
      setState(() => _revealed = false);
      final steps = listenSteps(
        e.reading.isEmpty ? e.word : e.reading,
        spokenMeaning(e.senses.isEmpty ? const [] : e.senses.first.glosses),
        _settingsFrom(lib.settings),
      );
      for (final step in steps) {
        if (stopped()) return;
        switch (step.action) {
          case ListenAction.japanese:
            final problem = await Speech.instance.say(step.text);
            if (problem != null) {
              if (mounted) toast(context, problem);
              _stop();
              return;
            }
          case ListenAction.meaning:
            setState(() => _revealed = true);
            final problem = await Speech.instance.sayEnglish(step.text);
            if (problem != null && !_warnedEnglish && mounted) {
              _warnedEnglish = true;
              toast(context, problem);
            }
          case ListenAction.pause:
            await Future.delayed(step.duration);
          case ListenAction.tone:
            setState(() => _revealed = true);
            await (widget.playTone ?? _playTone)();
        }
      }
      if (stopped()) return;
      setState(() => _index++);
    }
    if (mounted && run == _run) setState(() => _playing = false);
  }

  Future<void> _playTone() async {
    final player = _player ??= AudioPlayer();
    await player.stop();
    await player.play(AssetSource('sounds/tone.wav'));
    // tone.wav is 0.45 s; waiting it out keeps the next word off the chime.
    await Future.delayed(const Duration(milliseconds: 450));
  }

  void _stop() {
    _run++;
    Speech.instance.stop();
    _player?.stop();
    if (mounted) setState(() => _playing = false);
  }

  void _jump(int to) {
    final wasPlaying = _playing;
    _stop();
    setState(() {
      _index = to.clamp(0, _queue.length - 1);
      _revealed = false;
    });
    if (wasPlaying) _play();
  }

  void _shuffle() {
    _stop();
    setState(() {
      _queue.shuffle(Random());
      _index = 0;
      _revealed = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final lib = AppScope.library(context);
    final s = lib.settings;
    final done = _index >= _queue.length;
    final w = _queue.isEmpty ? null : _queue[done ? _queue.length - 1 : _index];

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
          _queue.isEmpty
              ? 'Listen'
              : 'Listen  ${(_index + 1).clamp(1, _queue.length)} / ${_queue.length}',
          style: T.headlineMd,
        ),
        actions: [
          IconButton(
            tooltip: 'Shuffle',
            icon: const Icon(Icons.shuffle_rounded),
            onPressed: _queue.length > 1 ? _shuffle : null,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(
            value: _queue.isEmpty ? 0 : _index / _queue.length,
            minHeight: 4,
            backgroundColor: C.track,
            color: C.lime,
          ),
        ),
      ),
      body: w == null
          ? const EmptyState(
              emoji: '🎧',
              title: 'No words yet',
              body: 'Save words while reading and they become a playlist here.',
            )
          : Column(
              children: [
                Expanded(
                  child: _NowPlaying(word: w, revealed: _revealed),
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _Options(settings: s, onChanged: lib.changed),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              tooltip: 'Previous',
                              iconSize: 36,
                              onPressed: _index > 0
                                  ? () => _jump(_index - 1)
                                  : null,
                              icon: const Icon(Icons.skip_previous_rounded),
                            ),
                            const SizedBox(width: 20),
                            SizedBox(
                              width: 76,
                              height: 76,
                              child: IconButton.filled(
                                tooltip: _playing ? 'Pause' : 'Play',
                                style: IconButton.styleFrom(
                                  backgroundColor: C.lime,
                                  foregroundColor: C.onLime,
                                ),
                                iconSize: 44,
                                onPressed: _playing
                                    ? _stop
                                    : () {
                                        if (done) setState(() => _index = 0);
                                        _play();
                                      },
                                icon: Icon(
                                  _playing
                                      ? Icons.pause_rounded
                                      : Icons.play_arrow_rounded,
                                ),
                              ),
                            ),
                            const SizedBox(width: 20),
                            IconButton(
                              tooltip: 'Next',
                              iconSize: 36,
                              onPressed: _index < _queue.length - 1
                                  ? () => _jump(_index + 1)
                                  : null,
                              icon: const Icon(Icons.skip_next_rounded),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

/// The word being played: big, with its reading; the meaning appears
/// once it has been said.
class _NowPlaying extends StatelessWidget {
  const _NowPlaying({required this.word, required this.revealed});

  final Word word;
  final bool revealed;

  @override
  Widget build(BuildContext context) {
    final e = word.entry;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(e.word, style: Jp.word, textAlign: TextAlign.center),
            if (e.hasKanji) Text(e.reading, style: Jp.reading),
            const SizedBox(height: 24),
            AnimatedOpacity(
              duration: const Duration(milliseconds: 250),
              opacity: revealed ? 1 : 0,
              child: Text(
                e.shortMeaning,
                textAlign: TextAlign.center,
                style: T.headlineMd.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Think time, and whether the meaning is said, the Japanese said twice,
/// the playlist looped. Saved with the rest of the settings.
class _Options extends StatelessWidget {
  const _Options({required this.settings, required this.onChanged});

  final Settings settings;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    Widget chip(String label, bool on, void Function(bool) set) => FilterChip(
      label: Text(label, style: T.pill.copyWith(color: on ? C.onLime : C.text)),
      selected: on,
      showCheckmark: false,
      selectedColor: C.lime,
      backgroundColor: C.surface,
      side: const BorderSide(color: C.border),
      shape: const StadiumBorder(),
      onSelected: (v) {
        set(v);
        onChanged();
      },
    );
    return Column(
      children: [
        Row(
          children: [
            Text('Think time', style: T.bodyMd.copyWith(color: C.textDim)),
            Expanded(
              child: Slider(
                value: settings.listenThinkSeconds,
                min: 0.5,
                max: 8,
                divisions: 15,
                label: '${settings.listenThinkSeconds}s',
                onChanged: (v) {
                  settings.listenThinkSeconds = v;
                  onChanged();
                },
              ),
            ),
            SizedBox(
              width: 40,
              child: Text(
                '${settings.listenThinkSeconds}s',
                style: T.monoBold.copyWith(color: C.lime),
              ),
            ),
          ],
        ),
        Wrap(
          spacing: 8,
          alignment: WrapAlignment.center,
          children: [
            chip(
              'Say meaning',
              settings.listenSayMeaning,
              (v) => settings.listenSayMeaning = v,
            ),
            chip(
              'Japanese twice',
              settings.listenTwice,
              (v) => settings.listenTwice = v,
            ),
            chip('Loop', settings.listenLoop, (v) => settings.listenLoop = v),
          ],
        ),
      ],
    );
  }
}
