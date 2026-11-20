import 'dart:math';

import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../data/game_config.dart';
import '../data/save_data.dart';
import 'components/boat.dart';
import 'components/bubbles.dart';
import 'components/creature.dart';
import 'components/fishing_line.dart';
import 'components/floating_text.dart';
import 'components/ocean.dart';
import 'spawn_logic.dart';

enum GamePhase { menu, playing, gameOver }

/// Overlay names used with [GameWidget.overlayBuilderMap].
class Overlays {
  Overlays._();
  static const menu = 'menu';
  static const hud = 'hud';
  static const gameOver = 'gameOver';
  static const rotate = 'rotate';
  static const all = [menu, hud, gameOver, rotate];
}

class HookGame extends FlameGame
    with TapCallbacks, DragCallbacks, KeyboardEvents {
  HookGame({required this.save, Random? random}) : random = random ?? Random();

  final SaveData save;
  final Random random;

  /// Coins caught in the current round (shown in the HUD).
  final ValueNotifier<int> roundCoins = ValueNotifier(0);

  /// Whole seconds left in the round (shown in the HUD).
  final ValueNotifier<int> secondsLeft = ValueNotifier(GameConfig.roundSeconds);

  GamePhase phase = GamePhase.menu;
  bool lastRoundWasBest = false;

  /// Turned off in tests to keep the water empty.
  bool spawningEnabled = true;

  late final Boat boat;
  late final FishingLine line;
  late final Bubbles bubbles;

  double _timeLeft = GameConfig.roundSeconds.toDouble();
  double _spawnTimer = 0;
  double _time = 0;
  int _keyDirection = 0;

  bool get isPlaying => phase == GamePhase.playing;

  /// True while a round is paused because the screen is in portrait.
  bool pausedForRotation = false;

  /// The game is made for landscape: taller than wide counts as portrait.
  bool get isPortrait => size.y > size.x;

  /// A round is running and not paused.
  bool get canPlay => isPlaying && !pausedForRotation;

  double get surfaceY => (size.y * GameConfig.skyFraction).clamp(
    GameConfig.minSkyHeight,
    GameConfig.maxSkyHeight,
  );
  double get seabedY =>
      size.y -
      (size.y * GameConfig.seabedFraction).clamp(
        GameConfig.minSeabedHeight,
        GameConfig.maxSeabedHeight,
      );
  double get waterDepth => max(1, seabedY - surfaceY);

  /// Deepest point the hook can reach with the current line upgrade.
  double get maxHookY =>
      surfaceY + waterDepth * save.value(UpgradeType.line) - 8;

  /// Y position of the animated water surface at [x].
  double waveHeightAt(double x) =>
      surfaceY + sin(x * 0.025 + _time * 1.8) * 3 + sin(x * 0.06 - _time) * 1.5;

  Iterable<Creature> get creatures => children.whereType<Creature>();

  @override
  Color backgroundColor() => const Color(0xFF041F45);

  @override
  Future<void> onLoad() async {
    add(Ocean());
    add(bubbles = Bubbles());
    add(boat = Boat());
    add(line = FishingLine());
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    if (isLoaded) boat.moveBy(0);
  }

  // ------------------------------------------------------------ Round flow

  void startRound() {
    for (final creature in creatures.toList()) {
      creature.removeFromParent();
    }
    line.reset();
    boat.center();
    roundCoins.value = 0;
    _timeLeft = GameConfig.roundSeconds.toDouble();
    secondsLeft.value = GameConfig.roundSeconds;
    lastRoundWasBest = false;
    phase = GamePhase.playing;
    for (
      var i = 0;
      spawningEnabled && i < GameConfig.creaturesAtRoundStart;
      i++
    ) {
      spawnCreature(anywhere: true);
    }
    overlays
      ..remove(Overlays.menu)
      ..remove(Overlays.gameOver)
      ..add(Overlays.hud);
  }

  void endRound() {
    if (!isPlaying) return;
    phase = GamePhase.gameOver;
    secondsLeft.value = 0;
    line.reset();
    lastRoundWasBest = save.finishRound(roundCoins.value);
    overlays
      ..remove(Overlays.hud)
      ..add(Overlays.gameOver);
  }

  void onCatchLanded(Creature creature) {
    if (!isPlaying) return;
    final type = creature.type;
    final at = boat.rodTip + Vector2(0, -10);
    if (type.kind == CreatureKind.boot) {
      showText('Old boot!', at, const Color(0xFFD7CCC8));
    } else {
      roundCoins.value += type.value;
      showText('+${type.value}', at, const Color(0xFFFFE066), fontSize: 26);
    }
  }

  void showText(String text, Vector2 at, Color color, {double fontSize = 20}) {
    add(
      FloatingText(
        text: text,
        position: at.clone(),
        color: color,
        fontSize: fontSize,
      ),
    );
  }

  /// Adds a creature. With [anywhere], it starts at a random x on screen
  /// instead of just off the edge.
  Creature spawnCreature({bool anywhere = false, CreatureType? type}) {
    final kind = type ?? pickCreatureType(random);
    final direction = random.nextBool() ? 1.0 : -1.0;
    final y = surfaceY + waterDepth * pickDepth(random, kind);
    final x = anywhere
        ? random.nextDouble() * size.x
        : (direction > 0 ? -kind.length : size.x + kind.length);
    final creature = Creature(
      type: kind,
      start: Vector2(x, y),
      speed: pickSpeed(random, kind),
      direction: direction,
      phase: random.nextDouble() * 10,
    );
    add(creature);
    return creature;
  }

  // ------------------------------------------------------------- Update

  @override
  void update(double dt) {
    // Pause the round while the phone is held in portrait, and resume
    // automatically once it is turned to landscape.
    final shouldPause = isPlaying && isPortrait;
    if (shouldPause != pausedForRotation) {
      pausedForRotation = shouldPause;
      if (shouldPause) {
        _keyDirection = 0;
        overlays.add(Overlays.rotate, priority: 10);
      } else {
        overlays.remove(Overlays.rotate);
      }
    }
    if (pausedForRotation) return; // Everything stays frozen.

    final step = min(dt, GameConfig.maxFrameTime);
    _time += step;

    if (_keyDirection != 0 && !line.isOut) {
      boat.moveBy(_keyDirection * save.value(UpgradeType.boat) * step);
    }

    _spawnTimer -= step;
    if (spawningEnabled && _spawnTimer <= 0 && size.x > 0) {
      _spawnTimer = GameConfig.spawnInterval;
      if (creatures.length < GameConfig.maxCreatures) spawnCreature();
    }

    if (isPlaying) {
      _timeLeft -= step;
      final whole = max(0, _timeLeft.ceil());
      if (secondsLeft.value != whole) secondsLeft.value = whole;
      if (_timeLeft <= 0) endRound();
    }

    super.update(step);
  }

  // ------------------------------------------------------------- Input

  @override
  void onTapUp(TapUpEvent event) {
    // Aim the hook at the tap point (a sky tap drops straight down).
    if (canPlay) line.tapAt(event.localPosition);
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    super.onDragUpdate(event);
    // The boat stays put while the hook is out.
    if (canPlay && !line.isOut) {
      boat.moveBy(event.localDelta.x * GameConfig.dragSensitivity);
    }
  }

  @override
  KeyEventResult onKeyEvent(
    KeyEvent event,
    Set<LogicalKeyboardKey> keysPressed,
  ) {
    final left =
        keysPressed.contains(LogicalKeyboardKey.arrowLeft) ||
        keysPressed.contains(LogicalKeyboardKey.keyA);
    final right =
        keysPressed.contains(LogicalKeyboardKey.arrowRight) ||
        keysPressed.contains(LogicalKeyboardKey.keyD);
    _keyDirection = canPlay ? (right ? 1 : 0) - (left ? 1 : 0) : 0;
    if (_keyDirection != 0) boat.targetX = boat.x;

    if (event is KeyDownEvent &&
        (event.logicalKey == LogicalKeyboardKey.space ||
            event.logicalKey == LogicalKeyboardKey.arrowDown)) {
      if (canPlay) line.tapAt(null); // Straight down.
      return KeyEventResult.handled;
    }
    return (left || right) ? KeyEventResult.handled : KeyEventResult.ignored;
  }

  @override
  void onRemove() {
    roundCoins.dispose();
    secondsLeft.dispose();
    super.onRemove();
  }
}
