import 'dart:ui';

/// All gameplay numbers live in this file. Change them here to tune the game.
///
/// Depths are fractions of the water column: 0.0 = water surface,
/// 1.0 = sea floor. This keeps the game working on any screen size.
class GameConfig {
  GameConfig._();

  // ---------------------------------------------------------------- Round
  /// Length of one round in seconds.
  static const int roundSeconds = 60;

  /// Largest frame time used by the simulation (prevents big jumps when the
  /// browser tab was in the background).
  static const double maxFrameTime = 0.05;

  // --------------------------------------------------------------- Layout
  /// Water surface position as a fraction of the screen height.
  static const double surfaceFraction = 0.2;

  /// Height of the sandy sea floor in logical pixels.
  static const double seabedHeight = 46;

  /// Max width of the game area (keeps it portrait-shaped on wide screens).
  static const double maxGameWidth = 520;

  /// Water depth shown to the player, used only for the "m" labels in the shop.
  static const double waterDepthMeters = 60;

  // ------------------------------------------------------------------ Boat
  /// How far the boat moves per pixel of finger drag.
  static const double dragSensitivity = 1.0;

  /// Up/down bobbing of the boat on the waves.
  static const double boatBobAmount = 3;
  static const double boatBobSpeed = 2.2;

  // ------------------------------------------------------------------ Hook
  /// Reeling up is this many times faster than dropping.
  static const double reelSpeedMultiplier = 1.35;

  /// Reeling speed multiplier while carrying a heavy old boot.
  static const double bootReelSlowdown = 0.45;

  /// Seconds the line is unusable after a jellyfish cuts it.
  static const double lineCutCooldown = 1.6;

  /// Extra pickup radius around the hook in pixels.
  static const double hookCatchRadius = 7;

  /// How quickly the hook swings back under the boat (higher = stiffer).
  static const double hookFollowStrength = 6;

  /// Hook travel speed along its path, as a multiple of the "Faster Hook"
  /// upgrade value. 1.0 = same speed for angled and straight drops.
  static const double hookTravelSpeedMultiplier = 1.0;

  /// Furthest the hook can go sideways from the rod tip, in pixels.
  static const double maxSidewaysReach = 160;

  /// Total line length = straight-down reach x this factor. Stops long
  /// diagonal casts from going further than the line allows.
  static const double lineLengthFactor = 1.15;

  // ------------------------------------------------------------- Spawning
  /// Maximum creatures in the water at once.
  static const int maxCreatures = 13;

  /// Seconds between spawns while below [maxCreatures].
  static const double spawnInterval = 0.55;

  /// Creatures already swimming when a round starts.
  static const int creaturesAtRoundStart = 8;

  /// Ambient bubbles per second rising from the sea floor.
  static const double bubblesPerSecond = 5;

  // -------------------------------------------------------------- Upgrades
  static const Map<UpgradeType, UpgradeInfo> upgrades = {
    UpgradeType.line: UpgradeInfo(
      name: 'Longer Line',
      description: 'Reach deeper, richer fish',
      // Max hook depth (fraction of water) for level 0, 1, 2, ...
      values: [0.42, 0.56, 0.70, 0.84, 1.0],
      // Cost to go from level 0->1, 1->2, ...
      costs: [40, 110, 240, 480],
    ),
    UpgradeType.hook: UpgradeInfo(
      name: 'Faster Hook',
      description: 'Hook drops and reels faster',
      // Hook drop speed in pixels per second.
      values: [190, 235, 285, 340, 400],
      costs: [30, 90, 200, 400],
    ),
    UpgradeType.boat: UpgradeInfo(
      name: 'Boat Speed',
      description: 'Move the boat faster',
      // Boat speed in pixels per second.
      values: [170, 230, 300, 380, 470],
      costs: [25, 70, 160, 340],
    ),
  };

