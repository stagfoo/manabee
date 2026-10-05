/// Pair matching: Japanese tiles and meaning tiles, shuffled together. Tap
/// one of each; a pair from the same word clears. Timed and counts
/// misses, so a replay has something to beat.
library;

import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/games.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'study_screen.dart';

class MatchScreen extends StatefulWidget {
  const MatchScreen({super.key, this.mangaId});

  final String? mangaId;

  @override
  State<MatchScreen> createState() => _MatchScreenState();
}

class _MatchScreenState extends State<MatchScreen> {
  late MatchGame _game;
  final _watch = Stopwatch();
  Timer? _ticker;
  int? _flash;

  @override
  void initState() {
    super.initState();
    _deal();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _deal() {
    final words = AppScope.read(context).wordsFor(widget.mangaId);
    _game = MatchGame.deal([for (final w in words) gameCardOf(w)], Random());
    _watch
      ..reset()
      ..start();
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  void _tap(int i) {
    switch (_game.tap(i)) {
      case MatchResult.matched:
        HapticFeedback.lightImpact();
      case MatchResult.mismatched:
        HapticFeedback.heavyImpact();
        // Briefly show which tile was the wrong partner.
        _flash = i;
        Future.delayed(const Duration(milliseconds: 450), () {
          if (mounted && _flash == i) setState(() => _flash = null);
        });
      default:
        break;
    }
    if (_game.finished) {
      _watch.stop();
      _ticker?.cancel();
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final secs = _watch.elapsed.inSeconds;
    return GridScaffold(
      header: false,
      body: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'MATCH',
                      style: T.headlineMd.copyWith(
                        letterSpacing: 4,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                Text(
                  '${secs ~/ 60}:${(secs % 60).toString().padLeft(2, '0')}',
                  style: T.monoBold.copyWith(color: C.lime, fontSize: 14),
                ),
                const SizedBox(width: 12),
                Text(
                  '✗ ${_game.mistakes}',
                  style: T.monoBold.copyWith(color: C.danger, fontSize: 14),
                ),
                IconButton(
                  onPressed: () => Navigator.maybePop(context),
                  icon: const Icon(Icons.close_rounded, color: C.textDim),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_game.tiles.length < 4)
              const Expanded(
                child: EmptyState(
                  emoji: '🤔',
                  title: 'Not enough words',
                  body: 'Save a few more words with different meanings.',
                ),
              )
            else if (_game.finished)
              Expanded(
                child: EmptyState(
                  emoji: _game.mistakes == 0 ? '🏆' : '🎉',
                  title: 'Cleared in ${secs}s',
                  body: _game.mistakes == 0
                      ? 'Not a single miss.'
                      : '${_game.mistakes} misses.',
                  action: LimeButton(
                    label: 'Play again',
                    onPressed: () => setState(_deal),
                  ),
                ),
              )
            else
              Expanded(
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 0.9,
                  ),
                  itemCount: _game.tiles.length,
                  itemBuilder: (context, i) => _Tile(
                    tile: _game.tiles[i],
                    cleared: _game.cleared.contains(i),
                    selected: _game.selected == i,
                    wrong: _flash == i,
                    onTap: () => _tap(i),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.tile,
    required this.cleared,
    required this.selected,
    required this.wrong,
    required this.onTap,
  });

  final MatchTile tile;
  final bool cleared;
  final bool selected;
  final bool wrong;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final jp = tile.side == TileSide.japanese;
    final base = jp ? C.violet : C.surface;
    final bg = wrong
        ? C.danger
        : selected
        ? C.lime
        : base;
    final fg = wrong || selected ? Colors.black : C.text;
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 250),
      opacity: cleared ? 0 : 1,
      child: IgnorePointer(
        ignoring: cleared,
        child: Material(
          color: bg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: jp ? Colors.transparent : C.ghostBorder,
              width: 1.5,
            ),
          ),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Center(
                child: Text(
                  tile.label,
                  textAlign: TextAlign.center,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: jp
                      ? T.jp.copyWith(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: fg,
                          height: 1.25,
                        )
                      : T.bodyMd.copyWith(
                          color: fg,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
