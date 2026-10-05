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
import 'flashcards_screen.dart';
import 'match_screen.dart';
import 'quiz_screen.dart';

GameCard gameCardOf(Word w) => GameCard(
  id: w.id,
  japanese: w.entry.word,
  reading: w.entry.reading,
  meaning: w.entry.shortMeaning,
);

/// Flash cards run full screen, above the dock, as a review does in Anki.
void openFlashcards(BuildContext context, String? mangaId) => Navigator.of(
  context,
  rootNavigator: true,
).push(MaterialPageRoute(builder: (_) => FlashcardsScreen(mangaId: mangaId)));

class StudyScreen extends StatefulWidget {
  const StudyScreen({super.key});

  @override
  State<StudyScreen> createState() => _StudyScreenState();
}

class _StudyScreenState extends State<StudyScreen> {
  /// Null = all words.
  String? _mangaId;

  @override
  Widget build(BuildContext context) {
    final lib = AppScope.library(context);
    if (_mangaId != null && lib.mangaById(_mangaId!) == null) _mangaId = null;
    final words = lib.wordsFor(_mangaId);
    final today = lib.dueToday(_mangaId);
    final learned = lib.learnedCount(_mangaId);
    final withWords = lib.recent
        .where((m) => lib.wordsFor(m.id).isNotEmpty)
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
                _DeckChip(
                  label: 'All words',
                  on: _mangaId == null,
                  onTap: () => setState(() => _mangaId = null),
                ),
                for (final m in withWords)
                  _DeckChip(
                    label: m.title,
                    on: _mangaId == m.id,
                    onTap: () => setState(() => _mangaId = m.id),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _DueCard(
            today: today,
            deckSize: words.length,
            onStart: () => openFlashcards(context, _mangaId),
          ),
          const SizedBox(height: 8),
          _Panel(
            child: _ProgressRow(
              label: 'Words learned',
              learned: learned,
              total: words.length,
            ),
          ),
          const SizedBox(height: 20),
          Text('Practice', style: T.pill.copyWith(color: C.textDim)),
          const SizedBox(height: 8),
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
    required this.today,
    required this.deckSize,
    required this.onStart,
  });

  final DueCounts today;
  final int deckSize;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (today.total == 0)
            Row(
              children: [
                const Icon(
                  Icons.check_circle_outline_rounded,
                  size: 28,
                  color: C.lime,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    deckSize == 0
                        ? 'No flash cards yet.'
                        : 'Done for today — nothing due right now.',
                    style: T.bodyLg,
                  ),
                ),
              ],
            )
          else ...[
            Text('Due today', style: T.pill.copyWith(color: C.textDim)),
            const SizedBox(height: 12),
            Row(
              children: [
                _Count('${today.newCards}', 'new', Srs.newCards),
                _Count('${today.learning}', 'learning', Srs.learning),
                _Count('${today.review}', 'review', Srs.review),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: C.lime,
                  foregroundColor: C.onLime,
                  minimumSize: const Size(0, 56),
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

class _ProgressRow extends StatelessWidget {
  const _ProgressRow({
    required this.label,
    required this.learned,
    required this.total,
  });

  final String label;
  final int learned;
  final int total;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: T.bodyLg),
          Text('$learned / $total', style: T.bodyMd.copyWith(color: C.textDim)),
        ],
      ),
      const SizedBox(height: 8),
      ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(
          value: total == 0 ? 0 : learned / total,
          minHeight: 8,
          backgroundColor: C.track,
          color: C.lime,
        ),
      ),
      const SizedBox(height: 6),
      Text(
        'Learned = reached a week between reviews.',
        style: T.bodyMd.copyWith(color: C.inactive, fontSize: 11),
      ),
    ],
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
