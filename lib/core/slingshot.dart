/// Slingshot physics for Kanji Chain: pull back, let go, fly straight,
/// bounce off the side walls, hit a target or leave the screen.
///
/// No gravity: the shot goes where it's aimed, so it's a game about
/// choosing the right part, not about judging an arc. Pure geometry,
/// tested without a screen.
library;

import 'dart:math' as math;
import 'dart:ui';

/// How far back the band stretches, in logical pixels.
const double kMaxPull = 150;

/// Pixels per second of speed per pixel of pull.
const double kPower = 9;

/// A pull too short to be meant — a tap, a wobble — fires nothing.
const double kMinPull = 24;

/// The velocity a release gives: opposite the pull, faster the further
/// back, and capped at [kMaxPull]. Null when the pull was too short.
Offset? launchVelocity(Offset pull) {
  final d = pull.distance;
  if (d < kMinPull) return null;
  final clamped = d > kMaxPull ? pull * (kMaxPull / d) : pull;
  return -clamped * kPower;
}

/// Where the band can be pulled to, from [origin] toward [finger].
Offset clampPull(Offset origin, Offset finger) {
  final pull = finger - origin;
  final d = pull.distance;
  return d > kMaxPull ? origin + pull * (kMaxPull / d) : finger;
}

/// One step of flight: moves by [dt] seconds and bounces off the left and
/// right walls of [bounds] (a shot of [radius]).
(Offset, Offset) step(
  Offset pos,
  Offset vel,
  double dt,
  Size bounds,
  double radius,
) {
  var p = pos + vel * dt;
  var v = vel;
  if (p.dx < radius) {
    p = Offset(2 * radius - p.dx, p.dy);
    v = Offset(-v.dx, v.dy);
  } else if (p.dx > bounds.width - radius) {
    p = Offset(2 * (bounds.width - radius) - p.dx, p.dy);
    v = Offset(-v.dx, v.dy);
  }
  return (p, v);
}

/// The index of the first target within [reach] of [pos], or null.
int? hitTarget(Offset pos, List<Offset?> targets, double reach) {
  var best = -1;
  var bestDistance = double.infinity;
  for (var i = 0; i < targets.length; i++) {
    final t = targets[i];
    if (t == null) continue;
    final d = (t - pos).distance;
    if (d < reach && d < bestDistance) {
      best = i;
      bestDistance = d;
    }
  }
  return best < 0 ? null : best;
}

/// Gone off the top or the bottom.
bool offscreen(Offset pos, Size bounds, double radius) =>
    pos.dy < -radius || pos.dy > bounds.height + radius;

/// Where target slot [i] of [count] floats, in a [size] play area at
/// [t] seconds: two rows across the top, each target bobbing gently on
/// its own phase so the board feels alive without being hard to hit.
Offset slotPosition(int i, int count, Size size, double t) {
  final perRow = (count / 2).ceil();
  final row = i ~/ perRow;
  final col = i % perRow;
  final x =
      size.width * (col + 0.5) / perRow +
      (row.isOdd ? size.width / (perRow * 4) : 0);
  final y = size.height * (0.14 + row * 0.2);
  final bob = math.sin(t * 1.6 + i * 1.3) * 6;
  // Kept 40 px off the edges — or centred, in an area too narrow for that.
  final margin = math.min(40.0, size.width / 2);
  return Offset(x.clamp(margin, size.width - margin), y + bob);
}
