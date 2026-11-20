import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';

import '../../data/game_config.dart';
import '../hook_game.dart';

/// A fish, old boot or jellyfish swimming across the screen.
class Creature extends PositionComponent with HasGameReference<HookGame> {
  Creature({
    required this.type,
    required Vector2 start,
    required this.speed,
    required this.direction,
    double phase = 0,
  }) : _baseY = start.y,
       _time = phase,
       super(
         position: start,
         size: Vector2(type.length, type.height),
         anchor: Anchor.center,
         priority: 2,
       );

  final CreatureType type;
  final double speed;

  /// 1 = swimming right, -1 = swimming left.
  final double direction;

  final double _baseY;
  double _time;

  /// True while hanging on the hook.
  bool hooked = false;

  /// Whether [point] touches this creature (plus a little hook radius).
  bool touches(Vector2 point) {
    final rx = size.x / 2 + GameConfig.hookCatchRadius;
    final ry = size.y / 2 + GameConfig.hookCatchRadius;
    final dx = (point.x - position.x) / rx;
    final dy = (point.y - position.y) / ry;
    return dx * dx + dy * dy <= 1;
  }

  @override
  void update(double dt) {
    _time += dt;
    if (hooked) return; // The fishing line moves us.

    position.x += speed * direction * dt;
    final bobAmount = type.kind == CreatureKind.jellyfish ? 9.0 : 3.0;
    position.y = _baseY + sin(_time * 1.6) * bobAmount;

    final margin = size.x + 10;
    if ((direction > 0 && position.x > game.size.x + margin) ||
        (direction < 0 && position.x < -margin)) {
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    canvas.save();
    canvas.translate(size.x / 2, size.y / 2);
    if (hooked) {
      // Dangle head-up from the hook and wriggle.
      canvas.rotate(-pi / 2 * direction + sin(_time * 18) * 0.25);
    }
    if (direction < 0) canvas.scale(-1, 1);
    switch (type.kind) {
      case CreatureKind.fish:
        _renderFish(canvas);
      case CreatureKind.boot:
        _renderBoot(canvas);
      case CreatureKind.jellyfish:
        _renderJelly(canvas);
    }
    canvas.restore();
  }

  void _renderFish(Canvas canvas) {
    final w = size.x;
    final h = size.y;
    final wiggle = sin(_time * (hooked ? 22 : 9)) * h * 0.18;

    // Tail.
    final tail = Path()
      ..moveTo(-w * 0.32, 0)
      ..lineTo(-w * 0.52, -h * 0.42 + wiggle)
      ..lineTo(-w * 0.46, wiggle * 0.5)
      ..lineTo(-w * 0.52, h * 0.42 + wiggle)
      ..close();
    canvas.drawPath(tail, Paint()..color = type.finColor);

    // Top fin.
    final fin = Path()
      ..moveTo(-w * 0.15, -h * 0.38)
      ..quadraticBezierTo(0, -h * 0.75, w * 0.12, -h * 0.4)
      ..close();
    canvas.drawPath(fin, Paint()..color = type.finColor);

    // Body with a lighter belly.
    final body = Rect.fromCenter(
      center: Offset.zero,
      width: w * 0.8,
      height: h,
    );
    canvas.drawOval(
      body,
      Paint()
        ..shader = Gradient.linear(Offset(0, -h / 2), Offset(0, h / 2), [
          type.bodyColor,
          Color.lerp(type.bodyColor, const Color(0xFFFFFFFF), 0.45)!,
        ]),
    );

    // Stripes.
    final stripe = type.stripeColor;
    if (stripe != null) {
      final paint = Paint()
        ..color = stripe
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.06;
      canvas.save();
      canvas.clipPath(Path()..addOval(body));
      for (final sx in [-0.12, 0.12]) {
        canvas.drawLine(Offset(w * sx, -h), Offset(w * sx, h), paint);
      }
      canvas.restore();
    }

    // Sparkle for the golden fish.
    if (type.value >= 50) {
      final glow = 0.5 + 0.5 * sin(_time * 6);
      canvas.drawCircle(
        Offset(-w * 0.05, -h * 0.15),
        h * 0.12 + glow * 2,
        Paint()..color = Color.fromRGBO(255, 255, 255, 0.4 + glow * 0.4),
      );
    }

    // Eye.
    canvas.drawCircle(
      Offset(w * 0.22, -h * 0.1),
      h * 0.16,
      Paint()..color = const Color(0xFFFFFFFF),
    );
    canvas.drawCircle(
      Offset(w * 0.25, -h * 0.1),
      h * 0.08,
      Paint()..color = const Color(0xFF111111),
    );
  }

  void _renderBoot(Canvas canvas) {
    final w = size.x;
    final h = size.y;
    final sway = sin(_time * 1.2) * 0.12;
    canvas.rotate(sway);
    final boot = Path()
      ..moveTo(-w * 0.35, -h * 0.5)
      ..lineTo(w * 0.05, -h * 0.5)
      ..lineTo(w * 0.05, h * 0.05)
      ..quadraticBezierTo(w * 0.5, h * 0.05, w * 0.5, h * 0.3)
      ..lineTo(w * 0.5, h * 0.5)
      ..lineTo(-w * 0.35, h * 0.5)
      ..close();
    canvas.drawPath(boot, Paint()..color = type.bodyColor);
    canvas.drawRect(
      Rect.fromLTWH(-w * 0.35, h * 0.38, w * 0.85, h * 0.12),
      Paint()..color = type.finColor,
    );
    canvas.drawRect(
      Rect.fromLTWH(-w * 0.38, -h * 0.55, w * 0.46, h * 0.12),
      Paint()..color = type.finColor,
    );
    final lace = Paint()
      ..color = const Color(0xFFBCAAA4)
      ..strokeWidth = 1.5;
    for (var i = 0; i < 3; i++) {
      final ly = -h * 0.3 + i * h * 0.12;
      canvas.drawLine(Offset(-w * 0.05, ly), Offset(w * 0.05, ly + 3), lace);
    }
  }

  void _renderJelly(Canvas canvas) {
    final w = size.x;
    final h = size.y;
    final pulse = 1 + sin(_time * 3.2) * 0.08;
    final domeH = h * 0.45;

    // Tentacles.
    final tentacle = Paint()
      ..color = type.finColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 5; i++) {
      final tx = (-0.32 + i * 0.16) * w;
      final path = Path()..moveTo(tx, 0);
      for (var s = 1; s <= 4; s++) {
        final ty = s * h * 0.13;
        path.lineTo(tx + sin(_time * 4 + i + s) * 4, ty);
      }
      canvas.drawPath(path, tentacle);
    }

    // Dome.
    canvas.save();
    canvas.scale(pulse, 2 - pulse);
    final dome = Path()
      ..moveTo(-w / 2, 0)
      ..quadraticBezierTo(-w / 2, -domeH * 1.3, 0, -domeH * 1.3)
      ..quadraticBezierTo(w / 2, -domeH * 1.3, w / 2, 0)
      ..quadraticBezierTo(0, domeH * 0.25, -w / 2, 0)
      ..close();
    canvas.drawPath(dome, Paint()..color = type.bodyColor);
    canvas.drawCircle(
      Offset(-w * 0.15, -domeH * 0.8),
      w * 0.1,
      Paint()..color = const Color(0x66FFFFFF),
    );
    canvas.restore();
  }
}
