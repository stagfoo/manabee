/// Flash cards. Front: furigana, the word, romaji. Tap to flip. Back: the
/// full entry, with 👍 / 👎 to grade — which is what moves a card between
/// Leitner boxes (core/srs.dart). The arrows on the front browse without
/// grading.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/srs.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/entry_detail.dart';

class FlashcardsScreen extends StatefulWidget {
  const FlashcardsScreen({super.key, this.mangaId});

  final String? mangaId;

  @override
  State<FlashcardsScreen> createState() => _FlashcardsScreenState();
}

class _FlashcardsScreenState extends State<FlashcardsScreen> {
  late List<String> _order;
  int _index = 0;
  bool _flipped = false;

  @override
  void initState() {
    super.initState();
    // The order is fixed for the session; re-sorting after every answer
    // would move the card you're on.
    final words = AppScope.read(context).wordsFor(widget.mangaId);
    _order = [
      for (final w in studyOrder(words, (w) => w.review, DateTime.now())) w.id,
    ];
  }

  void _go(int delta) => setState(() {
    _index = (_index + delta).clamp(0, _order.length);
    _flipped = false;
  });

  void _answer(Word w, bool knewIt) {
    AppScope.read(context).answer(w, knewIt: knewIt);
    _go(1);
  }

  @override
  Widget build(BuildContext context) {
    final lib = AppScope.library(context);
    final byId = {for (final w in lib.wordsFor(widget.mangaId)) w.id: w};
    _order = _order.where(byId.containsKey).toList();
    final all = byId.values;
    final ups = all.where((w) => w.review.known).length;
    final downs = all.length - ups;
    final done = _index >= _order.length;
    final word = done ? null : byId[_order[_index]];

    return GridScaffold(
      header: false,
      body: Padding(
        padding: const EdgeInsets.fromLTRB(28, 16, 28, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'FLASH CARDS',
                      style: T.headlineMd.copyWith(
                        letterSpacing: 4,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.maybePop(context),
                  icon: const Icon(Icons.close_rounded, color: C.textDim),
                ),
              ],
            ),
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: '$ups'),
                  const TextSpan(text: '👍', style: TextStyle(fontSize: 24)),
                  TextSpan(text: ' / $downs'),
                  const TextSpan(text: '👎', style: TextStyle(fontSize: 24)),
                ],
              ),
              style: T.headlineMd,
            ),
            const SizedBox(height: 28),
            if (done || word == null)
              Expanded(
                child: EmptyState(
                  emoji: '🎉',
                  title: 'Deck done',
                  body:
                      '${lib.dueWords(widget.mangaId)} still due. Come back tomorrow for the next round.',
                  action: LimeButton(
                    label: 'Go again',
                    onPressed: () => setState(() {
                      final words = lib.wordsFor(widget.mangaId);
                      _order = [
                        for (final w in studyOrder(
                          words,
                          (w) => w.review,
                          DateTime.now(),
                        ))
                          w.id,
                      ];
                      _index = 0;
                    }),
                  ),
                ),
              )
            else ...[
              // Square when there's room, smaller when there isn't — a
              // short landscape screen can't fit a full-width square.
              Expanded(
                child: Center(
                  child: AspectRatio(
                    aspectRatio: 1.0,
                    child: GestureDetector(
                      onTap: () => setState(() => _flipped = !_flipped),
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(end: _flipped ? math.pi : 0),
                        duration: const Duration(milliseconds: 380),
                        curve: Curves.easeInOutCubic,
                        builder: (context, angle, _) {
                          final showBack = angle > math.pi / 2;
                          return Transform(
                            alignment: Alignment.center,
                            transform: Matrix4.identity()
                              ..setEntry(3, 2, 0.0012)
                              ..rotateY(angle),
                            child: showBack
                                ? Transform(
                                    alignment: Alignment.center,
                                    transform: Matrix4.identity()
                                      ..rotateY(math.pi),
                                    child: _Back(word),
                                  )
                                : _Front(word),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 28),
              _flipped
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _Thumb('👍', () => _answer(word, true)),
                        Text(
                          '${_index + 1}/${_order.length}',
                          style: T.headlineMd.copyWith(
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        _Thumb('👎', () => _answer(word, false)),
                      ],
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _Arrow(
                          Icons.arrow_back_rounded,
                          _index > 0 ? () => _go(-1) : null,
                        ),
                        Text(
                          '${_index + 1}/${_order.length}',
                          style: T.headlineMd.copyWith(
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        _Arrow(Icons.arrow_forward_rounded, () => _go(1)),
                      ],
                    ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Front extends StatelessWidget {
  const _Front(this.word);

  final Word word;

  @override
  Widget build(BuildContext context) {
    final e = word.entry;
    return Container(
      decoration: BoxDecoration(
        color: C.violet,
        borderRadius: BorderRadius.circular(24),
        border: const Border(
          bottom: BorderSide(color: Color(0x4D000000), width: 2),
        ),
      ),
      child: Stack(
        children: [
          const Positioned(
            top: 16,
            right: 16,
            child: Icon(Icons.u_turn_left_rounded, color: Colors.white),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (e.hasKanji)
                      Text(e.reading, style: T.jp.copyWith(fontSize: 18)),
                    Text(
                      e.word,
                      style: T.jp.copyWith(
                        fontSize: 44,
                        fontWeight: FontWeight.w800,
                        height: 1.25,
                      ),
                    ),
                    Text(e.romaji, style: T.headlineXl.copyWith(fontSize: 40)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Back extends StatelessWidget {
  const _Back(this.word);

  final Word word;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF26262B),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Stack(
        children: [
          const Positioned(
            top: 16,
            right: 16,
            child: Icon(
              Icons.subdirectory_arrow_right_rounded,
              color: Colors.white,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 44, 18, 18),
            child: SingleChildScrollView(
              child: EntryDetail(word.entry, context_: word.context),
            ),
          ),
        ],
      ),
    );
  }
}

class _Arrow extends StatelessWidget {
  const _Arrow(this.icon, this.onTap);

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Opacity(
    opacity: onTap == null ? 0.4 : 1,
    child: Material(
      color: C.violet,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Icon(icon, color: Colors.black, size: 24),
        ),
      ),
    ),
  );
}

class _Thumb extends StatelessWidget {
  const _Thumb(this.emoji, this.onTap);

  final String emoji;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkResponse(
    onTap: onTap,
    radius: 36,
    child: Padding(
      padding: const EdgeInsets.all(6),
      child: Text(emoji, style: const TextStyle(fontSize: 48)),
    ),
  );
}
