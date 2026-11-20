import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'game_config.dart';

/// Coins, best score and upgrade levels, saved with shared_preferences.
class SaveData extends ChangeNotifier {
  SaveData._(this._prefs, this._coins, this._bestScore, this._levels);

  static const _coinsKey = 'coins';
  static const _bestKey = 'best_score';
  static String _levelKey(UpgradeType type) => 'upgrade_${type.name}';

  final SharedPreferences _prefs;
  int _coins;
  int _bestScore;
  final Map<UpgradeType, int> _levels;

  static Future<SaveData> load() async {
    final prefs = await SharedPreferences.getInstance();
    final levels = <UpgradeType, int>{
      for (final type in UpgradeType.values)
        type: (prefs.getInt(_levelKey(type)) ?? 0).clamp(
          0,
          GameConfig.upgrades[type]!.maxLevel,
        ),
    };
    return SaveData._(
      prefs,
      (prefs.getInt(_coinsKey) ?? 0).clamp(0, 999999999),
      (prefs.getInt(_bestKey) ?? 0).clamp(0, 999999999),
      levels,
    );
  }

  int get coins => _coins;
  int get bestScore => _bestScore;

  int level(UpgradeType type) => _levels[type]!;

  bool isMaxed(UpgradeType type) =>
      level(type) >= GameConfig.upgrades[type]!.maxLevel;

  /// Current value of an upgrade (depth fraction, hook speed or boat speed).
  double value(UpgradeType type) =>
      GameConfig.upgrades[type]!.values[level(type)];

  /// Price of the next level, or null when already maxed.
  int? nextCost(UpgradeType type) =>
      isMaxed(type) ? null : GameConfig.upgrades[type]!.costs[level(type)];

  bool canBuy(UpgradeType type) {
    final cost = nextCost(type);
    return cost != null && _coins >= cost;
  }

  /// Buys the next level. Returns false if maxed or not enough coins.
  bool buy(UpgradeType type) {
    final cost = nextCost(type);
    if (cost == null || _coins < cost) return false;
    _coins -= cost;
    _levels[type] = level(type) + 1;
    _prefs.setInt(_coinsKey, _coins);
    _prefs.setInt(_levelKey(type), _levels[type]!);
    notifyListeners();
    return true;
  }

  /// Adds the round's coins to the wallet. Returns true on a new best score.
  bool finishRound(int score) {
    _coins += score;
    final newBest = score > _bestScore;
    if (newBest) _bestScore = score;
    _prefs.setInt(_coinsKey, _coins);
    _prefs.setInt(_bestKey, _bestScore);
    notifyListeners();
    return newBest;
  }
}
