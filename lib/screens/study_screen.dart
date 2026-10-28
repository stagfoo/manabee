/// The Study tab, laid out like jlptbenkyo's home: pick a deck (every word,
/// or one manga's), see what's due today and study it, then practice games
/// underneath.
library;

import 'package:flutter/material.dart';

import '../core/games.dart';
import '../core/srs.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../services/store.dart';
import 'diary_screen.dart';
import 'flashcards_screen.dart';
import 'focus_screen.dart';
import 'kanji_chain_screen.dart';
import 'listen_screen.dart';
import 'sentence_shadow_screen.dart';
import 'shadow_screen.dart';
import 'match_screen.dart';
import 'mock_test_screen.dart';
import 'quiz_screen.dart';
import 'conjugation_screen.dart';
import 'grammar_screen.dart';

GameCard gameCardOf(Word w) => GameCard(
  id: w.id,
  japanese: w.entry.word,
  reading: w.entry.reading,
  meaning: w.entry.shortMeaning,
);

/// Flash cards run full screen, above the dock, as a review does in Anki.
void openFlashcards(
  BuildContext context,
  String? mangaId, [
  CardSkill skill = CardSkill.listening,
]) => Navigator.of(context, rootNavigator: true).push(
  MaterialPageRoute(
    builder: (_) => FlashcardsScreen(mangaId: mangaId, skill: skill),
  ),
);

class StudyScreen extends StatefulWidget {
  const StudyScreen({super.key});

  @override
  State<StudyScreen> createState() => _StudyScreenState();
}

class _StudyScreenState extends State<StudyScreen> {
  /// The deck: a book's id, [kFocusDeck], or null for every word.
  String? _mangaId;

  @override
  void initState() {
    super.initState();
    // Open on the focus set when there is one: it's what's being studied.
    if (AppScope.read(context).focusCount > 0) _mangaId = kFocusDeck;
  }

