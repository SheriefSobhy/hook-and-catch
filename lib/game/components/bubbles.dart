import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';

import '../../data/game_config.dart';
import '../hook_game.dart';

/// Draws all bubbles in one component (cheaper than one component each).
class Bubbles extends Component with HasGameReference<HookGame> {
  Bubbles() : super(priority: 3);

  final List<_Bubble> _bubbles = [];
  double _spawnBudget = 0;

  static final _fill = Paint()..color = const Color(0x33FFFFFF);
  static final _ring = Paint()
    ..color = const Color(0x99FFFFFF)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.2;
  static final _shine = Paint()..color = const Color(0xCCFFFFFF);

  /// Adds a bubble at a point (used by the moving hook and splashes).
  void emit(double x, double y, {double radius = 2.5}) {
    if (_bubbles.length > 160) return;
    final random = game.random;
    _bubbles.add(
      _Bubble(
        x: x,
        y: y,
        radius: radius * (0.6 + random.nextDouble() * 0.8),
        speed: 30 + random.nextDouble() * 40,
        phase: random.nextDouble() * pi * 2,
      ),
    );
  }

  @override
  void update(double dt) {
    final size = game.size;
    if (size.x <= 0) return;
    final random = game.random;

    _spawnBudget += dt * GameConfig.bubblesPerSecond;
    while (_spawnBudget >= 1) {
      _spawnBudget -= 1;
      emit(random.nextDouble() * size.x, game.seabedY, radius: 3.5);
    }

    final surface = game.surfaceY;
    for (final bubble in _bubbles) {
      bubble.age += dt;
      bubble.y -= bubble.speed * dt;
      bubble.speed = min(bubble.speed + 15 * dt, 110);
    }
    _bubbles.removeWhere((b) => b.y < surface + 4);
  }

  @override
  void render(Canvas canvas) {
    for (final bubble in _bubbles) {
      final center = Offset(
        bubble.x + sin(bubble.age * 3 + bubble.phase) * 3,
        bubble.y,
      );
      canvas.drawCircle(center, bubble.radius, _fill);
      canvas.drawCircle(center, bubble.radius, _ring);
      canvas.drawCircle(
        center.translate(-bubble.radius * 0.35, -bubble.radius * 0.35),
        bubble.radius * 0.25,
        _shine,
      );
    }
  }
}

class _Bubble {
  _Bubble({
    required this.x,
    required this.y,
    required this.radius,
    required this.speed,
    required this.phase,
  });

  final double x;
  double y;
  final double radius;
  double speed;
  final double phase;
  double age = 0;
}
