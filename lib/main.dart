// 文件说明：应用启动入口，负责初始化数据库、依赖注入、主题、国际化与全局服务。
// 技术要点：Flutter Localizations、Provider、SharedPreferences、SQLite FFI、Path Provider。

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart' as provider;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'l10n/app_localizations.dart';
import 'pages/home/home_shell_page.dart';
import 'pages/legal/user_agreement_page.dart';
import 'services/books/book_services.dart';
import 'services/core/core_services.dart';
import 'utils/app_themes.dart';
import 'services/tts_service.dart';
import 'package:path_provider/path_provider.dart';
import 'utils/glass_config.dart';
import 'utils/localization_extension.dart';
import 'utils/font_catalog_helper.dart';
import 'utils/ui_style.dart';
import 'widgets/app_brand_icon.dart';
import 'widgets/update_check_gate.dart';

void main() async {
  // 确保可以在 runApp 前安全调用 SystemChrome
  WidgetsFlutterBinding.ensureInitialized();

  // 🚀 启用高刷新率支持
  if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
    // 检查并启用设备的最高刷新率
    SystemChrome.setApplicationSwitcherDescription(
      const ApplicationSwitcherDescription(
        label: '开元阅读',
        primaryColor: 0xFF1976D2,
      ),
    );
    if (Platform.isAndroid) {
      const fullscreenChannel = MethodChannel('com.niki.xxread/fullscreen');
      try {
        await fullscreenChannel.invokeMethod<void>('enableHighRefreshRate');
      } catch (_) {
        // 部分机型不支持动态切换高刷，忽略异常
      }
    }
  }

  // 在桌面平台上初始化 sqflite_common_ffi
  if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  // 设置基础系统UI样式 - 透明背景
  // 注意：不在这里设置SystemUiMode，让各页面根据需要自行控制
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark, // iOS: 状态栏图标为深色(适合白色背景)
      statusBarBrightness: Brightness.light, // iOS: 状态栏背景为浅色
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
      systemStatusBarContrastEnforced: false,
      systemNavigationBarContrastEnforced: false,
    ),
  );

  runApp(
    RestartableApp(
      child: provider.MultiProvider(
        providers: [
          provider.ChangeNotifierProvider(create: (_) => ThemeNotifier()),
          provider.ChangeNotifierProvider(
            create: (_) => AppSettingsNotifier(),
          ),
          provider.ChangeNotifierProvider(create: (_) => TtsService()),
        ],
        child: const XxReadApp(),
      ),
    ),
  );
}

class RestartableApp extends StatefulWidget {
  const RestartableApp({super.key, required this.child});

  final Widget child;

  static void restart(BuildContext context) {
    final state = context.findAncestorStateOfType<_RestartableAppState>();
    state?.restartApp();
  }

  @override
  State<RestartableApp> createState() => _RestartableAppState();
}

class _RestartableAppState extends State<RestartableApp> {
  Key _subtreeKey = UniqueKey();

  void restartApp() {
    setState(() => _subtreeKey = UniqueKey());
  }

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: _subtreeKey,
      child: widget.child,
    );
  }
}

class ThemeNotifier extends ChangeNotifier {
  static const String _themeModePrefKey = 'isDarkMode';
  static const String _uiStylePrefKey = 'ui_style_mode';
  static const String _appThemePrefKey = 'appTheme';
  static const String _customAccentPrefKey = 'customAccentColor';
  static const String _globalAccentPrefKey = 'globalAccentColor';
  static const String _lastPresetThemePrefKey = 'last_preset_app_theme';

  ThemeMode _themeMode = ThemeMode.system;
  bool _isInitialized = false;
  AppTheme _currentAppTheme = AppThemes.blueTheme; // 默认蓝色主题
  Color? _customAccentColor; // 存储自定义强调色
  Color? _globalAccentColor; // 全局强调色（与应用主题分离）
  String _lastPresetThemeName = AppThemes.blueTheme.name;
  AppUiStyle _uiStyle = AppUiStyle.material3;

  ThemeMode get themeMode => _themeMode;
  bool get isInitialized => _isInitialized;
  AppTheme get currentAppTheme => _currentAppTheme;
  Color? get customAccentColor => _customAccentColor;
  Color? get globalAccentColor => _globalAccentColor;
  Color? get effectiveAccentColor =>
      _globalAccentColor ??
      (_currentAppTheme.name == 'custom' ? _customAccentColor : null);
  bool get isUsingThemeAccent => effectiveAccentColor == null;
  String get lastPresetThemeName => _lastPresetThemeName;
  AppUiStyle get uiStyle => _uiStyle;
  bool get isGlassEffectsEnabled => _uiStyle == AppUiStyle.glass;
  bool get shouldDisableGlassEffects => _uiStyle == AppUiStyle.material3;

