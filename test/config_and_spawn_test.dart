import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:hook_and_catch/data/game_config.dart';
import 'package:hook_and_catch/game/spawn_logic.dart';

void main() {
  group('GameConfig', () {
    test('every upgrade has one more value than costs', () {
      for (final info in GameConfig.upgrades.values) {
        expect(info.values.length, info.costs.length + 1, reason: info.name);
        expect(info.costs, everyElement(greaterThan(0)));
      }
      expect(GameConfig.upgrades.keys.toSet(), UpgradeType.values.toSet());
    });

    test('creature depth and speed ranges are valid', () {
      for (final c in GameConfig.creatures) {
        expect(c.minDepth, inInclusiveRange(0, 1), reason: c.name);
        expect(c.maxDepth, inInclusiveRange(c.minDepth, 1), reason: c.name);
        expect(c.maxSpeed, greaterThanOrEqualTo(c.minSpeed), reason: c.name);
        expect(c.spawnWeight, greaterThan(0), reason: c.name);
      }
    });

    test('deeper fish are rarer and worth more', () {
      final fish =
          GameConfig.creatures
              .where((c) => c.kind == CreatureKind.fish)
              .toList()
            ..sort((a, b) => a.minDepth.compareTo(b.minDepth));
      for (var i = 1; i < fish.length; i++) {
        expect(fish[i].value, greaterThan(fish[i - 1].value));
        expect(fish[i].spawnWeight, lessThan(fish[i - 1].spawnWeight));
      }
    });

    test('has bad things: a boot and a jellyfish', () {
      final kinds = GameConfig.creatures.map((c) => c.kind).toSet();
      expect(kinds, containsAll(CreatureKind.values));
    });
  });

  group('spawn logic', () {
    test('weighted pick follows spawn weights', () {
      final random = Random(42);
      final counts = <String, int>{};
      for (var i = 0; i < 20000; i++) {
        final t = pickCreatureType(random);
        counts[t.name] = (counts[t.name] ?? 0) + 1;
      }
      expect(counts['Sardine']!, greaterThan(counts['Golden Koi']! * 5));
      expect(counts.length, GameConfig.creatures.length);
    });

    test('depth and speed stay in range', () {
      final random = Random(1);
      for (final type in GameConfig.creatures) {
        for (var i = 0; i < 50; i++) {
          expect(
            pickDepth(random, type),
            inInclusiveRange(type.minDepth, type.maxDepth),
          );
          expect(
            pickSpeed(random, type),
            inInclusiveRange(type.minSpeed, type.maxSpeed),
          );
        }
      }
    });
  });
}
