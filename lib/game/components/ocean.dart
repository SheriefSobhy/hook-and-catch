import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';

import '../../data/game_config.dart';
import '../hook_game.dart';

/// Sky, animated water surface, light rays, sea floor and swaying seaweed.
class Ocean extends Component with HasGameReference<HookGame> {
  Ocean() : super(priority: 0);

  double _time = 0;
  Size _cachedSize = Size.zero;
  late Paint _skyPaint;
  late Paint _waterPaint;
  final List<_Weed> _weeds = [];
  final List<_Rock> _rocks = [];

  static const _sandColor = Color(0xFFE0C78A);
  static const _sandDark = Color(0xFFC9A961);

  @override
  void update(double dt) => _time += dt;

  void _rebuild(Size size) {
    _cachedSize = size;
    final surface = game.surfaceY;
    _skyPaint = Paint()
      ..shader = Gradient.linear(Offset.zero, Offset(0, surface), const [
        Color(0xFF7EC8F2),
        Color(0xFFD6F0FF),
      ]);
    _waterPaint = Paint()
      ..shader = Gradient.linear(
        Offset(0, surface),
        Offset(0, size.height),
        const [
          Color(0xFF3FC1E8),
          Color(0xFF1580C0),
          Color(0xFF0A4C86),
          Color(0xFF041F45),
        ],
        const [0.0, 0.3, 0.65, 1.0],
      );

    // Same random layout every time so it does not flicker on resize.
    final random = Random(7);
    final weedCount = max(4, (size.width / 45).round());
    _weeds
      ..clear()
      ..addAll(
        List.generate(
          weedCount,
          (i) => _Weed(
            x: (i + 0.1 + random.nextDouble() * 0.8) * size.width / weedCount,
            height: 35 + random.nextDouble() * 55,
            phase: random.nextDouble() * pi * 2,
            color: Color.lerp(
              const Color(0xFF2E8B57),
              const Color(0xFF66BB6A),
              random.nextDouble(),
            )!,
          ),
        ),
      );
    _rocks
      ..clear()
      ..addAll(
        List.generate(
          max(3, (size.width / 110).round()),
          (_) => _Rock(
            x: random.nextDouble() * size.width,
            radius: 10 + random.nextDouble() * 14,
          ),
        ),
      );
  }

  @override
  void render(Canvas canvas) {
    final size = game.size.toSize();
    if (size.isEmpty) return;
    if (size != _cachedSize) _rebuild(size);

    final surface = game.surfaceY;
    final seabed = game.seabedY;

    // Sky and sun. The sun sits in the middle, below the HUD badges
    // (coins on the left, timer on the right) so it never touches them.
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, surface + 10), _skyPaint);
    final sun = Offset(
      size.width * GameConfig.sunXFraction,
      surface * GameConfig.sunYFraction,
    );
    canvas.drawCircle(
      sun,
      GameConfig.sunGlowRadius,
      Paint()..color = const Color(0x55FFF59D),
    );
    canvas.drawCircle(
      sun,
      GameConfig.sunRadius,
      Paint()..color = const Color(0xFFFFEE58),
    );

    // Water with a wavy top edge.
    final water = Path()..moveTo(0, size.height);
    for (double x = 0; x <= size.width + 8; x += 8) {
      water.lineTo(x, game.waveHeightAt(x));
    }
    water
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(water, _waterPaint);

    // Foam highlight along the surface.
    final foam = Path()..moveTo(0, game.waveHeightAt(0));
    for (double x = 8; x <= size.width + 8; x += 8) {
      foam.lineTo(x, game.waveHeightAt(x));
    }
    canvas.drawPath(
      foam,
      Paint()
        ..color = const Color(0xAAFFFFFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );

    // Soft light rays from the surface.
    final rayPaint = Paint()..color = const Color(0x14FFFFFF);
    for (var i = 0; i < 4; i++) {
      final sway = sin(_time * 0.4 + i * 1.7) * 25;
      final x = size.width * (0.12 + i * 0.26) + sway;
      final ray = Path()
        ..moveTo(x - 14, surface)
        ..lineTo(x + 14, surface)
        ..lineTo(x + 60 + sway, seabed * 0.85)
        ..lineTo(x + 10 + sway, seabed * 0.85)
        ..close();
      canvas.drawPath(ray, rayPaint);
    }

    // Dashed line showing how deep the hook can reach.
    final reach = game.maxHookY;
    final dash = Paint()
      ..color = const Color(0x55FFFFFF)
      ..strokeWidth = 1.5;
    for (double x = 0; x < size.width; x += 16) {
      canvas.drawLine(Offset(x, reach), Offset(x + 8, reach), dash);
    }

    // Sea floor.
    final sand = Path()..moveTo(0, size.height);
    for (double x = 0; x <= size.width + 10; x += 10) {
      sand.lineTo(x, seabed + sin(x * 0.03) * 5 + sin(x * 0.011) * 4);
    }
    sand
      ..lineTo(size.width, size.height)
      ..close();
    for (final rock in _rocks) {
      canvas.drawCircle(
        Offset(rock.x, seabed + 6),
        rock.radius,
        Paint()..color = const Color(0xFF546E7A),
      );
    }
    canvas.drawPath(sand, Paint()..color = _sandColor);
    final speck = Paint()..color = _sandDark;
    for (double x = 13; x < size.width; x += 37) {
      canvas.drawCircle(Offset(x, seabed + 18 + (x % 3) * 6), 1.6, speck);
    }

    // Seaweed.
    for (final weed in _weeds) {
      final sway = sin(_time * 1.3 + weed.phase) * 10;
      final base = Offset(weed.x, seabed + 6);
      final path = Path()
        ..moveTo(base.dx - 4, base.dy)
        ..quadraticBezierTo(
          base.dx + sway,
          base.dy - weed.height * 0.5,
          base.dx + sway * 1.6,
          base.dy - weed.height,
        )
        ..quadraticBezierTo(
          base.dx + sway + 4,
          base.dy - weed.height * 0.5,
          base.dx + 4,
          base.dy,
        )
        ..close();
      canvas.drawPath(path, Paint()..color = weed.color);
    }
  }
}

class _Weed {
  _Weed({
    required this.x,
    required this.height,
    required this.phase,
    required this.color,
  });

  final double x;
  final double height;
  final double phase;
  final Color color;
}

class _Rock {
  _Rock({required this.x, required this.radius});

  final double x;
  final double radius;
}
