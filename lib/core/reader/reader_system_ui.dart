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

  static Future<ReaderTopBarStyle> applySavedPreference() async {
    final style = await loadPreference();
    await apply(style: style);
    return style;
  }

  static Future<void> apply({required ReaderTopBarStyle style}) async {
    final showStatusBar = style == ReaderTopBarStyle.system;
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
