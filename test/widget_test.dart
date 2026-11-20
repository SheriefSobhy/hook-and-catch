import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hook_and_catch/data/save_data.dart';
import 'package:hook_and_catch/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('menu shows, Play starts a round with the HUD', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({'coins': 100, 'best_score': 42});
    final save = await SaveData.load();

    await tester.pumpWidget(HookAndCatchApp(save: save));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

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
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('Play'), findsNothing);
    expect(find.byIcon(Icons.timer), findsOneWidget);
  });
}