  // ------------------------------------------------------------ Creatures
  /// Everything that swims. Deeper fish are rarer (lower spawn weight) and
  /// worth more coins.
  static const List<CreatureType> creatures = [
    CreatureType(
      name: 'Sardine',
      kind: CreatureKind.fish,
      value: 2,
      bodyColor: Color(0xFFB0C4DE),
      finColor: Color(0xFF7896B8),
      length: 26,
      height: 11,
      minSpeed: 75,
      maxSpeed: 115,
      minDepth: 0.06,
      maxDepth: 0.35,
      spawnWeight: 30,
    ),
    CreatureType(
      name: 'Clownfish',
      kind: CreatureKind.fish,
      value: 4,
      bodyColor: Color(0xFFFF8C1A),
      finColor: Color(0xFFE0600A),
      stripeColor: Color(0xFFFFFFFF),
      length: 30,
      height: 17,
      minSpeed: 55,
      maxSpeed: 85,
      minDepth: 0.12,
      maxDepth: 0.45,
      spawnWeight: 22,
    ),
    CreatureType(
      name: 'Parrotfish',
      kind: CreatureKind.fish,
      value: 8,
      bodyColor: Color(0xFF3CCB8F),
      finColor: Color(0xFF1E9E8A),
      length: 42,
      height: 20,
      minSpeed: 50,
      maxSpeed: 80,
      minDepth: 0.30,
      maxDepth: 0.62,
      spawnWeight: 15,
    ),
    CreatureType(
      name: 'Angelfish',
      kind: CreatureKind.fish,
      value: 15,
      bodyColor: Color(0xFF9B6BFF),
      finColor: Color(0xFF6A3FD6),
      stripeColor: Color(0xFFFFE066),
      length: 40,
      height: 30,
      minSpeed: 45,
      maxSpeed: 75,
      minDepth: 0.45,
      maxDepth: 0.76,
      spawnWeight: 9,
    ),
    CreatureType(
      name: 'Red Snapper',
      kind: CreatureKind.fish,
      value: 28,
      bodyColor: Color(0xFFE53950),
      finColor: Color(0xFFB0202F),
      length: 60,
      height: 26,
      minSpeed: 40,
      maxSpeed: 65,
      minDepth: 0.62,
      maxDepth: 0.90,
      spawnWeight: 6,
    ),
    CreatureType(
      name: 'Golden Koi',
      kind: CreatureKind.fish,
      value: 70,
      bodyColor: Color(0xFFFFD23F),
      finColor: Color(0xFFFFA000),
      length: 40,
      height: 19,
      minSpeed: 115,
      maxSpeed: 160,
      minDepth: 0.82,
      maxDepth: 0.97,
      spawnWeight: 2.5,
    ),
    CreatureType(
      name: 'Old Boot',
      kind: CreatureKind.boot,
      value: 0,
      bodyColor: Color(0xFF6D4C41),
      finColor: Color(0xFF3E2723),
      length: 34,
      height: 28,
      minSpeed: 15,
      maxSpeed: 30,
      minDepth: 0.20,
      maxDepth: 0.95,
      spawnWeight: 6,
    ),
    CreatureType(
      name: 'Jellyfish',
      kind: CreatureKind.jellyfish,
      value: 0,
      bodyColor: Color(0xCCFF77C8),
      finColor: Color(0x99FFB3E6),
      length: 30,
      height: 40,
      minSpeed: 14,
      maxSpeed: 28,
      minDepth: 0.22,
      maxDepth: 0.90,
      spawnWeight: 7,
    ),
  ];
}

enum UpgradeType { line, hook, boat }

enum CreatureKind {
  /// Normal fish: worth coins.
  fish,

  /// Junk: worth nothing and slows reeling.
  boot,

  /// Cuts the line: you lose the hook for a moment.
  jellyfish,
}

class UpgradeInfo {
  const UpgradeInfo({
    required this.name,
    required this.description,
    required this.values,
    required this.costs,
  });

  final String name;
  final String description;

  /// Value for each level; `values.length == costs.length + 1`.
  final List<double> values;

  /// Price of each next level.
  final List<int> costs;

  int get maxLevel => costs.length;
}

class CreatureType {
  const CreatureType({
    required this.name,
    required this.kind,
    required this.value,
    required this.bodyColor,
    required this.finColor,
    required this.length,
    required this.height,
    required this.minSpeed,
    required this.maxSpeed,
    required this.minDepth,
    required this.maxDepth,
    required this.spawnWeight,
    this.stripeColor,
  });

  final String name;
  final CreatureKind kind;

  /// Coins earned when landed.
  final int value;
  final Color bodyColor;
  final Color finColor;
  final Color? stripeColor;

  /// Size in logical pixels.
  final double length;
  final double height;

  /// Horizontal swim speed range in pixels per second.
  final double minSpeed;
  final double maxSpeed;

  /// Depth range (0 = surface, 1 = sea floor).
  final double minDepth;
  final double maxDepth;

  /// Relative chance of spawning. Higher = more common.
  final double spawnWeight;
}
