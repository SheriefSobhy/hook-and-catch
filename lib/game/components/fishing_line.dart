import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';

import '../../data/game_config.dart';
import '../hook_aim.dart';
import '../hook_game.dart';
import 'creature.dart';

enum HookState {
  /// Hanging under the rod, ready to drop.
  ready,

  /// Sinking down.
  dropping,

  /// Coming back up.
  reeling,

  /// A jellyfish cut the line; waiting for a new hook.
  cut,
}

/// The line from the rod tip down to the hook, plus what is on the hook.
class FishingLine extends Component with HasGameReference<HookGame> {
  FishingLine() : super(priority: 4);

  static const double restLength = 16;

  HookState state = HookState.ready;
  Vector2 hook = Vector2.zero();
  Creature? caught;

  /// Where the hook is travelling to while [HookState.dropping].
  Vector2 target = Vector2.zero();
  double _cutTimer = 0;
  double _bubbleTimer = 0;
  double _time = 0;

  /// True while the hook is away from the boat.
  bool get isOut => state == HookState.dropping || state == HookState.reeling;

  double get _dropSpeed =>
      game.save.value(UpgradeType.hook) * GameConfig.hookTravelSpeedMultiplier;

  /// Called when the player taps. [point] is the tap position in the game,
  /// or null to drop straight down (keyboard).
  void tapAt(Vector2? point) {
    switch (state) {
      case HookState.ready:
        final tip = game.boat.rodTip;
        target = aimHookTarget(
          tip: tip,
          tap: point,
          surfaceY: point == null ? 0 : game.waveHeightAt(point.x),
          maxDepthY: game.maxHookY,
        );
        // The cast starts at the rod tip and goes straight to the target.
        hook = tip.clone();
        state = HookState.dropping;
        game.boat.stop();
      case HookState.dropping:
        state = HookState.reeling;
      case HookState.reeling:
      case HookState.cut:
        break;
    }
  }

  /// Moves the hook toward [goal] by at most [distance]. Returns true on
  /// arrival.
  bool _moveToward(Vector2 goal, double distance) {
    final offset = goal - hook;
    if (offset.length <= distance) {
      hook.setFrom(goal);
      return true;
    }
    hook.add(offset.normalized()..scale(distance));
    return false;
  }

  /// Puts the hook back under the rod and lets go of any catch.
  void reset() {
    caught?.removeFromParent();
    caught = null;
    state = HookState.ready;
    _cutTimer = 0;
    final tip = game.boat.rodTip;
    hook = Vector2(tip.x, tip.y + restLength);
  }

  @override
  void update(double dt) {
    _time += dt;
    final tip = game.boat.rodTip;
    final follow = min(1.0, dt * GameConfig.hookFollowStrength);

    switch (state) {
      case HookState.ready:
        // Dangle under the rod tip, swinging after the boat.
        hook.x += (tip.x - hook.x) * follow;
        hook.y += (tip.y + restLength - hook.y) * follow;
      case HookState.dropping:
        if (_moveToward(target, _dropSpeed * dt)) state = HookState.reeling;
      case HookState.reeling:
        var speed = _dropSpeed * GameConfig.reelSpeedMultiplier;
        if (caught?.type.kind == CreatureKind.boot) {
          speed *= GameConfig.bootReelSlowdown;
        }
        // Straight back along the line to the rod tip.
        if (_moveToward(tip, speed * dt)) _land();
      case HookState.cut:
        hook = Vector2(tip.x, tip.y + restLength);
        _cutTimer -= dt;
        if (_cutTimer <= 0) state = HookState.ready;
    }

    final underwater = hook.y > game.surfaceY + 4;
    if (underwater && state != HookState.cut) {
      if (caught == null &&
          (state == HookState.dropping || state == HookState.reeling)) {
        _checkCatch();
      }
      _bubbleTimer -= dt;
      if (_bubbleTimer <= 0 &&
          (state == HookState.dropping || state == HookState.reeling)) {
        _bubbleTimer = 0.12;
        game.bubbles.emit(hook.x, hook.y, radius: 2);
      }
    }

    final fish = caught;
    if (fish != null) {
      fish.position.setValues(hook.x, hook.y + fish.size.x * 0.4);
    }
  }

  void _checkCatch() {
    if (!game.isPlaying) return;
    for (final creature in game.creatures) {
      if (creature.hooked || !creature.touches(hook)) continue;
      if (creature.type.kind == CreatureKind.jellyfish) {
        _cutLine();
      } else {
        creature.hooked = true;
        caught = creature;
        state = HookState.reeling;
        for (var i = 0; i < 6; i++) {
          game.bubbles.emit(hook.x, hook.y, radius: 3);
        }
      }
      return;
    }
  }

  void _cutLine() {
    game.showText('Line cut!', hook.clone(), const Color(0xFFFF6B9A));
    for (var i = 0; i < 8; i++) {
      game.bubbles.emit(hook.x, hook.y, radius: 3);
    }
    state = HookState.cut;
    _cutTimer = GameConfig.lineCutCooldown;
    hook = game.boat.rodTip + Vector2(0, restLength);
  }

  void _land() {
    final fish = caught;
    caught = null;
    state = HookState.ready;
    if (fish != null) {
      game.onCatchLanded(fish);
      fish.removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    final tip = game.boat.rodTip;
    if (state == HookState.cut) {
      // A short loose end of line while waiting for a new hook.
      final wave = sin(_time * 10) * 3;
      canvas.drawLine(
        tip.toOffset(),
        Offset(tip.x + wave, tip.y + 10),
        _linePaint,
      );
      return;
    }

    // Straight line from the rod tip to the hook.
    final end = hook.toOffset();
    canvas.drawLine(tip.toOffset(), end, _linePaint);

    // Hook: a small "J".
    final hookPath = Path()
      ..moveTo(end.dx, end.dy)
      ..lineTo(end.dx, end.dy + 8)
      ..arcToPoint(
        Offset(end.dx - 8, end.dy + 8),
        radius: const Radius.circular(4),
      )
      ..lineTo(end.dx - 8, end.dy + 5);
    canvas.drawPath(hookPath, _hookPaint);
    canvas.drawCircle(end, 2.5, Paint()..color = const Color(0xFFFF5252));
  }

  static final _linePaint = Paint()
    ..color = const Color(0xDDFFFFFF)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.2;

  static final _hookPaint = Paint()
    ..color = const Color(0xFFCFD8DC)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.2
    ..strokeCap = StrokeCap.round;
}
