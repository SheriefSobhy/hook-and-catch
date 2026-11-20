/// Asks the browser for fullscreen + landscape. Does nothing on other
/// platforms (Android/iOS apps use SystemChrome in main.dart instead).
library;

export 'landscape_stub.dart' if (dart.library.js_interop) 'landscape_web.dart';
