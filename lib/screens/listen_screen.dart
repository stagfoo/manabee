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
  const ListenScreen({super.key, this.mangaId, this.playTone, this.seed});

  final String? mangaId;

  /// Plays the chime and returns when it has rung out. Injectable so tests
  /// can hear the order of things; the app uses the bundled tone.wav.
  final Future<void> Function()? playTone;

  /// For tests: a fixed shuffle.
  final int? seed;

  @override
  State<ListenScreen> createState() => _ListenScreenState();
}

/// How well a word is known, from its flash-card schedule.
Familiarity familiarityOf(Word w) {
  final r = w.review;
  if (r.isNew) return Familiarity.fresh;
  if (r.learned) return Familiarity.known;
  if (r.isLearning || r.lapses > 0) return Familiarity.weak;
  return Familiarity.review;
}

ListenOrder _orderFrom(String s) => switch (s) {
  'saved' => ListenOrder.saved,
  'shuffled' => ListenOrder.shuffled,
  _ => ListenOrder.weakest,
};

class _ListenScreenState extends State<ListenScreen> {
  late List<Word> _words;

  /// The playlist: words in play order, repeats included
  /// (core/listen.dart buildPlaylist).
  List<PlaylistEntry> _entries = const [];
  int _index = 0;
  bool _playing = false;
  late final Random _random = Random(widget.seed);

