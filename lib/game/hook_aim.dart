import 'dart:math';

import 'package:flame/components.dart';

import '../data/game_config.dart';

/// Where the hook should travel to when the player taps at [tap].
///
/// - A tap in the water aims from the [tip] toward the tap point.
/// - If that point is past the max reach (deeper than [maxDepthY], further
///   sideways than [maxSideways], or longer than the line allows), the hook
///   stops at the max reach along the same direction.
/// - A tap in the sky (at or above [surfaceY]) or no tap at all (keyboard)
///   drops the hook straight down to [maxDepthY].
Vector2 aimHookTarget({
  required Vector2 tip,
  required Vector2? tap,
  required double surfaceY,
  required double maxDepthY,
  double maxSideways = GameConfig.maxSidewaysReach,
  double lineLengthFactor = GameConfig.lineLengthFactor,
}) {
  final straightDown = Vector2(tip.x, maxDepthY);
  if (tap == null || tap.y <= surfaceY) return straightDown;

  final direction = tap - tip;
  final maxDrop = maxDepthY - tip.y;
  if (direction.y <= 0 || maxDrop <= 0) return straightDown;

  var t = 1.0;
  if (direction.y > maxDrop) t = min(t, maxDrop / direction.y);
  if (direction.x.abs() > maxSideways) {
    t = min(t, maxSideways / direction.x.abs());
  }
  final maxLength = maxDrop * lineLengthFactor;
  final length = direction.length;
  if (length > maxLength) t = min(t, maxLength / length);

  return tip + direction * t;
}