  ThemeNotifier() {
    _loadTheme();
  }

  void _loadTheme() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final isDarkMode = prefs.getBool(_themeModePrefKey);
    _uiStyle = appUiStyleFromStorage(prefs.getString(_uiStylePrefKey));
    await prefs.remove('disable_glass_effects');
    final appThemeName =
        prefs.getString(_appThemePrefKey) ?? AppThemes.blueTheme.name;
    final customColorValue = prefs.getInt(_customAccentPrefKey);
    final globalAccentColorValue = prefs.getInt(_globalAccentPrefKey);
    _lastPresetThemeName =
        prefs.getString(_lastPresetThemePrefKey) ?? AppThemes.blueTheme.name;

    _syncGlassEffectState();
    if (prefs.getBool('enableAnimations') != true) {
      await prefs.setBool('enableAnimations', true);
    }

    if (isDarkMode == null) {
      // 首次启动，使用系统主题
      _themeMode = ThemeMode.system;
    } else {
      _themeMode = isDarkMode ? ThemeMode.dark : ThemeMode.light;
    }

    if (appThemeName != 'custom') {
      _lastPresetThemeName = appThemeName;
    }

    // 加载应用主题（兼容历史 custom 方案）
    if (appThemeName == 'custom' && customColorValue != null) {
      _customAccentColor = Color(customColorValue);
      _currentAppTheme = AppThemes.createCustomTheme(_customAccentColor!);
      debugPrint('🎨 加载自定义主题: ${_customAccentColor.toString()}');
    } else {
      _customAccentColor = null;
      _currentAppTheme = AppThemes.getThemeByName(appThemeName);
      debugPrint('🎨 加载预设主题: ${_currentAppTheme.displayName}');
    }

    // 加载全局强调色（优先于主题内强调色）
    if (globalAccentColorValue != null) {
      _globalAccentColor = Color(globalAccentColorValue);
      AppThemes.setGlobalAccentColor(_globalAccentColor);
    } else {
      _globalAccentColor = null;
      AppThemes.setGlobalAccentColor(null);
    }

    _isInitialized = true;
    notifyListeners();

