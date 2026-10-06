/// A one-shot burst of confetti, for finishing something.
///
/// Drawn by hand rather than pulled in as a package: it's a few dozen
/// rectangles falling under gravity, and a dependency for that would be
/// one more thing to break on the next Android toolchain bump.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';

class Confetti extends StatefulWidget {
  const Confetti({super.key, this.pieces = 90, this.seed});

  /// More for a bigger occasion (a perfect quiz).
  final int pieces;
  final int? seed;

  @override
  State<Confetti> createState() => _ConfettiState();
}

class _ConfettiState extends State<Confetti>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3200),
  )..forward();
  late final List<_Piece> _pieces;

  static const _colours = [
    C.lime,
    C.violet,
    C.mint,
    Colors.white,
    Color(0xFFFF6FB5),
    Color(0xFF42A5F5),
  ];

  @override
  void initState() {
    super.initState();
    final r = math.Random(widget.seed);
    _pieces = List.generate(widget.pieces, (_) {
      // Two cannons, bottom left and bottom right, firing up and inward.
      final left = r.nextBool();
      final angle = (left ? -1 : 1) * (0.15 + r.nextDouble() * 0.45);
      final speed = 1.6 + r.nextDouble() * 0.8;
      return _Piece(
        x0: left ? 0.0 : 1.0,
        vx: (left ? 1 : -1) * math.sin(angle).abs() * speed,
        vy: -math.cos(angle).abs() * speed,
        spin: (r.nextDouble() - 0.5) * 18,
        wobble: r.nextDouble() * math.pi * 2,
        size: 6 + r.nextDouble() * 6,
        colour: _colours[r.nextInt(_colours.length)],
        delay: r.nextDouble() * 0.15,
      );
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) => CustomPaint(
          size: Size.infinite,
          painter: _ConfettiPainter(_pieces, _c.value),
        ),
      ),
    );
  }
}

class _Piece {
  _Piece({
    required this.x0,
    required this.vx,
    required this.vy,
    required this.spin,
    required this.wobble,
    required this.size,
    required this.colour,
    required this.delay,
  });

  final double x0, vx, vy, spin, wobble, size, delay;
  final Color colour;
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.pieces, this.t);

  final List<_Piece> pieces;
  final double t;

  static const _gravity = 2.8;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (final p in pieces) {
      final local = ((t - p.delay) / (1 - p.delay)).clamp(0.0, 1.0);
      if (local <= 0) continue;
      final s = local * 1.6;
      // Launched from the bottom corners, in units of the screen size.
      final x = p.x0 + p.vx * s * 0.55 + math.sin(p.wobble + s * 6) * 0.02;
      final y = 1.0 + p.vy * s + 0.5 * _gravity * s * s;
      if (y > 1.1) continue;
      final fade = local > 0.8 ? (1 - local) / 0.2 : 1.0;
      paint.color = p.colour.withValues(alpha: fade);
      canvas
        ..save()
        ..translate(x * size.width, y * size.height)
        ..rotate(p.spin * s)
        // Flat paper turning over: the width breathes.
        ..scale(math.cos(p.wobble + s * 8).abs() * 0.8 + 0.2, 1)
        ..drawRect(
          Rect.fromCenter(
            center: Offset.zero,
            width: p.size,
            height: p.size * 0.6,
          ),
          paint,
        )
        ..restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.t != t;
}