  Future<void> _chooseFocus() async {
    await Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const FocusScreen()));
    if (!mounted) return;
    final lib = AppScope.read(context);
    setState(() => _mangaId = lib.focusCount > 0 ? kFocusDeck : null);
  }

  @override
  Widget build(BuildContext context) {
    final lib = AppScope.library(context);
    final focusCount = lib.focusCount;
    if (_mangaId == kFocusDeck) {
      if (focusCount == 0) _mangaId = null;
    } else if (_mangaId != null && lib.mangaById(_mangaId!) == null) {
      _mangaId = null;
    }
    final words = lib.wordsFor(_mangaId);
    // Listening always works on the focus set when there is one — the few
    // words being learned now — whichever deck is picked above.
    final listenDeck = lib.focusCount > 0 ? kFocusDeck : _mangaId;
    final listenWords = lib.wordsFor(listenDeck);
    final heard = lib.cardsDueToday(_mangaId, CardSkill.listening);
    final read = lib.cardsDueToday(_mangaId, CardSkill.reading);
    final kanjiWords = lib.cardsFor(_mangaId, CardSkill.reading).length;
    // Manga once they've given you words; commonplace books always — you
    // made those to study.
    final decks = lib.recent
        .where((m) => m.commonplace || lib.wordsFor(m.id).isNotEmpty)
        .toList();

    void open(Widget screen) =>
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));

    return GridScaffold(
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                if (focusCount > 0)
                  _DeckChip(
                    label: '🎯 Focus · $focusCount',
                    on: _mangaId == kFocusDeck,
                    onTap: () => setState(() => _mangaId = kFocusDeck),
                  ),
                _DeckChip(
                  label: 'All words',
                  on: _mangaId == null,
                  onTap: () => setState(() => _mangaId = null),
                ),
                for (final m in decks)
                  _DeckChip(
                    label: m.commonplace ? '📒 ${m.title}' : m.title,
                    on: _mangaId == m.id,
                    onTap: () => setState(() => _mangaId = m.id),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _FocusPanel(
            count: focusCount,
            learned: lib.learnedCount(kFocusDeck),
            onChoose: _chooseFocus,
          ),
          const SizedBox(height: 8),
          _Section(
            icon: Icons.hearing_rounded,
            title: 'Listening',
            subtitle: 'Knowing a word when you hear it',
          ),
          _DueCard(
            label: 'Listening cards',
            hint: 'Hear the word, recall what it means',
            today: heard,
            deckSize: words.length,
            learned: lib.cardsLearned(_mangaId, CardSkill.listening),
            onStart: () => openFlashcards(context, _mangaId),
          ),
          const SizedBox(height: 4),
          if (listenDeck == kFocusDeck)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 4, 2),
              child: Text(
                'Practice below uses your ${listenWords.length} focus words.',
                style: T.bodyMd.copyWith(color: C.textDim, fontSize: 12),
              ),
            ),
          _Tile(
            icon: Icons.headphones_rounded,
            title: 'Listen',
            subtitle: 'Audio playlist: Japanese, a pause, the meaning, a chime',
            enabled: listenWords.isNotEmpty,
            onTap: () => Navigator.of(context, rootNavigator: true).push(
              MaterialPageRoute(
                builder: (_) => ListenScreen(mangaId: listenDeck),
              ),
            ),
          ),
          _Tile(
            icon: Icons.record_voice_over_outlined,
            title: 'Listening Quiz',
            subtitle: listenWords.length >= kMinQuizWords
                ? 'Hear the word, pick its meaning'
                : 'Needs $kMinQuizWords words to play',
            enabled: listenWords.length >= kMinQuizWords,
            onTap: () => open(QuizScreen(mangaId: listenDeck, audio: true)),
          ),
          _Tile(
            icon: Icons.volume_up_outlined,
            title: 'Listening Match',
            subtitle: listenWords.length >= kMinMatchWords
                ? 'Tap a tile to hear it; pair it with its meaning'
                : 'Needs $kMinMatchWords words to play',
            enabled: listenWords.length >= kMinMatchWords,
            onTap: () => open(MatchScreen(mangaId: listenDeck, audio: true)),
          ),
          _Section(
            icon: Icons.menu_book_rounded,
            title: 'Reading',
            subtitle: 'Knowing a word when you see its kanji',
          ),
          _DueCard(
            label: 'Reading cards',
            hint: 'See the kanji, recall the reading and meaning',
            today: read,
            deckSize: kanjiWords,
            learned: lib.cardsLearned(_mangaId, CardSkill.reading),
            emptyText: words.isEmpty
                ? 'No flash cards yet.'
                : 'No words with kanji in this deck.',
            onStart: () => openFlashcards(context, _mangaId, CardSkill.reading),
          ),
          const SizedBox(height: 4),
          _Tile(
            icon: Icons.assignment_outlined,
            title: 'Mock JLPT test',
            subtitle: switch (lib.mockResults.lastOrNull) {
              null =>
                'N5 · N4 · N3 — kanji readings and spellings, '
                    'test style',
              final r =>
                'Last: ${r.level} ${r.right}/${r.total} · '
                    'kanji readings and spellings',
            },
            enabled: true,
            onTap: () => Navigator.of(
              context,
              rootNavigator: true,
            ).push(MaterialPageRoute(builder: (_) => const MockTestScreen())),
          ),
          _Tile(
            icon: Icons.quiz_outlined,
            title: 'Quiz',
            subtitle: 'Pick the meaning, then the word',
            enabled: words.length >= kMinQuizWords,
            onTap: () => open(QuizScreen(mangaId: _mangaId)),
          ),
          _Tile(
            icon: Icons.extension_outlined,
            title: 'Match',
            subtitle: 'Pair each word with its meaning',
            enabled: words.length >= kMinMatchWords,
            onTap: () => open(MatchScreen(mangaId: _mangaId)),
          ),
          _Tile(
            icon: Icons.sports_esports_outlined,
            title: 'Kanji Chain',
            subtitle: 'Slingshot game: fire parts together to build kanji',
            enabled: true,
            onTap: () => Navigator.of(
              context,
              rootNavigator: true,
            ).push(MaterialPageRoute(builder: (_) => const KanjiChainScreen())),
          ),
          const _Section(
            icon: Icons.edit_note_rounded,
            title: 'Writing',
            subtitle: 'Putting Japanese together',
          ),
          _Tile(
            icon: Icons.book_outlined,
            title: 'Diary',
            subtitle: 'Write in Japanese; check it offline, look words up',
            enabled: true,
            onTap: () => open(const DiaryScreen()),
          ),
          _Tile(
            icon: Icons.hub_outlined,
            title: 'Verb maps',
            subtitle: 'Every form of a verb, casual and polite, as a map',
            enabled: true,
            onTap: () => open(VerbListScreen(mangaId: _mangaId)),
          ),
          _Tile(
            icon: Icons.join_inner_rounded,
            title: 'Particles',
            subtitle: 'を, に, で… — which job, decided by the verb',
            enabled: true,
            onTap: () =>
                open(GrammarScreen(drill: Drill.particles, mangaId: _mangaId)),
          ),
          _Tile(
            icon: Icons.link_rounded,
            title: 'Joining words',
            subtitle: 'から, ても, たら… — each on its own verb form',
            enabled: true,
            onTap: () =>
                open(GrammarScreen(drill: Drill.joining, mangaId: _mangaId)),
          ),
          const _Section(
            icon: Icons.mic_none_rounded,
            title: 'Speaking',
            subtitle: 'Saying it out loud',
          ),
          _Tile(
            icon: Icons.mic_rounded,
            title: 'Shadowing',
            subtitle: switch (lib.speakingDueToday(_mangaId).total) {
              0 => 'Say it, compare with the voice, grade yourself',
              final n => '$n to say today · record, compare, grade',
            },
            enabled: words.isNotEmpty,
            onTap: () => Navigator.of(context, rootNavigator: true).push(
              MaterialPageRoute(
                builder: (_) => ShadowScreen(mangaId: _mangaId),
              ),
            ),
          ),
          _Tile(
            icon: Icons.chat_bubble_outline_rounded,
            title: 'Sentence shadowing',
            subtitle: 'Native sentences: your focus words, or N5 · N4 · N3',
            enabled: true,
            onTap: () => Navigator.of(context, rootNavigator: true).push(
              MaterialPageRoute(builder: (_) => const SentenceShadowScreen()),
            ),
          ),
          if (words.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                'Save words while reading (the + in the reader) and they show up here.',
                style: T.bodyMd.copyWith(color: C.textDim),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }
}

