import 'dart:math';

import 'package:flame/components.dart';
import 'package:flame_test/flame_test.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hook_and_catch/data/game_config.dart';
import 'package:hook_and_catch/data/save_data.dart';
import 'package:hook_and_catch/game/components/creature.dart';
import 'package:hook_and_catch/game/components/fishing_line.dart';
import 'package:hook_and_catch/game/hook_game.dart';
import 'package:shared_preferences/shared_preferences.dart';

late SaveData save;

HookGame createGame() {
  final game = HookGame(save: save)..spawningEnabled = false;
  for (final name in [Overlays.menu, Overlays.hud, Overlays.gameOver]) {
    game.overlays.addEntry(name, (_, _) => const SizedBox());
  }
  return game;
}

/// Runs the game for [seconds] in small steps.
void run(HookGame game, double seconds) {
  const step = 1 / 60;
  for (double t = 0; t < seconds; t += step) {
    game.update(step);
  }
}

Future<void> startRound(HookGame game) async {
  game.onGameResize(Vector2(400, 800));
  game.startRound();
  await game.ready();
  run(game, 0.5); // Let the hook settle under the rod.
}

CreatureType typeOf(CreatureKind kind) =>
    GameConfig.creatures.firstWhere((c) => c.kind == kind);

Future<Creature> placeUnderHook(
  HookGame game,
  CreatureType type, {
  double depth = 60,
}) async {
  final creature = Creature(
    type: type,
    start: Vector2(game.line.hook.x, game.surfaceY + depth),
    speed: 0,
    direction: 1,
  );
  game.add(creature);
  await game.ready();
  return creature;
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    save = await SaveData.load();
  });

  testWithGame<HookGame>('round ends after the round time', createGame, (
    game,
  ) async {
    await startRound(game);
    expect(game.phase, GamePhase.playing);
    expect(game.secondsLeft.value, lessThanOrEqualTo(GameConfig.roundSeconds));

    run(game, GameConfig.roundSeconds.toDouble());
    expect(game.phase, GamePhase.gameOver);
    expect(game.secondsLeft.value, 0);
    expect(game.overlays.isActive(Overlays.gameOver), isTrue);
  });

  testWithGame<HookGame>('hook drops to max depth and comes back', createGame, (
    game,
  ) async {
    await startRound(game);
    expect(game.line.state, HookState.ready);

    game.line.tapAt(null);
    expect(game.line.state, HookState.dropping);

    var deepest = 0.0;
    for (var i = 0; i < 600 && game.line.state != HookState.ready; i++) {
      run(game, 1 / 60);
      if (game.line.hook.y > deepest) deepest = game.line.hook.y;
    }
    expect(deepest, closeTo(game.maxHookY, 0.01));
    expect(game.line.state, HookState.ready);
    expect(game.roundCoins.value, 0);
  });

  testWithGame<HookGame>('second tap reels the hook up early', createGame, (
    game,
  ) async {
    await startRound(game);
    game.line.tapAt(null);
    run(game, 0.3);
    game.line.tapAt(null);
    expect(game.line.state, HookState.reeling);
  });

  testWithGame<HookGame>('catching a fish earns its coins', createGame, (
    game,
  ) async {
    await startRound(game);
    final sardine = typeOf(CreatureKind.fish);
    final fish = await placeUnderHook(game, sardine);

    game.line.tapAt(null);
    for (var i = 0; i < 120 && !fish.hooked; i++) {
      run(game, 1 / 60);
    }
    expect(fish.hooked, isTrue);
    expect(game.line.caught, fish);
    expect(game.line.state, HookState.reeling);

    run(game, 3);
    expect(game.line.state, HookState.ready);
    expect(game.roundCoins.value, sardine.value);
    expect(fish.isMounted, isFalse);

    run(game, GameConfig.roundSeconds.toDouble());
    expect(save.coins, sardine.value);
    expect(save.bestScore, sardine.value);
  });

  testWithGame<HookGame>('old boot is worth nothing', createGame, (game) async {
    await startRound(game);
    await placeUnderHook(game, typeOf(CreatureKind.boot));
    game.line.tapAt(null);
    run(game, 6);
    expect(game.line.state, HookState.ready);
    expect(game.roundCoins.value, 0);
  });

  testWithGame<HookGame>('jellyfish cuts the line', createGame, (game) async {
    await startRound(game);
    final jelly = await placeUnderHook(game, typeOf(CreatureKind.jellyfish));
    game.line.tapAt(null);
    run(game, 1);
    expect(game.line.state, HookState.cut);
    expect(jelly.hooked, isFalse);

    game.line.tapAt(null); // Tapping does nothing while the line is cut.
    expect(game.line.state, HookState.cut);

    run(game, GameConfig.lineCutCooldown + 0.1);
    expect(game.line.state, HookState.ready);
  });

  testWithGame<HookGame>(
    'dragging moves the boat within the screen',
    createGame,
    (game) async {
      await startRound(game);
      game.boat.moveBy(-1000);
      run(game, 5);
      expect(game.boat.x, game.boat.minX);
      game.boat.moveBy(5000);
      run(game, 5);
      expect(game.boat.x, game.boat.maxX);
    },
  );

  testWithGame<HookGame>('longer line upgrade reaches deeper', createGame, (
    game,
  ) async {
    await startRound(game);
    final before = game.maxHookY;
    save.finishRound(1000);
    expect(save.buy(UpgradeType.line), isTrue);
    expect(game.maxHookY, greaterThan(before));
  });

  group('aimed casting', () {
    testWithGame<HookGame>('tap in the water casts at an angle', createGame, (
      game,
    ) async {
      await startRound(game);
      final tip = game.boat.rodTip.clone();
      final tap = tip + Vector2(110, 160);
      game.line.tapAt(tap);
      expect(game.line.state, HookState.dropping);
      expect(game.line.target.distanceTo(tap), lessThan(0.001));

      // Goes out along the straight line from the rod tip to the tap.
      for (var i = 0; i < 600 && game.line.state == HookState.dropping; i++) {
        run(game, 1 / 60);
        expect(distanceToLine(game.line.hook, tip, tap), lessThan(0.5));
      }
      expect(game.line.state, HookState.reeling);
      expect(game.line.hook.distanceTo(tap), lessThan(0.001));

      // Comes back along the same line (the rod tip bobs a few pixels).
      for (var i = 0; i < 600 && game.line.state == HookState.reeling; i++) {
        run(game, 1 / 60);
        expect(distanceToLine(game.line.hook, tip, tap), lessThan(8));
      }
      expect(game.line.state, HookState.ready);
      expect(game.line.hook.distanceTo(game.boat.rodTip), lessThan(20));
    });

    testWithGame<HookGame>(
      'tap beyond max reach stops at max reach',
      createGame,
      (game) async {
        await startRound(game);
        final tip = game.boat.rodTip.clone();
        final tap = Vector2(game.size.x, game.size.y); // Far bottom corner.
        game.line.tapAt(tap);
        final target = game.line.target.clone();

        // Same direction as the tap...
        expect(distanceToLine(target, tip, tap), lessThan(0.001));
        // ...but within every limit.
        final maxDrop = game.maxHookY - tip.y;
        expect(target.y, lessThanOrEqualTo(game.maxHookY + 0.001));
        expect(
          (target.x - tip.x).abs(),
          lessThanOrEqualTo(GameConfig.maxSidewaysReach + 0.001),
        );
        expect(
          target.distanceTo(tip),
          lessThanOrEqualTo(maxDrop * GameConfig.lineLengthFactor + 0.001),
        );
        expect(target.distanceTo(tip), lessThan(tap.distanceTo(tip)));

        // The hook never goes past the target.
        var deepest = 0.0;
        for (var i = 0; i < 900 && game.line.state != HookState.ready; i++) {
          run(game, 1 / 60);
          deepest = max(deepest, game.line.hook.y);
        }
        expect(deepest, closeTo(target.y, 0.001));
      },
    );

    testWithGame<HookGame>('sky tap drops straight down', createGame, (
      game,
    ) async {
      await startRound(game);
      final tip = game.boat.rodTip.clone();
      game.line.tapAt(Vector2(20, game.surfaceY - 40));
      expect(game.line.target.x, closeTo(tip.x, 0.001));
      expect(game.line.target.y, closeTo(game.maxHookY, 0.001));

      var deepest = 0.0;
      while (game.line.state == HookState.dropping) {
        run(game, 1 / 60);
        expect(game.line.hook.x, closeTo(tip.x, 0.001));
        deepest = max(deepest, game.line.hook.y);
      }
      expect(deepest, closeTo(game.maxHookY, 0.001));
    });

    testWithGame<HookGame>('catches a fish on an angled path', createGame, (
      game,
    ) async {
      await startRound(game);
      final tip = game.boat.rodTip.clone();
      final tap = tip + Vector2(-140, 200);
      final sardine = typeOf(CreatureKind.fish);
      final fish = await placeAt(game, sardine, tip + (tap - tip) * 0.6);

      game.line.tapAt(tap);
      for (var i = 0; i < 300 && !fish.hooked; i++) {
        run(game, 1 / 60);
      }
      expect(game.line.caught, fish);
      expect(game.line.state, HookState.reeling);

      run(game, 4);
      expect(game.line.state, HookState.ready);
      expect(game.roundCoins.value, sardine.value);
    });

    testWithGame<HookGame>(
      'jellyfish cuts the line on an angled path',
      createGame,
      (game) async {
        await startRound(game);
        final tip = game.boat.rodTip.clone();
        final tap = tip + Vector2(120, 220);
        await placeAt(
          game,
          typeOf(CreatureKind.jellyfish),
          tip + (tap - tip) * 0.7,
        );

        game.line.tapAt(tap);
        run(game, 2);
        expect(game.line.state, HookState.cut);
      },
    );

    testWithGame<HookGame>(
      'second tap reels in an angled cast early',
      createGame,
      (game) async {
        await startRound(game);
        final tip = game.boat.rodTip.clone();
        final tap = tip + Vector2(120, 250);
        game.line.tapAt(tap);
        run(game, 0.4);
        game.line.tapAt(tap);
        expect(game.line.state, HookState.reeling);
        expect(game.line.hook.distanceTo(tap), greaterThan(10));
      },
    );

    testWithGame<HookGame>('boat stops when the hook goes out', createGame, (
      game,
    ) async {
      await startRound(game);
      game.boat.moveBy(-150);
      run(game, 0.2);
      game.line.tapAt(null);
      final x = game.boat.x;
      run(game, 1);
      expect(game.boat.x, x);
    });
  });
}

/// Distance from [p] to the infinite line through [a] and [b].
double distanceToLine(Vector2 p, Vector2 a, Vector2 b) {
  final ab = b - a;
  final ap = p - a;
  return (ab.x * ap.y - ab.y * ap.x).abs() / ab.length;
}

Future<Creature> placeAt(HookGame game, CreatureType type, Vector2 at) async {
  final creature = Creature(
    type: type,
    start: at.clone(),
    speed: 0,
    direction: 1,
  );
  game.add(creature);
  await game.ready();
  return creature;
}
