import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Keeps the display awake only while at least one reader page is active and
/// the user has enabled the corresponding preference.
abstract final class ReaderKeepScreenOnController {
  static const String preferenceKey = 'keepScreenOn';
  static const MethodChannel _channel = MethodChannel(
    'com.niki.xxread/fullscreen',
  );

  static final Set<Object> _activeReaders = LinkedHashSet<Object>.identity();
  static Future<void> _pendingSync = Future<void>.value();
  static bool? _preferenceEnabled;
  static bool _applied = false;
  static int _preferenceRevision = 0;
  static int _revision = 0;

  static Future<void> activate(Object reader) async {
    _activeReaders.add(reader);
    await _loadPreference();
    await _scheduleSync();
  }

  static Future<void> deactivate(Object reader) async {
    _activeReaders.remove(reader);
    await _scheduleSync();
  }

  static Future<void> setPreference(bool enabled) async {
    final preferenceRevision = ++_preferenceRevision;
    _preferenceEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    if (preferenceRevision != _preferenceRevision) return;
    await prefs.setBool(preferenceKey, enabled);
    await _scheduleSync();
  }

  static Future<void> reapply(Object reader) async {
    if (!_activeReaders.contains(reader)) return;
    await _loadPreference(refresh: true);
    await _scheduleSync(force: true);
  }

  static Future<void> _loadPreference({bool refresh = false}) async {
    if (_preferenceEnabled != null && !refresh) return;
    final prefs = await SharedPreferences.getInstance();
    _preferenceEnabled = prefs.getBool(preferenceKey) ?? false;
  }

  static Future<void> _scheduleSync({bool force = false}) {
    final revision = ++_revision;
    _pendingSync = _pendingSync.then((_) async {
      if (revision != _revision) return;
      final shouldKeepScreenOn =
          (_preferenceEnabled ?? false) && _activeReaders.isNotEmpty;
      if (!force && _applied == shouldKeepScreenOn) return;

      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        try {
          await _channel.invokeMethod<void>('setKeepScreenOn', <String, bool>{
            'enabled': shouldKeepScreenOn,
          });
        } on MissingPluginException catch (error) {
          debugPrint('Keep-screen-on bridge unavailable: $error');
          return;
        } on PlatformException catch (error) {
          debugPrint('Failed to update keep-screen-on state: $error');
          return;
        }
      }

      _applied = shouldKeepScreenOn;
    });
    return _pendingSync;
  }

  @visibleForTesting
  static Future<void> resetForTesting() async {
    await _pendingSync;
    _activeReaders.clear();
    _preferenceEnabled = null;
    _applied = false;
    _preferenceRevision = 0;
    _revision = 0;
    _pendingSync = Future<void>.value();
  }
}
