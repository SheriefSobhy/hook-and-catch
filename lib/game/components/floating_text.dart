import 'package:flame/components.dart';
import 'package:flutter/painting.dart';

/// Short text that floats up and fades out, like "+15" or "Line cut!".
class FloatingText extends PositionComponent {
  FloatingText({
    required this.text,
    required super.position,
    required this.color,
    this.fontSize = 20,
  }) : super(anchor: Anchor.center, priority: 10);

  static const double lifetime = 1.3;

  final String text;
  final double fontSize;
  final Color color;
  double _age = 0;

  @override
  void update(double dt) {
    _age += dt;
    position.y -= 38 * dt;
    if (_age >= lifetime) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    final t = (_age / lifetime).clamp(0.0, 1.0);
    final opacity = t < 0.6 ? 1.0 : 1 - (t - 0.6) / 0.4;
    final scale = t < 0.15 ? 0.6 + t / 0.15 * 0.4 : 1.0;
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color.withValues(alpha: opacity),
          fontSize: fontSize * scale,
          fontWeight: FontWeight.w900,
          shadows: [
            Shadow(
              color: const Color(0xFF000000).withValues(alpha: 0.5 * opacity),
              offset: const Offset(1.5, 1.5),
              blurRadius: 2,
            ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, Offset(-painter.width / 2, -painter.height / 2));
    painter.dispose();
  }
}