    // 不在这里更新系统UI，让各页面自行控制
    // 避免与阅读页面的全屏模式冲突
  }

  void toggleTheme(bool isDarkMode) async {
    final newThemeMode = isDarkMode ? ThemeMode.dark : ThemeMode.light;
    if (_themeMode == newThemeMode) return; // 避免重复设置

    _themeMode = newThemeMode;

    // 立即通知监听器更新UI
    notifyListeners();

    // 不在这里更新系统栏样式，让各页面自行控制
    // 避免与阅读页面的全屏模式冲突

    // 异步保存设置
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_themeModePrefKey, isDarkMode);
  }

  // 切换应用主题
  void setAppTheme(AppTheme theme) async {
    if (_currentAppTheme.name == theme.name) return; // 避免重复设置

    debugPrint('🎨 切换应用主题到: ${theme.displayName}');
    _currentAppTheme = theme;
    _customAccentColor = null; // 清除自定义强调色
    if (theme.name != 'custom') {
      _lastPresetThemeName = theme.name;
    }

    // 立即通知监听器更新UI
    notifyListeners();

    // 异步保存设置
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_appThemePrefKey, theme.name);
    await prefs.remove(_customAccentPrefKey); // 移除自定义颜色设置
    if (theme.name != 'custom') {
      await prefs.setString(_lastPresetThemePrefKey, _lastPresetThemeName);
    }
    debugPrint('🎨 主题已保存: ${theme.name}');
  }

  // 设置自定义强调色
  void setCustomAccentColor(Color color) async {
    debugPrint('🎨 设置自定义强调色: ${color.toString()}');

    if (_currentAppTheme.name != 'custom') {
      _lastPresetThemeName = _currentAppTheme.name;
    }

    // 清除可能冲突的全局强调色
    _globalAccentColor = null;
    AppThemes.setGlobalAccentColor(null);
    debugPrint('🎨 已清除全局强调色，避免冲突');

    _customAccentColor = color;
    final customTheme = AppThemes.createCustomTheme(color);

    _currentAppTheme = customTheme;
    debugPrint('🎨 当前主题已更新为: ${_currentAppTheme.displayName}');
    debugPrint(
      '🎨 自定义主题主色调: ${customTheme.lightColorScheme.primary.toString()}',
    );

    // 立即通知监听器更新UI
    notifyListeners();

    // 异步保存设置
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_appThemePrefKey, 'custom');
    await prefs.setInt(_customAccentPrefKey, color.toARGB32());
    await prefs.remove(_globalAccentPrefKey); // 清除全局强调色设置
    await prefs.setString(_lastPresetThemePrefKey, _lastPresetThemeName);
    debugPrint('🎨 自定义颜色已保存: ${color.toARGB32()}');
  }

  // 设置全局强调色（与应用主题分离）
  void setGlobalAccentColor(Color? color) async {
    if (_globalAccentColor == color) return; // 避免重复设置

    debugPrint('🎨 设置全局强调色: ${color?.toString() ?? "null (跟随主题)"}');
    _globalAccentColor = color;
    AppThemes.setGlobalAccentColor(color);

    // 立即通知监听器更新UI
    notifyListeners();

    // 异步保存设置
    SharedPreferences prefs = await SharedPreferences.getInstance();
    if (color != null) {
      await prefs.setInt(_globalAccentPrefKey, color.toARGB32());
    } else {
      await prefs.remove(_globalAccentPrefKey);
    }
  }

  /// 统一的强调色设置入口：
  /// - `null` 表示跟随当前应用主题
  /// - 非空颜色表示覆盖强调色
  ///
  /// 如果用户历史上使用的是 `custom` 主题，这里会回退到最近一次预设主题，
  /// 然后再应用全局强调色，避免“主题+强调色双层状态”让设置变得难理解。
  Future<void> setAccentColor(Color? color) async {
    final prefs = await SharedPreferences.getInstance();

    if (_currentAppTheme.name == 'custom') {
      _currentAppTheme = AppThemes.getThemeByName(_lastPresetThemeName);
      _customAccentColor = null;
      await prefs.setString(_appThemePrefKey, _currentAppTheme.name);
      await prefs.remove(_customAccentPrefKey);
    }

    if (_globalAccentColor == color) {
      return;
    }
    _globalAccentColor = color;
    AppThemes.setGlobalAccentColor(color);
    notifyListeners();

    if (color != null) {
      await prefs.setInt(_globalAccentPrefKey, color.toARGB32());
    } else {
      await prefs.remove(_globalAccentPrefKey);
    }
    await prefs.setString(_lastPresetThemePrefKey, _lastPresetThemeName);
  }

  void setThemeMode(ThemeMode mode) {
    if (_themeMode == mode) return;

    _themeMode = mode;
    notifyListeners();

    // 不在这里更新系统UI，让各页面自行控制
    // 避免与阅读页面的全屏模式冲突

    // 保存设置
    _saveThemeMode(mode);
  }

  void _saveThemeMode(ThemeMode mode) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    if (mode == ThemeMode.system) {
      await prefs.remove(_themeModePrefKey);
    } else {
      await prefs.setBool(_themeModePrefKey, mode == ThemeMode.dark);
    }
  }

  Future<void> setUiStyle(AppUiStyle style) async {
    if (_uiStyle == style) return;
    _uiStyle = style;
    _syncGlassEffectState();
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_uiStylePrefKey, style.storageValue);
  }

  Future<void> setGlassEffectsEnabled(bool enabled) {
    return setUiStyle(enabled ? AppUiStyle.glass : AppUiStyle.material3);
  }

  void _syncGlassEffectState() {
    GlassEffectConfig.setDisableAllGlassEffects(shouldDisableGlassEffects);
    GlassEffectConfig.applyPerformanceMode(
      reduceEffects: shouldDisableGlassEffects,
    );
  }
}

class XxReadApp extends StatefulWidget {
  const XxReadApp({super.key});

  @override
  State<XxReadApp> createState() => _XxReadAppState();
}

class _XxReadAppState extends State<XxReadApp> {
  bool? _hasAcceptedAgreement;
  bool _isBootstrapped = false;
  bool _showFirstHomeSupportAfterAgreement = false;
  _BootstrapError? _bootstrapError;

  @override
  void initState() {
    super.initState();
    _bootstrapServices();
    _checkAgreementStatus();
  }