  /// What's on screen for the word being played. Each side appears as
  /// it's said, so meaning-first hides the Japanese until it's heard.
  bool _showJapanese = true;
  bool _showMeaning = false;
  String? _sentence;

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
    _words = [...AppScope.read(context).wordsFor(widget.mangaId)];
    _rebuild();
  }

  @override
  void dispose() {
    _run++;
    Speech.instance.stop();
    _player?.dispose();
    super.dispose();
  }

  /// A fresh playlist from the current settings — and a fresh shuffle,
  /// each time round a loop.
  void _rebuild() {
    final s = AppScope.read(context).settings;
    _entries = buildPlaylist(
      [for (final w in _words) familiarityOf(w)],
      _orderFrom(s.listenOrder),
      _random,
      repeats: s.listenRepeats,
    );
    _index = 0;
  }

  Word? get _current {
    if (_entries.isEmpty) return null;
    final i = _index.clamp(0, _entries.length - 1);
    return _words[_entries[i].word];
  }

  /// Read fresh for every word, so changing an option mid-playlist takes
  /// effect from the next word.
  static ListenSettings _settingsFrom(Settings s, Familiarity f) {
    final base = Duration(milliseconds: (s.listenThinkSeconds * 1000).round());
    return ListenSettings(
      thinkTime: s.listenAdaptive ? adaptiveThinkTime(base, f) : base,
      sayMeaning: s.listenSayMeaning,
      repeatJapanese: s.listenTwice,
      toneBefore: s.listenToneBefore,
      meaningFirst: s.listenMeaningFirst,
      saySentence: s.listenSentence,
    );
  }

  Future<void> _play() async {
    if (_entries.isEmpty) return;
    final run = ++_run;
    final lib = AppScope.read(context);
    setState(() => _playing = true);
    bool stopped() => !mounted || run != _run;

    while (!stopped()) {
      if (_index >= _entries.length) {
        if (!lib.settings.listenLoop) break;
        setState(_rebuild);
      }
      final w = _words[_entries[_index].word];
      final e = w.entry;
      final settings = _settingsFrom(lib.settings, familiarityOf(w));
      setState(() {
        _showJapanese = !(settings.meaningFirst && settings.sayMeaning);
        _showMeaning = false;
        _sentence = null;
      });
      final inSentence =
          findInSentence(e, w.context, surface: w.surface) != null;
      final steps = listenSteps(
        e.reading.isEmpty ? e.word : e.reading,
        spokenMeaning(e.senses.isEmpty ? const [] : e.senses.first.glosses),
        settings,
        sentence: inSentence ? w.context : '',
      );
      for (final step in steps) {
        if (stopped()) return;
        switch (step.action) {
          case ListenAction.japanese:
            setState(() => _showJapanese = true);
            final problem = await Speech.instance.say(step.text);
            if (problem != null) {
              if (mounted) toast(context, problem);
              _stop();
              return;
            }
          case ListenAction.meaning:
            setState(() => _showMeaning = true);
            final problem = await Speech.instance.sayEnglish(step.text);
            if (problem != null && !_warnedEnglish && mounted) {
              _warnedEnglish = true;
              toast(context, problem);
            }
          case ListenAction.sentence:
            setState(() => _sentence = step.text);
            await Speech.instance.say(step.text);
          case ListenAction.pause:
            await Future.delayed(step.duration);
          case ListenAction.reveal:
            setState(() => _showMeaning = true);
          case ListenAction.tone:
            await (widget.playTone ?? _playTone)();
        }
      }
      if (stopped()) return;
      setState(() => _index++);
    }
    if (mounted && run == _run) setState(() => _playing = false);
  }

  /// The chime player, set up once.
  ///
  /// Two things here are why the chime used to ring only once:
  /// - mixWithOthers: by default the player takes Android audio focus, and
  ///   the text-to-speech voice takes it straight back for the next word —
  ///   after which the player stays silent. Mixing asks for no focus, so
  ///   neither silences the other.
  /// - ReleaseMode.stop with the source loaded once: each chime rewinds and
  ///   resumes the same loaded sound rather than setting it up again, which
  ///   on Android can quietly fail for a short clip played back to back.
  Future<AudioPlayer> _tonePlayer() async {
    final existing = _player;
    if (existing != null) return existing;
    final player = AudioPlayer();
    await player.setAudioContext(
      AudioContextConfig(focus: AudioContextConfigFocus.mixWithOthers).build(),
    );
    await player.setReleaseMode(ReleaseMode.stop);
    await player.setSource(AssetSource('sounds/tone.wav'));
    return _player = player;
  }

  Future<void> _playTone() async {
    final player = await _tonePlayer();
    await player.stop();
    await player.seek(Duration.zero);
    await player.resume();
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
      _index = to.clamp(0, _entries.length - 1);
      _showJapanese = true;
      _showMeaning = false;
      _sentence = null;
    });
    if (wasPlaying) _play();
  }

  /// The options, in a sheet: the main screen stays the word and the
  /// controls. Changing the order or repeats starts a new playlist.
  void _openOptions() {
    final lib = AppScope.read(context);
    final before = (lib.settings.listenOrder, lib.settings.listenRepeats);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => ListenableBuilder(
        listenable: lib,
        builder: (context, _) => SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: _Options(settings: lib.settings, onChanged: lib.changed),
          ),
        ),
      ),
    ).then((_) {
      if (!mounted) return;
      final after = (lib.settings.listenOrder, lib.settings.listenRepeats);
      if (after != before) {
        _stop();
        setState(_rebuild);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final done = _index >= _entries.length;
    final w = _current;
    final repeat = _entries.isEmpty || done ? 0 : _entries[_index].repeat;

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
          _entries.isEmpty
              ? 'Listen'
              : 'Listen  ${(_index + 1).clamp(1, _entries.length)} / ${_entries.length}',
          style: T.headlineMd,
        ),
        actions: [
          IconButton(
            tooltip: 'Options',
            icon: const Icon(Icons.tune_rounded),
            onPressed: _openOptions,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(
            value: _entries.isEmpty ? 0 : _index / _entries.length,
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
                  child: _NowPlaying(
                    word: w,
                    // Paused, the word is always shown; playing, each side
                    // appears as it's said.
                    showJapanese: !_playing || _showJapanese,
                    showMeaning: _showMeaning,
                    sentence: _sentence,
                    repeat: repeat,
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
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
                              onPressed: _index < _entries.length - 1
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
  const _NowPlaying({
    required this.word,
    required this.showJapanese,
    required this.showMeaning,
    this.sentence,
    this.repeat = 0,
  });

  final Word word;
  final bool showJapanese;
  final bool showMeaning;

  /// The sentence being said, if it's that part of the word.
  final String? sentence;

  /// A repeat of a new or weak word, rather than its first play.
  final int repeat;

  @override
  Widget build(BuildContext context) {
    final e = word.entry;
    Widget fade(bool on, Widget child) => AnimatedOpacity(
      duration: const Duration(milliseconds: 250),
      opacity: on ? 1 : 0,
      child: child,
    );
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (repeat > 0)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  'AGAIN',
                  style: T.monoSm.copyWith(color: C.mint, fontSize: 12),
                ),
              ),
            fade(
              showJapanese,
              Column(
                children: [
                  Text(e.word, style: Jp.word, textAlign: TextAlign.center),
                  if (e.hasKanji) Text(e.reading, style: Jp.reading),
                ],
              ),
            ),
            const SizedBox(height: 24),
            fade(
              showMeaning,
              Text(
                e.shortMeaning,
                textAlign: TextAlign.center,
                style: T.headlineMd.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            if (sentence != null) ...[
              const SizedBox(height: 20),
              Text(
                '「$sentence」',
                textAlign: TextAlign.center,
                style: T.jp.copyWith(fontSize: 17, color: C.textDim),
              ),
            ],
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
        _Choice(
          label: 'Chime',
          options: const ['Before word', 'After word'],
          selected: settings.listenToneBefore ? 0 : 1,
          onSelected: (i) {
            settings.listenToneBefore = i == 0;
            onChanged();
          },
        ),
        const SizedBox(height: 6),
        _Choice(
          label: 'Playlist',
          options: const ['As saved', 'Shuffle', 'Weakest'],
          selected: switch (settings.listenOrder) {
            'saved' => 0,
            'shuffled' => 1,
            _ => 2,
          },
          onSelected: (i) {
            settings.listenOrder = const ['saved', 'shuffled', 'weakest'][i];
            onChanged();
          },
        ),
        const SizedBox(height: 6),
        _Choice(
          label: 'Say first',
          options: const ['Japanese', 'Meaning'],
          selected: settings.listenMeaningFirst ? 1 : 0,
          // Meaning-first needs the meaning said; without it there's
          // nothing to recall from.
          enabled: settings.listenSayMeaning,
          onSelected: (i) {
            settings.listenMeaningFirst = i == 1;
            onChanged();
          },
        ),
        const SizedBox(height: 6),
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
            chip(
              'Repeats',
              settings.listenRepeats,
              (v) => settings.listenRepeats = v,
            ),
            chip(
              'Adaptive pause',
              settings.listenAdaptive,
              (v) => settings.listenAdaptive = v,
            ),
            chip(
              'Sentence',
              settings.listenSentence,
              (v) => settings.listenSentence = v,
            ),
          ],
        ),
      ],
    );
  }
}

/// A labelled two-way switch: "Chime  [Before word | After word]".
class _Choice extends StatelessWidget {
  const _Choice({
    required this.label,
    required this.options,
    required this.selected,
    required this.onSelected,
    this.enabled = true,
  });

  final String label;
  final List<String> options;
  final int selected;
  final ValueChanged<int> onSelected;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 64,
          child: Text(label, style: T.bodyMd.copyWith(color: C.textDim)),
        ),
        Expanded(
          child: SegmentedButton<int>(
            segments: [
              for (var i = 0; i < options.length; i++)
                ButtonSegment(
                  value: i,
                  label: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(options[i]),
                  ),
                ),
            ],
            selected: {selected},
            showSelectedIcon: false,
            onSelectionChanged: enabled ? (s) => onSelected(s.first) : null,
            style: SegmentedButton.styleFrom(
              selectedBackgroundColor: C.lime,
              selectedForegroundColor: C.onLime,
              foregroundColor: C.text,
              disabledForegroundColor: C.inactive,
              side: const BorderSide(color: C.ghostBorder),
              visualDensity: VisualDensity.compact,
            ),
          ),
        ),
      ],
    );
  }
}
