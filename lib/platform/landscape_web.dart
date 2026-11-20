import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Goes fullscreen and locks the screen to landscape.
///
/// Must be called from a user tap (browsers only allow fullscreen then).
/// Fails quietly where unsupported, e.g. iPhone Safari or desktop browsers.
Future<void> enterLandscapeFullscreen() async {
  try {
    if (web.document.fullscreenElement == null) {
      await web.document.documentElement?.requestFullscreen().toDart;
    }
  } catch (_) {
    // Fullscreen not supported or refused.
  }
  try {
    // Android Chrome only allows the lock while fullscreen.
    await web.window.screen.orientation.lock('landscape').toDart;
  } catch (_) {
    // Orientation lock not supported (iPhone, desktop).
  }
}
