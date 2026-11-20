import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hook_and_catch/game/hook_aim.dart';

void main() {
  final tip = Vector2(200, 100);
  const surface = 150.0;
  const maxDepth = 400.0; // 300 px straight down from the tip.

  Vector2 aim(Vector2? tap) => aimHookTarget(
    tip: tip,
    tap: tap,
    surfaceY: surface,
    maxDepthY: maxDepth,
    maxSideways: 160,
    lineLengthFactor: 1.15,
  );

  test('tap within reach is used exactly', () {
    expect(aim(Vector2(260, 300)), Vector2(260, 300));
  });

  test('too deep: stops at the depth line along the same direction', () {
    final target = aim(Vector2(250, 700)); // dx 50, dy 600 -> half way is 300
    expect(target.y, closeTo(maxDepth, 1e-3));
    expect(target.x, closeTo(200 + 50 * 300 / 600, 1e-3));
  });

  test('too far sideways: stops at the sideways limit', () {
    final target = aim(Vector2(0, 200)); // dx -200, dy 100
    expect(target.x, closeTo(200 - 160, 1e-3));
    expect(target.y, closeTo(100 + 100 * 160 / 200, 1e-3));
  });

  test('too long a diagonal: limited by line length', () {
    // dx 160, dy 300: length 340 fits the 345 px line (300 x 1.15).
    expect(aim(Vector2(360, 400)), Vector2(360, 400));
    // With a 300 px line the length limit kicks in first.
    final short = aimHookTarget(
      tip: tip,
      tap: Vector2(360, 400),
      surfaceY: surface,
      maxDepthY: maxDepth,
      maxSideways: 160,
      lineLengthFactor: 1.0,
    );
    expect(short.distanceTo(tip), closeTo(300, 1e-3));
  });

  test('sky tap or no tap drops straight down', () {
    expect(aim(Vector2(30, 120)), Vector2(200, maxDepth));
    expect(aim(Vector2(30, surface)), Vector2(200, maxDepth));
    expect(aim(null), Vector2(200, maxDepth));
  });
}
