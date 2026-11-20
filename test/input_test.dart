import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hook_and_catch/data/save_data.dart';
import 'package:hook_and_catch/game/components/fishing_line.dart';
import 'package:hook_and_catch/game/hook_game.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Real finger gestures on the game widget.
void main() {
  late HookGame game;

  Future<void> frames(WidgetTester tester, int count) async {
    for (var i = 0; i < count; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
  }

  Future<void> setUpGame(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final save = await SaveData.load();
    game = HookGame(save: save)..spawningEnabled = false;
    await tester.pumpWidget(
      GameWidget<HookGame>(
        game: game,
        overlayBuilderMap: {
          for (final name in Overlays.all)
            name: (_, _) => const SizedBox.shrink(),
        },
      ),
    );
    await frames(tester, 5);
    game.startRound();
    await frames(tester, 30);
  }

  testWidgets('dragging moves the boat and does not drop the hook', (
    tester,
  ) async {
    await setUpGame(tester);
    final startX = game.boat.x;

    await tester.dragFrom(const Offset(400, 300), const Offset(-150, 0));
    await frames(tester, 90);

    expect(game.line.state, HookState.ready);
    expect(game.boat.x, lessThan(startX - 100));
  });

  testWidgets('tapping the water casts toward the tap point', (tester) async {
    await setUpGame(tester);
    final tip = game.boat.rodTip.clone();

    await tester.tapAt(Offset(tip.x + 200, 180));
    await frames(tester, 5);

    expect(game.line.state, HookState.dropping);
    expect(game.line.target.x, greaterThan(tip.x + 120));
    expect(game.line.target.y, greaterThan(game.surfaceY));
  });

  testWidgets('dragging while the hook is out does not move the boat', (
    tester,
  ) async {
    await setUpGame(tester);
    await tester.tapAt(const Offset(600, 250));
    await frames(tester, 5);
    expect(game.line.isOut, isTrue);
    final x = game.boat.x;

    await tester.dragFrom(const Offset(300, 320), const Offset(150, 0));
    await frames(tester, 20);

    expect(game.line.isOut, isTrue);
    expect(game.boat.x, x);
  });

  testWidgets('space drops the hook straight down', (tester) async {
    await setUpGame(tester);
    final tip = game.boat.rodTip.clone();

    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await frames(tester, 5);

    expect(game.line.state, HookState.dropping);
    expect(game.line.target.x, closeTo(tip.x, 0.5));
    expect(game.line.target.y, closeTo(game.maxHookY, 0.001));
  });
}
