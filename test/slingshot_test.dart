import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:manabee/core/slingshot.dart';

void main() {
  test('pulling down fires up, faster the further back', () {
    final v = launchVelocity(const Offset(0, 100))!;
    expect(v.dx, 0);
    expect(v.dy, -100 * kPower);
    expect(launchVelocity(const Offset(0, 50))!.dy, greaterThan(v.dy));
  });

  test('the pull is capped, and a tiny pull fires nothing', () {
    expect(launchVelocity(const Offset(0, 1000))!.dy, -kMaxPull * kPower);
    expect(launchVelocity(const Offset(5, 5)), isNull);
    expect(
      clampPull(Offset.zero, const Offset(0, 1000)),
      const Offset(0, kMaxPull),
    );
  });

  test('pulling down-right fires up-left', () {
    final v = launchVelocity(const Offset(60, 80))!;
    expect(v.dx, lessThan(0));
    expect(v.dy, lessThan(0));
  });

  test('flight bounces off the side walls', () {
    const bounds = Size(300, 600);
    var (p, v) = step(
      const Offset(20, 300),
      const Offset(-200, -100),
      0.1,
      bounds,
      10,
    );
    expect(p.dx, greaterThanOrEqualTo(10));
    expect(v.dx, 200);
    (p, v) = step(
      const Offset(285, 300),
      const Offset(200, 0),
      0.1,
      bounds,
      10,
    );
    expect(p.dx, lessThanOrEqualTo(290));
    expect(v.dx, -200);
  });

  test('hits the nearest target in reach', () {
    final targets = [const Offset(100, 100), null, const Offset(130, 100)];
    expect(hitTarget(const Offset(120, 100), targets, 30), 2);
    expect(hitTarget(const Offset(100, 105), targets, 30), 0);
    expect(hitTarget(const Offset(300, 300), targets, 30), isNull);
  });

  test('leaves the screen off the top or the bottom', () {
    const bounds = Size(300, 600);
    expect(offscreen(const Offset(100, -20), bounds, 10), isTrue);
    expect(offscreen(const Offset(100, 620), bounds, 10), isTrue);
    expect(offscreen(const Offset(100, 300), bounds, 10), isFalse);
  });

  test('slots sit in the top of the play area and stay on screen', () {
    const size = Size(360, 600);
    for (var i = 0; i < 6; i++) {
      final p = slotPosition(i, 6, size, 3.7);
      expect(p.dx, inInclusiveRange(40, 320));
      expect(p.dy, lessThan(size.height * 0.5));
    }
  });

  test('a too-narrow area centres the slots instead of throwing', () {
    final p = slotPosition(0, 6, const Size(50, 600), 0);
    expect(p.dx, 25);
  });
}
