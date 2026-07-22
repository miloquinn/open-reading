// 文件说明：应用设置服务，负责全局偏好项的读取与变更通知。
// 技术要点：服务层、SharedPreferences、Flutter、OnlineFontService 进度回调驱动 UI 刷新。

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../utils/font_catalog_helper.dart';
import 'custom_font_service.dart';
import 'online_font_service.dart';

enum LibraryLayoutMode { card, grid }

class AppSettingsNotifier extends ChangeNotifier {
  static const String _keyAppLocale = 'app_locale';
  static const String _keyLegacyLocale = 'language';
  static const String _keyAppFontId = 'app_font_id_v2';
  static const String _keyReaderFontId = 'reader_font_id_v2';
  static const String _keyLegacyAppFontFamily = 'app_font_family';
  static const String _keyHideNavigationLabels =
      'hide_home_navigation_labels_v1';
  static const String _keyLibraryLayoutMode = 'library_layout_mode_v1';
  static const String _keyLibraryGridColumns = 'library_grid_columns_v1';

  Locale? _locale;
  String _localeCode = 'system';
  String _appFontId = FontCatalog.defaultAppFont.id;
  String _readerFontId = FontCatalog.defaultReaderFont.id;
  bool _hideNavigationLabels = true;
  LibraryLayoutMode _libraryLayoutMode = LibraryLayoutMode.card;
  int _libraryGridColumns = 3;
  bool _isInitialized = false;
  final CustomFontService _customFontService;
  final OnlineFontService _onlineFontService;

  AppSettingsNotifier({
    CustomFontService? customFontService,
    OnlineFontService? onlineFontService,
  }) : _customFontService = customFontService ?? CustomFontService(),
       _onlineFontService = onlineFontService ?? OnlineFontService() {
    _loadSettings();
  }

  Locale? get locale => _locale;
  String get localeCode => _localeCode;
  String get appFontId => _appFontId;
  String get readerFontId => _readerFontId;
  bool get hideNavigationLabels => _hideNavigationLabels;
  LibraryLayoutMode get libraryLayoutMode => _libraryLayoutMode;
  int get libraryGridColumns => _libraryGridColumns;

  /// 用户自定义导入的字体列表（在线字体不在此列）。
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

  /// 当前可用的 App 字体选项：系统字体 + 在线字体（区分已下载/未下载）+ 已加载的自定义字体。
  List<FontOption> get appFontOptions => <FontOption>[
    ...FontCatalog.appFonts,
    ...availableCustomFonts,
  ];
  List<FontOption> get readerFontOptions => <FontOption>[
    ...FontCatalog.readerFonts,
    ...availableCustomFonts,
  ];

  FontOption get appFont =>
      FontCatalog.appFontForId(_appFontId, customFonts: availableCustomFonts);
  FontOption get readerFont => FontCatalog.readerFontForId(
    _readerFontId,
    customFonts: availableCustomFonts,
  );
  String? get appFontFamily => appFont.family;
  bool get customFontImportSupported => _customFontService.isSupported;
  bool get onlineFontDownloadSupported => _onlineFontService.isSupported;
  bool get isInitialized => _isInitialized;

  /// 在线字体是否已下载完成（可用于选择）。
  bool isOnlineFontDownloaded(String fontId) =>
      _onlineFontService.isSupported && _onlineFontService.isDownloaded(fontId);

  /// 在线字体当前的下载进度；未在下载中返回 null。
  OnlineFontDownloadProgress? onlineFontProgress(String fontId) =>
      _onlineFontService.progressFor(fontId);

  /// 触发在线字体下载。下载完成后通知 UI 刷新；失败时设置错误状态供 UI 显示重试按钮。
  /// [domain] 用于下载成功后自动应用该字体到 App 或阅读域；传 null 仅下载不切换。
  Future<void> downloadOnlineFont(String fontId, {FontDomain? domain}) async {
    if (!_onlineFontService.isSupported) return;
    final option = _resolveOnlineFontOption(fontId);
    if (option == null) return; // 不是在线字体
    if (isOnlineFontDownloaded(fontId)) {
      // 已下载，确保已加载即可。
      await _onlineFontService.ensureLoaded(
        fontId,
        files: option.downloadFiles,
        family: option.family!,
      );
      if (domain != null) {
        await _applyDownloadedFont(domain, fontId);
      }
      notifyListeners();
      return;
    }
    try {
      await _onlineFontService.download(
        fontId: fontId,
        family: option.family!,
        files: option.downloadFiles,
        onProgress: (_) => notifyListeners(),
      );
      if (domain != null) {
        await _applyDownloadedFont(domain, fontId);
      }
      notifyListeners();
    } on OnlineFontException {
      // 失败状态已通过 progressFor() 暴露给 UI，无需额外处理。
      notifyListeners();
    }
  }

