import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'data/game_config.dart';
import 'data/save_data.dart';
import 'game/hook_game.dart';
import 'ui/overlays.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  final save = await SaveData.load();
  runApp(HookAndCatchApp(save: save));
}

class HookAndCatchApp extends StatefulWidget {
  const HookAndCatchApp({super.key, required this.save});

  final SaveData save;

  @override
  State<HookAndCatchApp> createState() => _HookAndCatchAppState();
}

class _HookAndCatchAppState extends State<HookAndCatchApp> {
  // Created once so rebuilds don't restart the game.
  late final HookGame _game = HookGame(save: widget.save);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hook & Catch',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF0277BD),
        brightness: Brightness.dark,
      ),
      home: Scaffold(
        backgroundColor: const Color(0xFF041F45),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: GameConfig.maxGameWidth,
            ),
            child: ClipRect(
              child: GameWidget<HookGame>(
                game: _game,
                initialActiveOverlays: const [Overlays.menu],
                overlayBuilderMap: {
                  Overlays.menu: (context, game) => MainMenu(game: game),
                  Overlays.hud: (context, game) => Hud(game: game),
                  Overlays.rotate: (context, game) => const RotateOverlay(),
                  Overlays.gameOver: (context, game) =>
                      GameOverMenu(game: game),
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