class _DeckChip extends StatelessWidget {
  const _DeckChip({required this.label, required this.on, required this.onTap});

  final String label;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: ChoiceChip(
      label: Text(label, style: T.pill.copyWith(color: on ? C.onLime : C.text)),
      selected: on,
      showCheckmark: false,
      selectedColor: C.lime,
      backgroundColor: C.surface,
      side: const BorderSide(color: C.border),
      shape: const StadiumBorder(),
      onSelected: (_) => onTap(),
    ),
  );
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Card(
    color: C.surface,
    elevation: 0,
    margin: EdgeInsets.zero,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: const BorderSide(color: C.border),
    ),
    child: Padding(padding: const EdgeInsets.all(20), child: child),
  );
}

/// What's due today and the button to study it — jlptbenkyo's due card,
/// with Anki's colours for the three counts.
class _DueCard extends StatelessWidget {
  const _DueCard({
    required this.label,
    required this.hint,
    required this.today,
    required this.deckSize,
    required this.learned,
    required this.onStart,
    this.emptyText = 'No flash cards yet.',
  });

  final String label;
  final String hint;
  final DueCounts today;
  final int deckSize;
  final int learned;
  final VoidCallback onStart;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(label, style: T.bodyLg)),
              if (deckSize > 0)
                Text(
                  '$learned / $deckSize learned',
                  style: T.bodyMd.copyWith(color: C.textDim, fontSize: 12),
                ),
            ],
          ),
          Text(hint, style: T.bodyMd.copyWith(color: C.inactive, fontSize: 12)),
          const SizedBox(height: 12),
          if (today.total == 0)
            Row(
              children: [
                const Icon(
                  Icons.check_circle_outline_rounded,
                  size: 24,
                  color: C.lime,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    deckSize == 0
                        ? emptyText
                        : 'Done for today — nothing due right now.',
                    style: T.bodyMd,
                  ),
                ),
              ],
            )
          else ...[
            Row(
              children: [
                _Count('${today.newCards}', 'new', Srs.newCards),
                _Count('${today.learning}', 'learning', Srs.learning),
                _Count('${today.review}', 'review', Srs.review),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: C.lime,
                  foregroundColor: C.onLime,
                  minimumSize: const Size(0, 52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  textStyle: T.pill.copyWith(fontSize: 16),
                ),
                onPressed: onStart,
                child: Text('Study ${today.total}'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Count extends StatelessWidget {
  const _Count(this.value, this.label, this.colour);

  final String value, label;
  final Color colour;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: T.headlineLg.copyWith(
            fontSize: 30,
            color: colour,
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(label, style: T.bodyMd.copyWith(color: C.textDim, fontSize: 12)),
      ],
    ),
  );
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final String title, subtitle;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: C.surface,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: C.border),
      ),
      child: ListTile(
        enabled: enabled,
        leading: Icon(icon, color: enabled ? C.lime : C.inactive),
        title: Text(title, style: T.bodyLg),
        subtitle: Text(subtitle, style: T.bodyMd.copyWith(color: C.textDim)),
        trailing: const Icon(Icons.chevron_right_rounded, color: C.textDim),
        onTap: onTap,
      ),
    );
  }
}

/// The focus set at a glance, and the way into choosing it.
class _FocusPanel extends StatelessWidget {
  const _FocusPanel({
    required this.count,
    required this.learned,
    required this.onChoose,
  });

  final int count;
  final int learned;
  final VoidCallback onChoose;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Row(
        children: [
          const Text('🎯', style: TextStyle(fontSize: 26)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  count == 0
                      ? 'Focus on a few at a time'
                      : 'Focus: $count words',
                  style: T.bodyLg.copyWith(fontWeight: FontWeight.w700),
                ),
                Text(
                  count == 0
                      ? 'Choose 20 words to study, then the next 20.'
                      : '$learned learned · the rest of your words wait',
                  style: T.bodyMd.copyWith(color: C.textDim, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: C.lime,
              side: const BorderSide(color: C.lime),
            ),
            onPressed: onChoose,
            child: Text(count == 0 ? 'Choose' : 'Edit'),
          ),
        ],
      ),
    );
  }
}

/// A heading over one group of practice: Writing, Listening, Speaking.
class _Section extends StatelessWidget {
  const _Section({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
    child: Row(
      children: [
        Icon(icon, color: C.lime, size: 22),
        const SizedBox(width: 10),
        Text(title, style: T.headlineMd.copyWith(fontSize: 20)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: T.bodyMd.copyWith(color: C.textDim, fontSize: 12),
          ),
        ),
      ],
    ),
  );
}