  Future<void> deleteOnlineFont(String fontId) async {
    if (!_onlineFontService.isSupported) return;
    final prefs = await SharedPreferences.getInstance();
    var selectionChanged = false;
    if (_appFontId == fontId) {
      _appFontId = FontCatalog.defaultAppFont.id;
      await prefs.setString(_keyAppFontId, _appFontId);
      selectionChanged = true;
    }
    if (_readerFontId == fontId) {
      _readerFontId = FontCatalog.defaultReaderFont.id;
      await prefs.setString(_keyReaderFontId, _readerFontId);
      selectionChanged = true;
    }
    if (selectionChanged) notifyListeners();
    await _onlineFontService.deleteDownload(fontId);
    notifyListeners();
  }

  FontOption? _resolveOnlineFontOption(String fontId) {
    for (final option in FontCatalog.appFonts) {
      if (option.id == fontId && option.isOnline) return option;
    }
    for (final option in FontCatalog.readerFonts) {
      if (option.id == fontId && option.isOnline) return option;
    }
    return null;
  }

  Future<void> _applyDownloadedFont(FontDomain domain, String fontId) async {
    switch (domain) {
      case FontDomain.app:
        _appFontId = fontId;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_keyAppFontId, fontId);
        break;
      case FontDomain.reader:
        _readerFontId = fontId;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_keyReaderFontId, fontId);
        break;
    }
  }

  Future<void> _loadSettings() async {
    await _customFontService.initialize();
    await _onlineFontService.initialize();
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
    _libraryLayoutMode = switch (prefs.getString(_keyLibraryLayoutMode)) {
      'grid' => LibraryLayoutMode.grid,
      _ => LibraryLayoutMode.card,
    };
    _libraryGridColumns = prefs.getInt(_keyLibraryGridColumns) == 2 ? 2 : 3;
    await _restoreSelectedFonts(prefs);
    _isInitialized = true;
    notifyListeners();
  }

  /// 启动时恢复已选字体的运行时注册：
  /// - 自定义字体：通过 CustomFontService.ensureLoaded 加载；文件缺失则回退默认
  /// - 在线字体：通过 OnlineFontService.ensureLoaded 加载；未下载则回退默认
  Future<void> _restoreSelectedFonts(SharedPreferences prefs) async {
    final appOption = FontCatalog.appFontForId(
      _appFontId,
      customFonts: availableCustomFonts,
    );
    if (appOption.isCustom) {
      if (!await _customFontService.ensureLoaded(_appFontId)) {
        _appFontId = FontCatalog.defaultAppFont.id;
        await prefs.setString(_keyAppFontId, _appFontId);
      }
    } else if (appOption.isOnline) {
      if (isOnlineFontDownloaded(_appFontId)) {
        await _onlineFontService.ensureLoaded(
          _appFontId,
          files: appOption.downloadFiles,
          family: appOption.family!,
        );
      } else {
        // 用户之前选过但尚未下载（例如刚升级到在线字体版本），先回退系统字体。
        _appFontId = FontCatalog.defaultAppFont.id;
        await prefs.setString(_keyAppFontId, _appFontId);
      }
    }
    final readerOption = FontCatalog.readerFontForId(
      _readerFontId,
      customFonts: availableCustomFonts,
    );
    if (readerOption.isCustom) {
      if (!await _customFontService.ensureLoaded(_readerFontId)) {
        _readerFontId = FontCatalog.defaultReaderFont.id;
        await prefs.setString(_keyReaderFontId, _readerFontId);
      }
    } else if (readerOption.isOnline) {
      if (isOnlineFontDownloaded(_readerFontId)) {
        await _onlineFontService.ensureLoaded(
          _readerFontId,
          files: readerOption.downloadFiles,
          family: readerOption.family!,
        );
      } else {
        _readerFontId = FontCatalog.defaultReaderFont.id;
        await prefs.setString(_keyReaderFontId, _readerFontId);
      }
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

  /// 设置 App 字体 ID。在线字体未下载时直接返回不切换——UI 应通过
  /// downloadOnlineFont() 触发下载完成后再调用本方法。
  Future<void> setAppFontId(String id) async {
    final normalized = FontCatalog.appFontForId(
      id,
      customFonts: availableCustomFonts,
    ).id;
    if (normalized == _appFontId) return;
    if (normalized.startsWith('custom_') &&
        !await _customFontService.ensureLoaded(normalized)) {
      return;
    }
    final option = FontCatalog.appFontForId(
      normalized,
      customFonts: availableCustomFonts,
    );
    if (option.isOnline && !isOnlineFontDownloaded(normalized)) {
      return;
    }
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
    if (normalized == _readerFontId) return;
    if (normalized.startsWith('custom_') &&
        !await _customFontService.ensureLoaded(normalized)) {
      return;
    }
    final option = FontCatalog.readerFontForId(
      normalized,
      customFonts: availableCustomFonts,
    );
    if (option.isOnline && !isOnlineFontDownloaded(normalized)) {
      return;
    }
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

  Future<void> setLibraryLayoutMode(LibraryLayoutMode mode) async {
    if (_libraryLayoutMode == mode) return;
    _libraryLayoutMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLibraryLayoutMode, mode.name);
  }

  Future<void> setLibraryGridColumns(int columns) async {
    final normalized = columns == 2 ? 2 : 3;
    if (_libraryGridColumns == normalized) return;
    _libraryGridColumns = normalized;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyLibraryGridColumns, normalized);
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