  Future<void> _bootstrapServices() async {
    setState(() {
      _isBootstrapped = false;
      _bootstrapError = null;
    });

    // 初始化缓存与应用状态服务
    try {
      await DataCacheService().initialize();
      await AppStateService().initialize();
    } catch (e) {
      debugPrint('数据服务初始化失败: $e');
      if (mounted) {
        setState(() => _bootstrapError = _BootstrapError.dataService);
      }
      return;
    }

    // 初始化图片管理器
    try {
      final appDocDir = await getApplicationDocumentsDirectory();
      await BookImageManager().initialize(appDocDir.path);
    } catch (e) {
      debugPrint('图片管理器初始化失败: $e');
      if (mounted) {
        setState(() => _bootstrapError = _BootstrapError.imageManager);
      }
      return;
    }

    // 修复历史绝对路径（升级/重装后可能导致书籍与封面路径失效）
    try {
      await BookStorageRepairService().repairAllBooksIfNeeded();
      // 清理历史残留的临时/无效文件，避免占用存储
      await BookStorageRepairService().cleanupUnusedStorageArtifacts();
    } catch (e) {
      // 路径修复失败不阻塞启动
      debugPrint('书籍路径修复失败（已忽略，不阻塞启动）: $e');
    }

    if (!mounted) return;
    setState(() {
      _isBootstrapped = true;
      _bootstrapError = null;
    });
  }

  /// 检查用户是否已同意协议
  Future<void> _checkAgreementStatus() async {
    final hasAccepted = await UserAgreementService.hasUserAcceptedAgreement();
    if (!mounted) return;
    setState(() {
      _hasAcceptedAgreement = hasAccepted;
    });
    debugPrint('📋 协议状态检查: ${hasAccepted ? "已同意" : "未同意"}');
  }

  /// 处理用户同意协议
  void _onAgreementAccepted() {
    setState(() {
      _hasAcceptedAgreement = true;
      _showFirstHomeSupportAfterAgreement = true;
    });
    debugPrint('✅ 用户协议已同意，进入主应用');
  }

