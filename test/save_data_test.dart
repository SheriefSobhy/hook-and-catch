import 'package:flutter_test/flutter_test.dart';
import 'package:hook_and_catch/data/game_config.dart';
import 'package:hook_and_catch/data/save_data.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('starts empty', () async {
    final save = await SaveData.load();
    expect(save.coins, 0);
    expect(save.bestScore, 0);
    for (final type in UpgradeType.values) {
      expect(save.level(type), 0);
    }
  });

  test('finishing rounds adds coins and tracks best score', () async {
    final save = await SaveData.load();
    expect(save.finishRound(50), isTrue);
    expect(save.finishRound(20), isFalse);
    expect(save.coins, 70);
    expect(save.bestScore, 50);

    final reloaded = await SaveData.load();
    expect(reloaded.coins, 70);
    expect(reloaded.bestScore, 50);
  });

  test('buying upgrades costs coins, saves, and stops at max', () async {
    final save = await SaveData.load();
    final info = GameConfig.upgrades[UpgradeType.line]!;
    expect(save.buy(UpgradeType.line), isFalse, reason: 'no coins yet');

    final total = info.costs.reduce((a, b) => a + b);
    save.finishRound(total + 5);
    for (var i = 0; i < info.maxLevel; i++) {
      expect(save.buy(UpgradeType.line), isTrue);
    }
    expect(save.isMaxed(UpgradeType.line), isTrue);
    expect(save.nextCost(UpgradeType.line), isNull);
    expect(save.buy(UpgradeType.line), isFalse);
    expect(save.coins, 5);
    expect(save.value(UpgradeType.line), info.values.last);

    final reloaded = await SaveData.load();
    expect(reloaded.level(UpgradeType.line), info.maxLevel);
    expect(reloaded.coins, 5);
  });

  test('bad saved levels are clamped', () async {
    SharedPreferences.setMockInitialValues({'upgrade_boat': 99});
    final save = await SaveData.load();
    expect(
      save.level(UpgradeType.boat),
      GameConfig.upgrades[UpgradeType.boat]!.maxLevel,
    );
  });
}
