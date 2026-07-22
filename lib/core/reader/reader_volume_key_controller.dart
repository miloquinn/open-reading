import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Connects Android hardware volume keys to the currently visible reader.
class ReaderVolumeKeyController {
  const ReaderVolumeKeyController._();

  static const preferenceKey = 'enableVolumeKeyTurn';
  static const MethodChannel _androidChannel = MethodChannel(
    'com.niki.xxread/reader_keys',
  );

  static Object? _activeOwner;
  static VoidCallback? _onNextPage;
  static VoidCallback? _onPreviousPage;
  static bool _enabled = false;
  static int _generation = 0;

  static bool get _supportsVolumePaging =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static Future<bool> activate({
    required Object owner,
    required bool pageTurningAvailable,
    required VoidCallback onNextPage,
    required VoidCallback onPreviousPage,
  }) async {
    final generation = ++_generation;
    _activeOwner = owner;
    _onNextPage = onNextPage;
    _onPreviousPage = onPreviousPage;

    final prefs = await SharedPreferences.getInstance();
    final preferenceEnabled = prefs.getBool(preferenceKey) ?? true;
    final enabled = preferenceEnabled && pageTurningAvailable;
    if (!_supportsVolumePaging ||
        generation != _generation ||
        !identical(_activeOwner, owner)) {
      return enabled;
    }

    _enabled = enabled;
    _androidChannel.setMethodCallHandler(_handleMethodCall);
    await _setNativeEnabled(enabled);
    return enabled;
  }

  static Future<void> deactivate(Object owner) async {
    if (!identical(_activeOwner, owner)) return;
    _generation++;
    _activeOwner = null;
    _onNextPage = null;
    _onPreviousPage = null;
    _enabled = false;
    if (!_supportsVolumePaging) return;
    _androidChannel.setMethodCallHandler(null);
    await _setNativeEnabled(false);
  }

  static Future<void> _handleMethodCall(MethodCall call) async {
    if (!_enabled || call.method != 'onVolumeKey') return;
    final arguments = call.arguments;
    final direction = arguments is Map ? arguments['direction'] : null;
    switch (direction) {
      case 'next':
        _onNextPage?.call();
        return;
      case 'previous':
        _onPreviousPage?.call();
        return;
    }
  }

  static Future<void> _setNativeEnabled(bool enabled) async {
    try {
      await _androidChannel.invokeMethod<void>(
        'setVolumePagingEnabled',
        <String, Object?>{'enabled': enabled},
      );
    } on MissingPluginException {
      // Widget tests and non-standard hosts may not provide the Android bridge.
    } on PlatformException {
      // Keep the reader usable if a vendor Android host rejects the call.
    }
  }
}
