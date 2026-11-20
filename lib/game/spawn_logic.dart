import 'dart:math';

import '../data/game_config.dart';

/// Picks a creature type using the spawn weights (higher weight = more common).
CreatureType pickCreatureType(
  Random random, [
  List<CreatureType> types = GameConfig.creatures,
]) {
  final total = types.fold<double>(0, (sum, t) => sum + t.spawnWeight);
  var roll = random.nextDouble() * total;
  for (final type in types) {
    roll -= type.spawnWeight;
    if (roll < 0) return type;
  }
  return types.last;
}

/// Random depth fraction inside the creature's depth range.
double pickDepth(Random random, CreatureType type) =>
    type.minDepth + random.nextDouble() * (type.maxDepth - type.minDepth);

/// Random swim speed inside the creature's speed range.
double pickSpeed(Random random, CreatureType type) =>
    type.minSpeed + random.nextDouble() * (type.maxSpeed - type.minSpeed);
