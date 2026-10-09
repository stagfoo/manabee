/// Kanji Chain: pull back the slingshot and fire a kanji part into the
/// part it combines with — 日 into 月 makes 明. What you build stays on
/// the board, so 木 into 木 makes 林 and another 木 into that makes 森.
///
/// The rules are core/kanji_chain.dart and the physics core/slingshot.dart;
/// this screen runs the clock, takes the drag, and draws.
library;

import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../core/kanji_chain.dart';
import '../core/slingshot.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/confetti.dart';

/// The combinations, loaded once (assets/kanji/combos.json, built by
/// tool/build_kanji_combos.py from KanjiVG and KANJIDIC).
Future<ComboBook>? _book;
Future<ComboBook> loadComboBook() => _book ??= rootBundle
    .loadString('assets/kanji/combos.json')
    .then(
      (s) => ComboBook([
        for (final j in (jsonDecode(s) as Map)['combos'] as List)
          Combo.fromJson(j as Map<String, dynamic>),
      ]),
    );

class KanjiChainScreen extends StatefulWidget {
  const KanjiChainScreen({super.key, this.book, this.seed, this.onStart});

  /// For tests: a ready book and a fixed seed instead of the asset and
  /// the clock, and each new game handed over as it starts.
  final ComboBook? book;
  final int? seed;
  final ValueChanged<ChainGame>? onStart;

  @override
  State<KanjiChainScreen> createState() => _KanjiChainScreenState();
}

