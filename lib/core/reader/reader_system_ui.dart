import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum ReaderTopBarStyle { system, reader, hidden }

ReaderTopBarStyle readerTopBarStyleFromName(
  String? name, {
  ReaderTopBarStyle fallback = ReaderTopBarStyle.reader,
}) {
  return ReaderTopBarStyle.values.firstWhere(
    (style) => style.name == name,
    orElse: () => fallback,
  );
}

/// Applies the system-bar preference shared by every reader entry point.
class ReaderSystemUiController {
  const ReaderSystemUiController._();

  static const preferenceKey = 'readerTopBarStyle';
  static const legacyPreferenceKey = 'readerShowSystemStatusBar';
  static const MethodChannel _androidChannel = MethodChannel(
    'com.niki.xxread/fullscreen',
  );
  static const MethodChannel _iosReaderUiChannel = MethodChannel(
    'com.niki.xxread/reader_ui',
  );

  static Future<ReaderTopBarStyle> loadPreference() async {
    final prefs = await SharedPreferences.getInstance();
    final storedStyle = prefs.getString(preferenceKey);
    if (storedStyle != null) {
      return readerTopBarStyleFromName(storedStyle);
    }

    final legacyValue = prefs.getBool(legacyPreferenceKey);
    final migratedStyle = legacyValue == true
        ? ReaderTopBarStyle.system
        : ReaderTopBarStyle.reader;
    await prefs.setString(preferenceKey, migratedStyle.name);
    return migratedStyle;
  }

  static Future<void> savePreference(ReaderTopBarStyle style) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(preferenceKey, style.name);
  }

  static Future<ReaderTopBarStyle> applySavedPreference({
    SystemUiOverlayStyle? overlayStyle,
  }) async {
    final style = await loadPreference();
    await apply(style: style, overlayStyle: overlayStyle);
    return style;
  }

  static Future<void> apply({
    required ReaderTopBarStyle style,
    SystemUiOverlayStyle? overlayStyle,
  }) async {
    final showStatusBar = style == ReaderTopBarStyle.system;
    var handledByHost = false;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      try {
        await _androidChannel.invokeMethod<void>(
          showStatusBar ? 'showReaderStatusBar' : 'hideSystemUI',
        );
        handledByHost = true;
      } on MissingPluginException {
        // Isolated widget tests and add-to-app previews may not have a host.
      } on PlatformException {
        // Fall back to Flutter's system UI API if the host rejects the call.
      }
    }

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      try {
        await _iosReaderUiChannel.invokeMethod<void>('setReaderImmersive', {
          'enabled': !showStatusBar,
        });
      } on MissingPluginException {
        // Widget tests and non-standard hosts may not install the bridge.
      } on PlatformException {
        // Flutter's system UI mode still provides the status-bar fallback.
      }
    }

    if (!handledByHost) {
      if (showStatusBar) {
        await SystemChrome.setEnabledSystemUIMode(
          SystemUiMode.manual,
          overlays: const [SystemUiOverlay.top],
        );
      } else {
        await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      }
    }
    if (overlayStyle != null) {
      SystemChrome.setSystemUIOverlayStyle(overlayStyle);
    }
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
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      try {
        await _iosReaderUiChannel.invokeMethod<void>('setReaderImmersive', {
          'enabled': false,
        });
      } on MissingPluginException {
        // Fall through to Flutter's cross-platform implementation.
      } on PlatformException {
        // Fall through to Flutter's cross-platform implementation.
      }
    }
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }
}
