/// The pieces of an Anki-style review shared by flash cards and
/// shadowing: the new + learning + review count, the four grade buttons
/// with their intervals, the big button, and the end-of-session message.
library;

import 'package:flutter/material.dart';

import '../core/srs.dart';
import '../theme.dart';

/// Anki's "12 + 3 + 20": new, learning, review, with the count the current
/// card belongs to underlined.
class SrsCounts extends StatelessWidget {
  const SrsCounts({
    super.key,
    required this.newCards,
    required this.learning,
    required this.review,
    required this.current,
  });

  final int newCards;
  final int learning;
  final int review;
  final ReviewState current;

  @override
  Widget build(BuildContext context) {
    TextSpan count(int n, Color colour, bool on) => TextSpan(
      text: '$n',
      style: TextStyle(
        color: colour,
        fontWeight: FontWeight.w700,
        decoration: on ? TextDecoration.underline : null,
        decorationColor: colour,
        decorationThickness: 2.5,
      ),
    );
    const plus = TextSpan(
      text: '  +  ',
      style: TextStyle(color: C.inactive),
    );
    return Text.rich(
      TextSpan(
        children: [
          count(newCards, Srs.newCards, current.isNew),
          plus,
          count(learning, Srs.learning, current.isLearning),
          plus,
          count(review, Srs.review, current.isReview),
        ],
      ),
      style: T.bodyLg.copyWith(fontSize: 18),
    );
  }
}

/// Again · Hard · Good · Easy, each labelled with where the card lands.
/// Big targets: a mis-tap here costs a card weeks of schedule.

class GradeRow extends StatelessWidget {
  const GradeRow({
    super.key,
    required this.previews,
    required this.now,
    required this.onGrade,
  });

  final Map<Grade, ReviewState> previews;
  final DateTime now;
  final ValueChanged<Grade> onGrade;

  static const buttons = {
    Grade.again: ('Again', Srs.again),
    Grade.hard: ('Hard', Srs.hard),
    Grade.good: ('Good', Srs.good),
    Grade.easy: ('Easy', Srs.easy),
  };

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final g in Grade.values) ...[
          if (g != Grade.again) const SizedBox(width: 8),
          Expanded(
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: buttons[g]!.$2,
                foregroundColor: Colors.white,
                minimumSize: const Size(0, 60),
                padding: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: () => onGrade(g),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      buttons[g]!.$1,
                      style: T.pill.copyWith(color: Colors.white, fontSize: 16),
                    ),
                    Text(
                      formatInterval(previews[g]!.due!.difference(now)),
                      style: T.bodyMd.copyWith(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class BigButton extends StatelessWidget {
  const BigButton({super.key, required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: FilledButton(
      style: FilledButton.styleFrom(
        backgroundColor: C.lime,
        foregroundColor: C.onLime,
        minimumSize: const Size(0, 60),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: T.pill.copyWith(fontSize: 16),
      ),
      onPressed: onPressed,
      child: Text(label),
    ),
  );
}

class DoneMessage extends StatelessWidget {
  const DoneMessage({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    this.actions = const [],
  });

  final IconData icon;
  final String title;
  final String body;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: C.lime),
            const SizedBox(height: 16),
            Text(title, style: T.headlineLg, textAlign: TextAlign.center),
            if (body.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                body,
                style: T.bodyMd.copyWith(color: C.textDim),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 24),
            ...actions,
          ],
        ),
      ),
    );
  }
}

/// The square speaker beside Show answer — the 10 of a 90/10 row, as tall
/// as the button so the two read as one control.
