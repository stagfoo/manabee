/// The Study tab: pick a deck (every word, or one manga's), then flash
/// cards, the quiz, or the matching game.
library;

import 'package:flutter/material.dart';

import '../core/games.dart';
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
          Text('STUDY', style: T.headlineMd.copyWith(letterSpacing: 4)),
          const SizedBox(height: 12),
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
          Row(
            children: [
              _Stat(label: 'NEW', value: '${today.newCards}', color: C.violet),
              _Stat(
                label: 'LEARNING',
                value: '${today.learning}',
                color: C.danger,
              ),
              _Stat(label: 'REVIEW', value: '${today.review}', color: C.mint),
              _Stat(label: 'LEARNED', value: '$learned/${words.length}'),
            ],
          ),
          const SizedBox(height: 20),
          _GameCard(
            title: 'Flash Cards',
            subtitle: today.total > 0
                ? '${today.total} to study today · Again / Hard / Good / Easy'
                : 'All caught up · next reviews come back on their own',
            emoji: '🃏',
            color: C.violet,
            enabled: words.isNotEmpty,
            onTap: () => open(FlashcardsScreen(mangaId: _mangaId)),
          ),
          _GameCard(
            title: 'Quiz',
            subtitle: 'Practice — pick the meaning, then the word',
            emoji: '❓',
            color: C.lime,
            dark: true,
            enabled: words.length >= kMinQuizWords,
            onTap: () => open(QuizScreen(mangaId: _mangaId)),
          ),
          _GameCard(
            title: 'Match',
            subtitle: 'Practice — pair each word with its meaning',
            emoji: '🧩',
            color: C.mint,
            dark: true,
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

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, this.color = C.text});

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      margin: const EdgeInsets.symmetric(horizontal: 3),
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: C.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: C.border),
      ),
      child: Column(
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(value, style: T.headlineLg.copyWith(color: color)),
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(label, style: T.monoSm),
          ),
        ],
      ),
    ),
  );
}

class _GameCard extends StatelessWidget {
  const _GameCard({
    required this.title,
    required this.subtitle,
    required this.emoji,
    required this.color,
    required this.enabled,
    required this.onTap,
    this.dark = false,
  });

  final String title;
  final String subtitle;
  final String emoji;
  final Color color;
  final bool enabled;
  final bool dark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = dark ? C.onLime : C.text;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Opacity(
        opacity: enabled ? 1 : 0.35,
        child: Material(
          color: color,
          borderRadius: BorderRadius.circular(24),
          child: InkWell(
            onTap: enabled ? onTap : null,
            borderRadius: BorderRadius.circular(24),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: T.headlineMd.copyWith(color: fg, fontSize: 22),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: T.bodyMd.copyWith(
                            color: fg.withValues(alpha: 0.75),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(emoji, style: const TextStyle(fontSize: 40)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