class _KanjiChainScreenState extends State<KanjiChainScreen>
    with SingleTickerProviderStateMixin {
  ChainGame? _game;
  late final Ticker _ticker;
  Duration _lastTick = Duration.zero;
  double _t = 0;
  Size _size = Size.zero;

  Offset? _pullTo;
  Offset? _shotPos;
  Offset? _shotVel;

  /// The last merge, shown for a moment, and when.
  Combo? _announce;
  double _announceAt = 0;

  /// A slot that was hit with the wrong part, shaken for a moment.
  int? _wrongSlot;
  double _wrongAt = 0;

  static const double _targetSize = 64;
  static const double _ammoSize = 60;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_tick)..start();
    _start();
  }

  Future<void> _start() async {
    final book = widget.book ?? await loadComboBook();
    if (!mounted) return;
    final game = ChainGame(book, Random(widget.seed));
    widget.onStart?.call(game);
    setState(() {
      _game = game;
      _shotPos = null;
      _announce = null;
    });
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  /// The slingshot sits high enough that a full pull stays on screen.
  Offset get _origin => Offset(_size.width / 2, _size.height * 0.7);

  List<Offset?> get _slots {
    final g = _game;
    if (g == null) return const [];
    return [
      for (var i = 0; i < g.board.length; i++)
        g.board[i] == null ? null : slotPosition(i, g.board.length, _size, _t),
    ];
  }

  void _tick(Duration elapsed) {
    final dt = ((elapsed - _lastTick).inMicroseconds / 1e6).clamp(0.0, 0.05);
    _lastTick = elapsed;
    _t += dt;
    final g = _game;
    if (g != null && _shotPos != null && _shotVel != null && !_size.isEmpty) {
      final (p, v) = step(_shotPos!, _shotVel!, dt, _size, _ammoSize / 2);
      _shotPos = p;
      _shotVel = v;
      final i = hitTarget(p, _slots, (_targetSize + _ammoSize) / 2 * 0.8);
      if (i != null) {
        final r = g.hit(i);
        _shotPos = null;
        if (r == ShotResult.merged) {
          HapticFeedback.mediumImpact();
          _announce = g.last;
          _announceAt = _t;
        } else {
          HapticFeedback.heavyImpact();
          _wrongSlot = i;
          _wrongAt = _t;
        }
      } else if (offscreen(p, _size, _ammoSize)) {
        g.miss();
        _shotPos = null;
        HapticFeedback.heavyImpact();
      }
    }
    if (mounted) setState(() {});
  }

  void _release() {
    final pull = _pullTo;
    _pullTo = null;
    if (pull == null || _game == null || _game!.over) return;
    final v = launchVelocity(pull - _origin);
    if (v == null) return;
    _shotPos = _origin;
    _shotVel = v;
  }

  @override
  Widget build(BuildContext context) {
    final g = _game;
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
        title: Text('Kanji Chain', style: T.headlineMd),
        actions: [
          if (g != null) ...[
            Text(
              List.generate(3, (i) => i < g.hearts ? '❤️' : '🤍').join(),
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(width: 12),
            Text(
              '${g.score}',
              style: T.monoBold.copyWith(color: C.lime, fontSize: 18),
            ),
            const SizedBox(width: 16),
          ],
        ],
      ),
      body: g == null
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(
              builder: (context, box) {
                _size = Size(box.maxWidth, box.maxHeight);
                return Stack(
                  children: [
                    const Positioned.fill(
                      child: CustomPaint(painter: GridPainter()),
                    ),
                    Positioned.fill(
                      child: GestureDetector(
                        key: const ValueKey('play-area'),
                        behavior: HitTestBehavior.opaque,
                        onPanStart: (d) {
                          if (_shotPos != null || g.over) return;
                          setState(
                            () => _pullTo = clampPull(_origin, d.localPosition),
                          );
                        },
                        onPanUpdate: (d) {
                          if (_pullTo == null) return;
                          setState(
                            () => _pullTo = clampPull(_origin, d.localPosition),
                          );
                        },
                        onPanEnd: (_) => _release(),
                        child: CustomPaint(
                          painter: _SlingPainter(
                            origin: _origin,
                            pull: _shotPos == null ? _pullTo : null,
                          ),
                        ),
                      ),
                    ),
                    for (var i = 0; i < g.board.length; i++)
                      if (g.board[i] != null) _target(g, i),
                    _ammo(g),
                    if (_announce != null && _t - _announceAt < 2.2)
                      _announcement(_announce!, _t - _announceAt),
                    if (g.chain >= 2 && !g.over)
                      Positioned(
                        bottom: 16,
                        left: 0,
                        right: 0,
                        child: Center(child: _ChainBadge(g.chain)),
                      ),
                    // The hint sits at the top, clear of the pulled band.
                    Positioned(
                      left: 0,
                      right: 0,
                      top: 6,
                      child: Text(
                        g.over
                            ? ''
                            : 'Pull back and fire ${g.ammo} at a part it combines with',
                        textAlign: TextAlign.center,
                        style: T.bodyMd.copyWith(
                          color: C.textDim,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    if (g.over) Positioned.fill(child: _gameOver(g)),
                  ],
                );
              },
            ),
    );
  }

  Widget _target(ChainGame g, int i) {
    final t = g.board[i]!;
    var p = slotPosition(i, g.board.length, _size, _t);
    if (_wrongSlot == i && _t - _wrongAt < 0.4) {
      p += Offset(sin((_t - _wrongAt) * 60) * 6, 0);
    }
    return Positioned(
      left: p.dx - _targetSize / 2,
      top: p.dy - _targetSize / 2,
      child: _Disc(
        glyph: t.glyph,
        size: _targetSize,
        fill: t.made ? const Color(0xFF1E2A10) : C.surface,
        ring: t.made ? C.lime : C.ghostBorder,
        text: C.text,
      ),
    );
  }

  Widget _ammo(ChainGame g) {
    final at = _shotPos ?? _pullTo ?? _origin;
    return Positioned(
      left: at.dx - _ammoSize / 2,
      top: at.dy - _ammoSize / 2,
      child: IgnorePointer(
        child: _Disc(
          glyph: g.ammo,
          size: _ammoSize,
          fill: C.lime,
          ring: C.lime,
          text: C.onLime,
        ),
      ),
    );
  }

  Widget _announcement(Combo c, double age) {
    final fade = age < 1.8 ? 1.0 : (2.2 - age) / 0.4;
    final readings = [...c.on, ...c.kun].take(3).join(' · ');
    return Positioned(
      left: 16,
      right: 16,
      top: _size.height * 0.44,
      child: IgnorePointer(
        child: Opacity(
          opacity: fade.clamp(0.0, 1.0),
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            decoration: BoxDecoration(
              color: C.elevated,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: C.lime),
              boxShadow: [
                BoxShadow(
                  color: C.lime.withValues(alpha: 0.25),
                  blurRadius: 18,
                ),
              ],
            ),
            child: Row(
              children: [
                Text(c.kanji, style: Jp.word.copyWith(fontSize: 46)),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${c.a} + ${c.b}',
                        style: T.jp.copyWith(color: C.textDim, fontSize: 15),
                      ),
                      Text(
                        c.meanings.take(2).join(', '),
                        style: T.bodyLg.copyWith(fontWeight: FontWeight.w700),
                      ),
                      if (readings.isNotEmpty)
                        Text(
                          readings,
                          style: T.jp.copyWith(color: C.lime, fontSize: 13),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _gameOver(ChainGame g) {
    return Container(
      color: const Color(0xE60D0D11),
      child: Stack(
        children: [
          if (g.made.length >= 5) const Positioned.fill(child: Confetti()),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    g.made.isEmpty
                        ? 'Out of hearts'
                        : 'You built ${g.made.length} kanji',
                    textAlign: TextAlign.center,
                    style: T.headlineLg,
                  ),
                  Text(
                    'Score ${g.score}',
                    textAlign: TextAlign.center,
                    style: T.monoBold.copyWith(color: C.lime, fontSize: 16),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView(
                      children: [
                        for (final c in g.made)
                          ListTile(
                            leading: Text(
                              c.kanji,
                              style: T.jp.copyWith(
                                fontSize: 30,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            title: Text(
                              c.meanings.take(2).join(', '),
                              style: T.bodyLg,
                            ),
                            subtitle: Text(
                              '${c.a} + ${c.b}   ${[...c.on, ...c.kun].take(2).join(' · ')}',
                              style: T.jp.copyWith(
                                color: C.textDim,
                                fontSize: 13,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  LimeButton(label: 'Play again', onPressed: _start),
                  const SizedBox(height: 8),
                  GhostButton(
                    label: 'Done',
                    onPressed: () => Navigator.maybePop(context),
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

class _Disc extends StatelessWidget {
  const _Disc({
    required this.glyph,
    required this.size,
    required this.fill,
    required this.ring,
    required this.text,
  });

  final String glyph;
  final double size;
  final Color fill;
  final Color ring;
  final Color text;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: fill,
      shape: BoxShape.circle,
      border: Border.all(color: ring, width: 2.5),
    ),
    child: Text(
      glyph,
      style: T.jp.copyWith(
        fontSize: size * 0.5,
        fontWeight: FontWeight.w700,
        color: text,
        height: 1.1,
      ),
    ),
  );
}

/// The slingshot's posts and band, and a dotted aim line while pulling.
class _SlingPainter extends CustomPainter {
  _SlingPainter({required this.origin, this.pull});

  final Offset origin;
  final Offset? pull;

  @override
  void paint(Canvas canvas, Size size) {
    final left = origin + const Offset(-44, 0);
    final right = origin + const Offset(44, 0);
    final post = Paint()
      ..color = C.ghostBorder
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(left, left + const Offset(8, 70), post);
    canvas.drawLine(right, right + const Offset(-8, 70), post);
    final band = Paint()
      ..color = C.lime.withValues(alpha: 0.8)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    final at = pull ?? origin;
    canvas.drawLine(left, at, band);
    canvas.drawLine(right, at, band);

    if (pull != null) {
      final v = launchVelocity(pull! - origin);
      if (v != null) {
        final dir = v / v.distance;
        final dot = Paint()..color = C.lime.withValues(alpha: 0.6);
        for (var k = 1; k <= 12; k++) {
          canvas.drawCircle(origin + dir * (k * 26.0), 3, dot);
        }
      }
    }
  }

  @override
  bool shouldRepaint(_SlingPainter old) =>
      old.pull != pull || old.origin != origin;
}

/// "chain ×3", under the slingshot while a chain is going.
class _ChainBadge extends StatelessWidget {
  const _ChainBadge(this.chain);

  final int chain;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
    decoration: BoxDecoration(
      color: C.mint.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: C.mint),
    ),
    child: Text(
      'chain ×$chain',
      style: T.monoBold.copyWith(color: C.mint, fontSize: 14),
    ),
  );
}
