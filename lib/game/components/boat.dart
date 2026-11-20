import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';

import '../../data/game_config.dart';
import '../hook_game.dart';

/// The player's boat. It glides toward [targetX] at the upgraded boat speed.
class Boat extends Component with HasGameReference<HookGame> {
  Boat() : super(priority: 5);

  static const double halfWidth = 38;

  double x = 0;
  double targetX = 0;
  double _time = 0;
  double _tilt = 0;
  bool _placed = false;

  double get bob =>
      sin(_time * GameConfig.boatBobSpeed) * GameConfig.boatBobAmount;

  /// Water line under the boat.
  double get y => game.waveHeightAt(x) + bob * 0.3;

  /// Where the fishing line leaves the rod.
  Vector2 get rodTip => Vector2(x + 30 + _tilt * 44, y - 44 + _tilt * 30);

  double get minX => halfWidth;
  double get maxX => max(halfWidth, game.size.x - halfWidth);

  void center() {
    x = game.size.x / 2;
    targetX = x;
    _placed = true;
  }

  /// Stops gliding (used when the hook goes out).
  void stop() => targetX = x;

  void moveBy(double dx) {
    targetX = (targetX + dx).clamp(minX, maxX);
  }

  @override
  void update(double dt) {
    _time += dt;
    if (!_placed && game.size.x > 0) center();
    targetX = targetX.clamp(minX, maxX);

    final speed = game.save.value(UpgradeType.boat);
    final diff = targetX - x;
    final step = speed * dt;
    final oldX = x;
    x = diff.abs() <= step ? targetX : x + step * diff.sign;
    x = x.clamp(minX, maxX);

    // Lean slightly in the direction of travel.
    final velocity = dt > 0 ? (x - oldX) / dt : 0.0;
    final wantedTilt = (velocity / max(speed, 1)) * 0.12;
    _tilt += (wantedTilt - _tilt) * min(1, dt * 8);
  }

  @override
  void render(Canvas canvas) {
    canvas.save();
    canvas.translate(x, y);
    canvas.rotate(_tilt + sin(_time * 1.7) * 0.025);

    // Rod.
    canvas.drawLine(
      const Offset(8, -12),
      const Offset(30, -44),
      Paint()
        ..color = const Color(0xFF5D4037)
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );

    // Cabin.
    final cabin = RRect.fromRectAndRadius(
      const Rect.fromLTWH(-22, -30, 26, 20),
      const Radius.circular(4),
    );
    canvas.drawRRect(cabin, Paint()..color = const Color(0xFFFFF3E0));
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-17, -26, 9, 8),
        const Radius.circular(2),
      ),
      Paint()..color = const Color(0xFF81D4FA),
    );
    canvas.drawRect(
      const Rect.fromLTWH(-25, -34, 32, 5),
      Paint()..color = const Color(0xFFD84315),
    );

    // Fisherman.
    canvas.drawCircle(
      const Offset(10, -22),
      6,
      Paint()..color = const Color(0xFFFFCC80),
    );
    canvas.drawRect(
      const Rect.fromLTWH(5, -17, 10, 9),
      Paint()..color = const Color(0xFFFFB300),
    );
    canvas.drawArc(
      const Rect.fromLTWH(3, -30, 14, 10),
      pi,
      pi,
      true,
      Paint()..color = const Color(0xFF1565C0),
    );

    // Hull.
    final hull = Path()
      ..moveTo(-halfWidth, -12)
      ..lineTo(halfWidth, -12)
      ..lineTo(halfWidth - 10, 8)
      ..quadraticBezierTo(0, 12, -halfWidth + 10, 8)
      ..close();
    canvas.drawPath(hull, Paint()..color = const Color(0xFFC62828));
    canvas.drawRect(
      const Rect.fromLTWH(-halfWidth, -12, halfWidth * 2, 4),
      Paint()..color = const Color(0xFFFFFFFF),
    );
    canvas.drawCircle(
      const Offset(-20, -1),
      2.5,
      Paint()..color = const Color(0xFFFFE082),
    );
    canvas.drawCircle(
      const Offset(-8, -1),
      2.5,
      Paint()..color = const Color(0xFFFFE082),
    );

    canvas.restore();
  }
}
