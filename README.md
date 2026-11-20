# Hook & Catch

A small 2D fishing game made with Flutter and [Flame](https://flame-engine.org/).
Everything is drawn in code, with no image files.

**Play in your browser:** https://sheriefsobhy.github.io/hook-and-catch/

## How to play

- Drag left/right to move the boat (or use the arrow keys).
- Tap the water to cast the hook toward that spot (up to the max reach).
  Tap the sky, or press Space, to drop it straight down. Tap again to reel it in.
- The boat can't move while the hook is out.
- The hook catches the first thing it touches. Deeper fish are rarer and worth more.
- Watch out: old boots are worthless and heavy, and jellyfish cut your line.
- Each round lasts 60 seconds. Spend coins on upgrades between rounds.

## Tuning

All the game numbers (fish values, speeds, upgrade costs, round time) are in
[lib/data/game_config.dart](lib/data/game_config.dart).

## Run locally

```sh
flutter pub get
flutter run            # on a phone or emulator
flutter run -d chrome  # in the browser
flutter analyze
flutter test
```

Every push to `main` builds the web version and deploys it to GitHub Pages
(see [.github/workflows/deploy.yml](.github/workflows/deploy.yml)).
