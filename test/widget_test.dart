import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hook_and_catch/data/game_config.dart';
import 'package:hook_and_catch/data/save_data.dart';
import 'package:hook_and_catch/game/hook_game.dart';
import 'package:hook_and_catch/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Landscape phone and browser sizes (logical pixels).
const landscapeSizes = [
  Size(568, 320), // Small phone
  Size(667, 375),
  Size(740, 340), // Android with browser bars
  Size(844, 390), // Large phone
  Size(1280, 720), // Laptop
];

Future<void> frames(WidgetTester tester, int count) async {
  for (var i = 0; i < count; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<HookGame> pumpApp(
  WidgetTester tester,
  Size size, {
  Map<String, Object> saved = const {},
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues(saved);
  final save = await SaveData.load();
  await tester.pumpWidget(HookAndCatchApp(save: save));
  await frames(tester, 10);
  return tester
      .widget<GameWidget<HookGame>>(find.byType(GameWidget<HookGame>))
      .game!;
}

/// The whole panel must be visible inside the screen.
void expectOnScreen(WidgetTester tester, Finder finder, Size size) {
  final rect = tester.getRect(finder);
  expect(rect.left, greaterThanOrEqualTo(-0.5));
  expect(rect.top, greaterThanOrEqualTo(-0.5));
  expect(rect.right, lessThanOrEqualTo(size.width + 0.5));
  expect(rect.bottom, lessThanOrEqualTo(size.height + 0.5));
}

void main() {
  testWidgets('menu shows, Play starts a round with the HUD', (tester) async {
    await pumpApp(
      tester,
      const Size(844, 390),
      saved: {'coins': 100, 'best_score': 42},
    );

    expect(find.text('Hook & Catch'), findsOneWidget);
    expect(find.text('Play'), findsOneWidget);
    expect(find.text('100'), findsOneWidget); // coins
    expect(find.text('42'), findsOneWidget); // best score
    expect(find.text('Longer Line'), findsOneWidget);

    // Buy the cheapest upgrade (boat speed costs 25).
    await tester.tap(find.text('25'));
    await tester.pump();
    expect(find.text('75'), findsOneWidget);

    await tester.tap(find.text('Play'));
    await frames(tester, 5);
    expect(find.text('Play'), findsNothing);
    expect(find.byIcon(Icons.timer), findsOneWidget);
  });

  for (final size in landscapeSizes) {
    testWidgets('menus fit ${size.width.toInt()}x${size.height.toInt()} '
        'without scrolling or overflow', (tester) async {
      final game = await pumpApp(tester, size, saved: {'coins': 500});

      // Main menu: everything visible, nothing scrolls.
      expect(find.byType(Scrollable), findsNothing);
      for (final text in [
        'Hook & Catch',
        'Play',
        'Longer Line',
        'Boat Speed',
      ]) {
        expectOnScreen(tester, find.text(text), size);
      }

      // Game over screen too.
      await tester.tap(find.text('Play'));
      await frames(tester, 5);
      game.endRound();
      await frames(tester, 10);
      expect(find.text("Time's up!"), findsOneWidget);
      expect(find.byType(Scrollable), findsNothing);
      for (final text in ["Time's up!", 'Play again', 'Faster Hook']) {
        expectOnScreen(tester, find.text(text), size);
      }
      // Flutter reports any overflow as a test failure automatically.
    });

    testWidgets('HUD, sun and boat do not touch at '
        '${size.width.toInt()}x${size.height.toInt()}', (tester) async {
      final game = await pumpApp(tester, size);
      await tester.tap(find.text('Play'));
      await frames(tester, 10);

      Rect badge(IconData icon) => tester.getRect(
        find.ancestor(
          of: find.byIcon(icon),
          matching: find.byType(AnimatedContainer),
        ),
      );
      final coins = badge(Icons.monetization_on);
      final timer = badge(Icons.timer);
      expect(coins.right, lessThan(timer.left));

      final sun = Rect.fromCircle(
        center: Offset(
          size.width * GameConfig.sunXFraction,
          game.surfaceY * GameConfig.sunYFraction,
        ),
        radius: GameConfig.sunGlowRadius,
      );
      expect(sun.overlaps(coins), isFalse);
      expect(sun.overlaps(timer), isFalse);

      // The rod tip (top of the boat) is below both badges.
      expect(game.boat.rodTip.y, greaterThan(timer.bottom));
      expect(game.boat.rodTip.y, greaterThan(coins.bottom));
    });
  }

  testWidgets('portrait shows the rotate message and pauses the round', (
    tester,
  ) async {
    final game = await pumpApp(tester, const Size(844, 390));
    await tester.tap(find.text('Play'));
    await frames(tester, 10);
    expect(find.text('Rotate your phone to play'), findsNothing);

    // Turn the phone to portrait.
    tester.view.physicalSize = const Size(390, 844);
    await frames(tester, 5);
    expect(find.text('Rotate your phone to play'), findsOneWidget);
    expect(find.byIcon(Icons.screen_rotation), findsOneWidget);
    final seconds = game.secondsLeft.value;
    await frames(tester, 40); // 2 seconds
    expect(game.secondsLeft.value, seconds);

    // Back to landscape: resumes automatically.
    tester.view.physicalSize = const Size(844, 390);
    await frames(tester, 40);
    expect(find.text('Rotate your phone to play'), findsNothing);
    expect(game.secondsLeft.value, lessThan(seconds));
  });
}
