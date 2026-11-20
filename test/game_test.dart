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

    game.line.onTap();
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
    game.line.onTap();
    run(game, 0.3);
    game.line.onTap();
    expect(game.line.state, HookState.reeling);
  });

  testWithGame<HookGame>('catching a fish earns its coins', createGame, (
    game,
  ) async {
    await startRound(game);
    final sardine = typeOf(CreatureKind.fish);
    final fish = await placeUnderHook(game, sardine);

    game.line.onTap();
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
    game.line.onTap();
    run(game, 6);
    expect(game.line.state, HookState.ready);
    expect(game.roundCoins.value, 0);
  });

  testWithGame<HookGame>('jellyfish cuts the line', createGame, (game) async {
    await startRound(game);
    final jelly = await placeUnderHook(game, typeOf(CreatureKind.jellyfish));
    game.line.onTap();
    run(game, 1);
    expect(game.line.state, HookState.cut);
    expect(jelly.hooked, isFalse);

    game.line.onTap(); // Tapping does nothing while the line is cut.
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
}
