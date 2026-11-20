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
  for (final name in Overlays.all) {
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
  game.onGameResize(Vector2(800, 400));
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
      final tap = tip + Vector2(250, 120);
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
      final tap = tip + Vector2(-260, 110);
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
        final tap = tip + Vector2(300, 120);
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

  group('landscape', () {
    testWithGame<HookGame>(
      'portrait pauses the round, landscape resumes it',
      createGame,
      (game) async {
        await startRound(game);
        run(game, 1);
        final seconds = game.secondsLeft.value;

        game.onGameResize(Vector2(400, 800)); // Phone turned to portrait.
        run(game, 5);
        expect(game.pausedForRotation, isTrue);
        expect(game.overlays.isActive(Overlays.rotate), isTrue);
        expect(game.secondsLeft.value, seconds, reason: 'timer is frozen');
        game.line.tapAt(Vector2(300, 300));
        expect(game.canPlay, isFalse);

        game.onGameResize(Vector2(800, 400)); // Back to landscape.
        run(game, 2);
        expect(game.pausedForRotation, isFalse);
        expect(game.overlays.isActive(Overlays.rotate), isFalse);
        expect(game.secondsLeft.value, lessThan(seconds));
      },
    );

    testWithGame<HookGame>(
      'portrait menu does not pause anything',
      createGame,
      (game) async {
        game.onGameResize(Vector2(400, 800));
        run(game, 1);
        expect(game.phase, GamePhase.menu);
        expect(game.pausedForRotation, isFalse);
        expect(game.overlays.isActive(Overlays.rotate), isFalse);
      },
    );

    for (final screen in [
      Vector2(568, 320), // Small phone
      Vector2(667, 375),
      Vector2(844, 390), // Large phone
      Vector2(915, 412),
      Vector2(1280, 720), // Laptop browser
    ]) {
      testWithGame<HookGame>(
        'layout fits a ${screen.x}x${screen.y} screen',
        createGame,
        (game) async {
          game.onGameResize(screen);
          game.startRound();
          await game.ready();
          run(game, 0.5);

          final surface = game.surfaceY;
          final seabed = game.seabedY;
          expect(surface, greaterThanOrEqualTo(GameConfig.minSkyHeight));
          expect(seabed, lessThan(screen.y));
          expect(seabed - surface, greaterThan(screen.y * 0.5));

          // Rod tip and boat stay below the HUD badges (about 44 px tall).
          expect(game.boat.rodTip.y, greaterThan(46));
          expect(game.boat.rodTip.y, lessThan(surface));

          // Sun stays inside the sky.
          final sunY = surface * GameConfig.sunYFraction;
          expect(sunY - GameConfig.sunGlowRadius, greaterThan(0));
          expect(sunY + GameConfig.sunGlowRadius, lessThan(surface));

          // Dashed max-depth line is in the water at every line level.
          expect(game.maxHookY, greaterThan(surface));
          expect(game.maxHookY, lessThan(seabed));
          final deepest =
              surface +
              (seabed - surface) *
                  GameConfig.upgrades[UpgradeType.line]!.values.last;
          expect(deepest, lessThanOrEqualTo(seabed));

          // Every spawn lane is in the water, below the surface.
          for (final type in GameConfig.creatures) {
            final top = surface + (seabed - surface) * type.minDepth;
            final bottom = surface + (seabed - surface) * type.maxDepth;
            expect(
              top - type.height / 2,
              greaterThan(surface - 4),
              reason: type.name,
            );
            expect(bottom, lessThan(seabed), reason: type.name);
          }

          // Boat can reach both edges, and the cast uses the extra width.
          expect(game.boat.maxX - game.boat.minX, greaterThan(screen.x * 0.8));
          final tip = game.boat.rodTip.clone();
          game.line.tapAt(Vector2(screen.x - 5, surface + 20));
          expect(game.line.target.x - tip.x, greaterThan(160));
        },
      );
    }
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