  /// 处理用户拒绝协议
  void _onAgreementRejected() {
    // 退出应用
    debugPrint('❌ 用户拒绝协议，退出应用');
    // 这里可以调用 SystemNavigator.pop() 或其他退出逻辑
    // SystemNavigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    return provider.Consumer2<ThemeNotifier, AppSettingsNotifier>(
      builder: (context, themeNotifier, appSettings, child) {
        // 不在这里更新系统UI，让各页面自行控制
        // 避免与阅读页面的全屏模式冲突

        return MaterialApp(
          onGenerateTitle: (context) => context.l10n.appTitle,
          debugShowCheckedModeBanner: false,
          // 🚀 启用高性能渲染，支持120Hz高刷新率
          scrollBehavior: const MaterialScrollBehavior().copyWith(
            physics: const BouncingScrollPhysics(),
          ),
          theme: _buildLightTheme(
            themeNotifier.currentAppTheme,
            appSettings.appFontFamily,
            themeNotifier.uiStyle,
          ),
          darkTheme: _buildDarkTheme(
            themeNotifier.currentAppTheme,
            appSettings.appFontFamily,
            themeNotifier.uiStyle,
          ),
          themeMode: themeNotifier.themeMode,
          locale: appSettings.locale,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => _buildHome(context),
          ),
          // 移除 builder 中的系统UI更新，让各页面自行控制
          // 避免与阅读页面的全屏模式冲突
        );
      },
    );
  }

  // 已移除未使用的 _getEffectiveThemeMode 方法

  /// 根据协议状态决定显示哪个页面
  Widget _buildHome(BuildContext context) {
    if (_bootstrapError != null) {
      return _buildBootstrapErrorPage(context);
    }

    // 如果还在初始化，显示加载页面
    if (!_isBootstrapped) {
      return _buildLoadingPage(context);
    }

    // 如果还在检查协议状态，显示加载页面
    if (_hasAcceptedAgreement == null) {
      return _buildLoadingPage(context);
    }

    // 如果未同意协议，显示协议页面
    if (!_hasAcceptedAgreement!) {
      return UserAgreementPage(
        onAgreed: _onAgreementAccepted,
        onDisagreed: _onAgreementRejected,
      );
    }

    // 已同意协议，显示主页面
    return UpdateCheckGate(
      child: HomeShellPage(
        showFirstHomeSupport: _showFirstHomeSupportAfterAgreement,
      ),
    );
  }

  Widget _buildBootstrapErrorPage(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline,
                size: 48,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                context.l10n.initializationFailed,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                switch (_bootstrapError) {
                  _BootstrapError.dataService =>
                    context.l10n.bootstrapDataServiceFailed,
                  _BootstrapError.imageManager =>
                    context.l10n.bootstrapImageManagerFailed,
                  null => context.l10n.unknownError,
                },
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _bootstrapServices,
                child: Text(context.l10n.retry),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 构建加载页面
  Widget _buildLoadingPage(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
              Theme.of(context).colorScheme.secondary.withValues(alpha: 0.05),
              Theme.of(context).colorScheme.surface,
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 68,
                height: 68,
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Theme.of(context).colorScheme.primary,
                      Theme.of(context).colorScheme.secondary,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const AppBrandIcon(
                  size: 56,
                  borderRadius: 13,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                context.l10n.appTitle,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 40),
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                  Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  ThemeData _buildLightTheme(
    AppTheme appTheme,
    String? appFontFamily,
    AppUiStyle uiStyle,
  ) {
    ColorScheme colorScheme = appTheme.lightColorScheme;
    debugPrint('🎨 构建浅色主题 - 基础主题: ${appTheme.displayName}');
    debugPrint('🎨 基础主色调: ${colorScheme.primary.toString()}');

    // 如果有全局强调色，应用到color scheme
    final globalAccent = AppThemes.getGlobalAccentColor();
    if (globalAccent != null) {
      debugPrint('🎨 应用全局强调色 (浅色主题): ${globalAccent.toString()}');
      colorScheme = AppThemes.getColorSchemeWithAccent(
        colorScheme,
        globalAccent,
      );
      debugPrint('🎨 新的主要颜色: ${colorScheme.primary.toString()}');
    } else {
      debugPrint('🎨 没有全局强调色，使用主题默认色');
    }

    return _buildThemeData(
      colorScheme: colorScheme,
      brightness: Brightness.light,
      appFontFamily: appFontFamily,
      uiStyle: uiStyle,
    );
  }

  ThemeData _buildDarkTheme(
    AppTheme appTheme,
    String? appFontFamily,
    AppUiStyle uiStyle,
  ) {
    ColorScheme colorScheme = appTheme.darkColorScheme;

    // 如果有全局强调色，应用到color scheme
    final globalAccent = AppThemes.getGlobalAccentColor();
    if (globalAccent != null) {
      debugPrint('🎨 应用全局强调色 (深色主题): ${globalAccent.toString()}');
      colorScheme = AppThemes.getColorSchemeWithAccent(
        colorScheme,
        globalAccent,
      );
      debugPrint('🎨 新的主要颜色: ${colorScheme.primary.toString()}');
    }

    return _buildThemeData(
      colorScheme: colorScheme,
      brightness: Brightness.dark,
      appFontFamily: appFontFamily,
      uiStyle: uiStyle,
    );
  }

  ThemeData _buildThemeData({
    required ColorScheme colorScheme,
    required Brightness brightness,
    required String? appFontFamily,
    required AppUiStyle uiStyle,
  }) {
    final isDark = brightness == Brightness.dark;
    final isMaterial3Style = uiStyle == AppUiStyle.material3;
    final systemBarColor =
        isMaterial3Style ? colorScheme.surface : Colors.transparent;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colorScheme.surface,
      cardColor: isMaterial3Style
          ? colorScheme.surfaceContainerLow
          : colorScheme.surface.withValues(alpha: isDark ? 0.82 : 0.9),
      dialogTheme: DialogThemeData(
        backgroundColor: isMaterial3Style
            ? colorScheme.surfaceContainerHigh
            : colorScheme.surface.withValues(alpha: isDark ? 0.9 : 0.96),
      ),
      fontFamily: appFontFamily,
      fontFamilyFallback: FontCatalog.appFallbacks(appFontFamily),
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: systemBarColor,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: systemBarColor,
          statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
          statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
          systemNavigationBarColor: systemBarColor,
          systemNavigationBarIconBrightness:
              isDark ? Brightness.light : Brightness.dark,
          systemNavigationBarDividerColor: Colors.transparent,
          systemStatusBarContrastEnforced: false,
          systemNavigationBarContrastEnforced: false,
        ),
      ),
      dividerTheme: DividerThemeData(
        color: colorScheme.outline.withValues(
          alpha: isMaterial3Style ? 0.32 : 0.18,
        ),
        thickness: 0.7,
      ),
      extensions: <ThemeExtension<dynamic>>[
        UiStyleThemeExtension(style: uiStyle),
      ],
    );
  }
}

/// 启动初始化失败的类型，文案在 build 时按当前语言解析。
enum _BootstrapError {
  dataService,
  imageManager,
}
