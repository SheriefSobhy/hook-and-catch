import 'package:flutter/material.dart';

import '../data/game_config.dart';
import '../game/hook_game.dart';

const _gold = Color(0xFFFFD23F);
const _panel = Color(0xE6082A54);

/// Coins and time at the top of the screen during a round.
class Hud extends StatelessWidget {
  const Hud({super.key, required this.game});

  final HookGame game;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            ValueListenableBuilder<int>(
              valueListenable: game.roundCoins,
              builder: (context, coins, _) => _Pill(
                icon: Icons.monetization_on,
                iconColor: _gold,
                text: '$coins',
              ),
            ),
            ValueListenableBuilder<int>(
              valueListenable: game.secondsLeft,
              builder: (context, seconds, _) => _Pill(
                icon: Icons.timer,
                iconColor: seconds <= 10 ? Colors.redAccent : Colors.white,
                text: '$seconds',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.icon,
    required this.iconColor,
    required this.text,
  });

  final IconData icon;
  final Color iconColor;
  final String text;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0x99062040),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: iconColor, size: 22),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

/// Title screen with the shop and a Play button.
class MainMenu extends StatelessWidget {
  const MainMenu({super.key, required this.game});

  final HookGame game;

  @override
  Widget build(BuildContext context) {
    return _Screen(
      children: [
        const Text(
          'Hook & Catch',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: 38,
            fontWeight: FontWeight.w900,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Drag to move the boat. Tap to drop the hook,\n'
          'tap again to reel in. Deeper fish pay more!\n'
          'Avoid jellyfish: they cut your line.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.4),
        ),
        const SizedBox(height: 14),
        _Wallet(game: game),
        const SizedBox(height: 12),
        Shop(game: game),
        const SizedBox(height: 16),
        _BigButton(label: 'Play', onPressed: game.startRound),
      ],
    );
  }
}

/// End of round: score, best score, shop and Play again.
class GameOverMenu extends StatelessWidget {
  const GameOverMenu({super.key, required this.game});

  final HookGame game;

  @override
  Widget build(BuildContext context) {
    return _Screen(
      children: [
        const Text(
          "Time's up!",
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: 34,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Score: ${game.roundCoins.value}',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: _gold,
            fontSize: 30,
            fontWeight: FontWeight.w800,
          ),
        ),
        if (game.lastRoundWasBest)
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text(
              'New best score!',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.lightGreenAccent,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        const SizedBox(height: 12),
        _Wallet(game: game),
        const SizedBox(height: 12),
        Shop(game: game),
        const SizedBox(height: 16),
        _BigButton(label: 'Play again', onPressed: game.startRound),
      ],
    );
  }
}

class _Screen extends StatelessWidget {
  const _Screen({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0x66000814),
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeOutBack,
              builder: (context, t, child) => Opacity(
                opacity: t.clamp(0.0, 1.0),
                child: Transform.scale(scale: 0.85 + 0.15 * t, child: child),
              ),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 420),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: _panel,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0x55FFFFFF)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: children,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Wallet extends StatelessWidget {
  const _Wallet({required this.game});

  final HookGame game;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: game.save,
      builder: (context, _) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _Stat(
            icon: Icons.monetization_on,
            color: _gold,
            label: 'Coins',
            value: '${game.save.coins}',
          ),
          _Stat(
            icon: Icons.emoji_events,
            color: Colors.orangeAccent,
            label: 'Best',
            value: '${game.save.bestScore}',
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final Color color;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 26),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(color: Colors.white60, fontSize: 12),
            ),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Lets the player spend coins on upgrades.
class Shop extends StatelessWidget {
  const Shop({super.key, required this.game});

  final HookGame game;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: game.save,
      builder: (context, _) => Column(
        children: [
          for (final type in UpgradeType.values)
            _UpgradeRow(game: game, type: type),
        ],
      ),
    );
  }
}

class _UpgradeRow extends StatelessWidget {
  const _UpgradeRow({required this.game, required this.type});

  final HookGame game;
  final UpgradeType type;

  String _format(double value) => switch (type) {
    UpgradeType.line => '${(value * GameConfig.waterDepthMeters).round()} m',
    UpgradeType.hook || UpgradeType.boat => '${value.round()}',
  };

  @override
  Widget build(BuildContext context) {
    final save = game.save;
    final info = GameConfig.upgrades[type]!;
    final level = save.level(type);
    final cost = save.nextCost(type);
    final current = _format(info.values[level]);
    final next = cost == null ? null : _format(info.values[level + 1]);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0x22FFFFFF),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  info.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  next == null ? '$current (max)' : '$current → $next',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    for (var i = 0; i < info.maxLevel; i++)
                      Container(
                        width: 14,
                        height: 6,
                        margin: const EdgeInsets.only(right: 3),
                        decoration: BoxDecoration(
                          color: i < level ? _gold : const Color(0x33FFFFFF),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: save.canBuy(type) ? () => save.buy(type) : null,
            style: FilledButton.styleFrom(
              backgroundColor: _gold,
              foregroundColor: const Color(0xFF3E2723),
              disabledBackgroundColor: const Color(0x33FFFFFF),
              disabledForegroundColor: Colors.white54,
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (cost != null) const Icon(Icons.monetization_on, size: 16),
                if (cost != null) const SizedBox(width: 4),
                Text(
                  cost == null ? 'MAX' : '$cost',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BigButton extends StatelessWidget {
  const _BigButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: const Color(0xFF26C6DA),
        foregroundColor: const Color(0xFF002B36),
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
      ),
    );
  }
}
