// 文件说明：应用设置服务，负责全局偏好项的读取与变更通知。
// 技术要点：服务层、SharedPreferences、Flutter。

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettingsNotifier extends ChangeNotifier {
  static const String _keyAppLocale = 'app_locale';
  static const String _keyLegacyLocale = 'language';
  static const String _keyAppFontFamily = 'app_font_family';

  Locale? _locale;
  String _localeCode = 'system';
  String? _appFontFamily;
  bool _isInitialized = false;

  AppSettingsNotifier() {
    _loadSettings();
  }

  Locale? get locale => _locale;
  String get localeCode => _localeCode;
  String? get appFontFamily => _appFontFamily;
  bool get isInitialized => _isInitialized;

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final storedLocale =
        prefs.getString(_keyAppLocale) ?? prefs.getString(_keyLegacyLocale);
    _applyLocaleCode(storedLocale ?? 'system', notify: false);
    final storedFontFamily = prefs.getString(_keyAppFontFamily);
    if (storedFontFamily != null && storedFontFamily.isNotEmpty) {
      await prefs.remove(_keyAppFontFamily);
    }
    _appFontFamily = null;
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

  Future<void> setAppFontFamily(String? family) async {
    _appFontFamily = family;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    if (family == null || family.isEmpty) {
      await prefs.remove(_keyAppFontFamily);
    } else {
      await prefs.setString(_keyAppFontFamily, family);
    }
  }
}
