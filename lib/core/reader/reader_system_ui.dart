import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Applies the system-bar preference shared by every reader entry point.
class ReaderSystemUiController {
  const ReaderSystemUiController._();

  static const preferenceKey = 'readerShowSystemStatusBar';
  static const MethodChannel _androidChannel =
      MethodChannel('com.niki.xxread/fullscreen');

  static Future<bool> applySavedPreference() async {
    final prefs = await SharedPreferences.getInstance();
    final showStatusBar = prefs.getBool(preferenceKey) ?? false;
    await apply(showStatusBar: showStatusBar);
    return showStatusBar;
  }

  static Future<void> apply({required bool showStatusBar}) async {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      try {
        await _androidChannel.invokeMethod<void>(
          showStatusBar ? 'showReaderStatusBar' : 'hideSystemUI',
        );
        return;
      } on MissingPluginException {
        // Isolated widget tests and add-to-app previews may not have a host.
      } on PlatformException {
        // Fall back to Flutter's system UI API if the host rejects the call.
      }
    }

    if (showStatusBar) {
      await SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.manual,
        overlays: const [SystemUiOverlay.top],
      );
      return;
    }
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  static Future<void> restore() async {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      try {
        await _androidChannel.invokeMethod<void>('showSystemUI');
        return;
      } on MissingPluginException {
        // Fall through to Flutter's cross-platform implementation.
      } on PlatformException {
        // Fall through to Flutter's cross-platform implementation.
      }
    }
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }
}
