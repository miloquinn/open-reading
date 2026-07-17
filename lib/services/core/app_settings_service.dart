// 文件说明：应用设置服务，负责全局偏好项的读取与变更通知。
// 技术要点：服务层、SharedPreferences、Flutter。

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../utils/font_catalog_helper.dart';

class AppSettingsNotifier extends ChangeNotifier {
  static const String _keyAppLocale = 'app_locale';
  static const String _keyLegacyLocale = 'language';
  static const String _keyAppFontId = 'app_font_id_v2';
  static const String _keyReaderFontId = 'reader_font_id_v2';
  static const String _keyLegacyAppFontFamily = 'app_font_family';

  Locale? _locale;
  String _localeCode = 'system';
  String _appFontId = FontCatalog.defaultAppFont.id;
  String _readerFontId = FontCatalog.defaultReaderFont.id;
  bool _isInitialized = false;

  AppSettingsNotifier() {
    _loadSettings();
  }

  Locale? get locale => _locale;
  String get localeCode => _localeCode;
  String get appFontId => _appFontId;
  String get readerFontId => _readerFontId;
  FontOption get appFont => FontCatalog.appFontForId(_appFontId);
  FontOption get readerFont => FontCatalog.readerFontForId(_readerFontId);
  String? get appFontFamily => appFont.family;
  bool get isInitialized => _isInitialized;

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final storedLocale =
        prefs.getString(_keyAppLocale) ?? prefs.getString(_keyLegacyLocale);
    _applyLocaleCode(storedLocale ?? 'system', notify: false);
    final storedAppFontId = prefs.getString(_keyAppFontId);
    if (storedAppFontId != null) {
      _appFontId = FontCatalog.appFontForId(storedAppFontId).id;
    } else {
      final legacyFamily = prefs.getString(_keyLegacyAppFontFamily);
      if (legacyFamily != null && legacyFamily.isNotEmpty) {
        _appFontId = FontCatalog.appFontForFamily(legacyFamily).id;
        await prefs.setString(_keyAppFontId, _appFontId);
      }
    }
    _readerFontId = FontCatalog.readerFontForId(
      prefs.getString(_keyReaderFontId),
    ).id;
    _isInitialized = true;
    notifyListeners();
  }

  void _applyLocaleCode(String code, {bool notify = true}) {
    _localeCode = code;
    _locale = _parseLocale(code);
    if (notify) {
      notifyListeners();
    }
  }

  Locale? _parseLocale(String code) {
    if (code.isEmpty || code == 'system') {
      return null;
    }
    final normalized = code.replaceAll('_', '-');
    final parts = normalized.split('-');
    if (parts.length >= 2) {
      return Locale(parts[0], parts[1]);
    }
    return Locale(parts[0]);
  }

  Future<void> setLocaleCode(String code) async {
    _applyLocaleCode(code);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyAppLocale, code);
    await prefs.setString(_keyLegacyLocale, code);
  }

  Future<void> setAppFontId(String id) async {
    final normalized = FontCatalog.appFontForId(id).id;
    if (_appFontId == normalized) return;
    _appFontId = normalized;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyAppFontId, normalized);
  }

  Future<void> setReaderFontId(String id) async {
    final normalized = FontCatalog.readerFontForId(id).id;
    if (_readerFontId == normalized) return;
    _readerFontId = normalized;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyReaderFontId, normalized);
  }
}
