// 文件说明：应用设置服务，负责全局偏好项的读取与变更通知。
// 技术要点：服务层、SharedPreferences、Flutter。

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../utils/font_catalog_helper.dart';
import 'custom_font_service.dart';

class AppSettingsNotifier extends ChangeNotifier {
  static const String _keyAppLocale = 'app_locale';
  static const String _keyLegacyLocale = 'language';
  static const String _keyAppFontId = 'app_font_id_v2';
  static const String _keyReaderFontId = 'reader_font_id_v2';
  static const String _keyLegacyAppFontFamily = 'app_font_family';
  static const String _keyHideNavigationLabels =
      'hide_home_navigation_labels_v1';

  Locale? _locale;
  String _localeCode = 'system';
  String _appFontId = FontCatalog.defaultAppFont.id;
  String _readerFontId = FontCatalog.defaultReaderFont.id;
  bool _hideNavigationLabels = true;
  bool _isInitialized = false;
  final CustomFontService _customFontService;

  AppSettingsNotifier({CustomFontService? customFontService})
      : _customFontService = customFontService ?? CustomFontService() {
    _loadSettings();
  }

  Locale? get locale => _locale;
  String get localeCode => _localeCode;
  String get appFontId => _appFontId;
  String get readerFontId => _readerFontId;
  bool get hideNavigationLabels => _hideNavigationLabels;
  List<FontOption> get customFonts => _customFontService.fonts
      .map(
        (font) => FontOption(
          id: font.id,
          family: font.runtimeFamily,
          fallbackFamilies: const <String>['SourceHanSansCN'],
          tone: FontTone.sansSerif,
          displayName: font.displayName,
          sourceFileName: font.fileName,
          fileSize: font.fileSize,
          isCustom: true,
          isAvailable: font.available,
        ),
      )
      .toList(growable: false);
  List<FontOption> get availableCustomFonts =>
      customFonts.where((font) => font.isAvailable).toList(growable: false);
  List<FontOption> get appFontOptions => <FontOption>[
        ...FontCatalog.appFonts,
        ...availableCustomFonts,
      ];
  List<FontOption> get readerFontOptions => <FontOption>[
        ...FontCatalog.readerFonts,
        ...availableCustomFonts,
      ];
  FontOption get appFont => FontCatalog.appFontForId(
        _appFontId,
        customFonts: availableCustomFonts,
      );
  FontOption get readerFont => FontCatalog.readerFontForId(
        _readerFontId,
        customFonts: availableCustomFonts,
      );
  String? get appFontFamily => appFont.family;
  bool get customFontImportSupported => _customFontService.isSupported;
  bool get isInitialized => _isInitialized;

  Future<void> _loadSettings() async {
    await _customFontService.initialize();
    final prefs = await SharedPreferences.getInstance();
    final storedLocale =
        prefs.getString(_keyAppLocale) ?? prefs.getString(_keyLegacyLocale);
    _applyLocaleCode(storedLocale ?? 'system', notify: false);
    final storedAppFontId = prefs.getString(_keyAppFontId);
    if (storedAppFontId != null) {
      _appFontId = FontCatalog.appFontForId(
        storedAppFontId,
        customFonts: availableCustomFonts,
      ).id;
    } else {
      final legacyFamily = prefs.getString(_keyLegacyAppFontFamily);
      if (legacyFamily != null && legacyFamily.isNotEmpty) {
        _appFontId = FontCatalog.appFontForFamily(legacyFamily).id;
        await prefs.setString(_keyAppFontId, _appFontId);
      }
    }
    _readerFontId = FontCatalog.readerFontForId(
      prefs.getString(_keyReaderFontId),
      customFonts: availableCustomFonts,
    ).id;
    _hideNavigationLabels = prefs.getBool(_keyHideNavigationLabels) ?? true;
    await _restoreSelectedCustomFonts(prefs);
    _isInitialized = true;
    notifyListeners();
  }

  Future<void> _restoreSelectedCustomFonts(SharedPreferences prefs) async {
    if (appFont.isCustom &&
        !await _customFontService.ensureLoaded(_appFontId)) {
      _appFontId = FontCatalog.defaultAppFont.id;
      await prefs.setString(_keyAppFontId, _appFontId);
    }
    if (readerFont.isCustom &&
        !await _customFontService.ensureLoaded(_readerFontId)) {
      _readerFontId = FontCatalog.defaultReaderFont.id;
      await prefs.setString(_keyReaderFontId, _readerFontId);
    }
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
    final normalized = FontCatalog.appFontForId(
      id,
      customFonts: availableCustomFonts,
    ).id;
    if (normalized.startsWith('custom_') &&
        !await _customFontService.ensureLoaded(normalized)) {
      return;
    }
    if (_appFontId == normalized) return;
    _appFontId = normalized;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyAppFontId, normalized);
  }

  Future<void> setReaderFontId(String id) async {
    final normalized = FontCatalog.readerFontForId(
      id,
      customFonts: availableCustomFonts,
    ).id;
    if (normalized.startsWith('custom_') &&
        !await _customFontService.ensureLoaded(normalized)) {
      return;
    }
    if (_readerFontId == normalized) return;
    _readerFontId = normalized;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyReaderFontId, normalized);
  }

  Future<void> setHideNavigationLabels(bool value) async {
    if (_hideNavigationLabels == value) return;
    _hideNavigationLabels = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyHideNavigationLabels, value);
  }

  Future<void> prepareCustomFontPreviews() async {
    await _customFontService.loadAvailableFonts();
  }

  Future<CustomFontImportResult> importCustomFont([FontDomain? domain]) async {
    final result = await _customFontService.importFont();
    final imported = result.font;
    if (imported == null) return result;
    notifyListeners();
    switch (domain) {
      case FontDomain.app:
        await setAppFontId(imported.id);
        break;
      case FontDomain.reader:
        await setReaderFontId(imported.id);
        break;
      case null:
        break;
    }
    return result;
  }

  Future<void> renameCustomFont(String id, String displayName) async {
    await _customFontService.renameFont(id, displayName);
    notifyListeners();
  }

  Future<void> deleteCustomFont(String id) async {
    final prefs = await SharedPreferences.getInstance();
    var selectionChanged = false;
    if (_appFontId == id) {
      _appFontId = FontCatalog.defaultAppFont.id;
      await prefs.setString(_keyAppFontId, _appFontId);
      selectionChanged = true;
    }
    if (_readerFontId == id) {
      _readerFontId = FontCatalog.defaultReaderFont.id;
      await prefs.setString(_keyReaderFontId, _readerFontId);
      selectionChanged = true;
    }
    if (selectionChanged) notifyListeners();
    await _customFontService.deleteFont(id);
    notifyListeners();
  }

  bool isAppFont(String id) => _appFontId == id;
  bool isReaderFont(String id) => _readerFontId == id;
}
