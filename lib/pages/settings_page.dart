// 文件说明：设置页面，负责应用主题、语言、同步、备份和外观设置。
// 技术要点：Flutter UI、Icons Plus、Package Info、Provider、SharedPreferences、URL Launcher。

import 'dart:async';
import 'dart:ui';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../main.dart';
import '../utils/app_themes.dart';
import '../l10n/app_localizations.dart';
import '../reader_core/ai/ai_service.dart';
import '../services/books/book_services.dart';
import '../services/core/core_services.dart';
import '../services/sync/sync_services.dart';
import '../widgets/side_toast.dart';
import '../widgets/webdav_config_dialog.dart';
import '../widgets/app_brand_icon.dart';
import 'home_shell_page.dart';
import 'home_layout_constants.dart';
import '../utils/localization_extension.dart';
import '../utils/page_style_helper.dart';
import '../utils/system_ui_helper.dart';
import '../utils/ui_style.dart';

part 'settings_page_cover_actions_part.dart';

// --- 保留历史翻页模式枚举，供已有设置值迁移使用 ---
enum ReaderPageTurnAnimation { cover, slide, scroll, chapterScroll, simulation }

extension ReaderPageTurnAnimationExt on ReaderPageTurnAnimation {
  String get prefValue => name;
}

class ReaderPageTurnAnimationPrefs {
  static ReaderPageTurnAnimation? fromPrefValue(String? value) {
    if (value == null) return null;
    return ReaderPageTurnAnimation.values.firstWhere((e) => e.name == value,
        orElse: () => ReaderPageTurnAnimation.cover);
  }
}
// ------------------------------------------------

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final ReaderHttpAIService _aiService = ReaderHttpAIService();
  late final TextEditingController _aiApiKeyController;
  late final TextEditingController _aiModelController;
  late final TextEditingController _aiBaseUrlController;
  late final TextEditingController _aiTempController;

  bool _enableAutoSave = true;
  bool _keepScreenOn = false;
  int _autoSaveInterval = 30;

  // 阅读设置
  ReaderPageTurnAnimation _pageTurnAnimation = ReaderPageTurnAnimation.cover;
  bool _enableVolumeKeyTurn = true;
  bool _showSystemStatusBarInReader = false;

  bool _enableAutoExtractCover = true;

  // WebDAV设置
  final WebDavSyncService _webdavService = WebDavSyncService();
  final IosCloudSyncService _iosCloudSyncService = IosCloudSyncService();
  bool _isIosCloudSyncing = false;

  // 其他设置
  bool _enableFullscreen = false;

  // 开发者设置
  bool _enableDeveloperMode = false;
  bool _enableDebugLogging = false;
  bool _enablePerformanceMonitor = false;
  bool _enableMemoryStats = false;
  bool _showFPS = false;
  String _appVersion = '3.0.0';
  final Map<AIProviderType, AIProviderSettings> _aiDraftByProvider =
      <AIProviderType, AIProviderSettings>{};
  AIProviderType _selectedAiProvider = AIProviderType.openai;
  AIModelPreset? _selectedAiPreset;
  bool _aiSettingsLoaded = false;
  bool _obscureAiApiKey = true;
  bool _isSavingAiSettings = false;
  String? _aiSettingsError;

  @override
  void initState() {
    super.initState();
    _aiApiKeyController = TextEditingController();
    _aiModelController = TextEditingController();
    _aiBaseUrlController = TextEditingController();
    _aiTempController = TextEditingController();
    _webdavService.statusNotifier.addListener(_onWebDavStatusChanged);
    unawaited(_loadAppVersion());
    _loadSettings();
    // 状态栏设置现在由_SettingsPageWrapper处理
  }

  @override
  void dispose() {
    _webdavService.statusNotifier.removeListener(_onWebDavStatusChanged);
    _aiApiKeyController.dispose();
    _aiModelController.dispose();
    _aiBaseUrlController.dispose();
    _aiTempController.dispose();
    super.dispose();
  }

  void _onWebDavStatusChanged() {
    if (!mounted) return;
    setState(() {});
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 状态栏设置现在由_SettingsPageWrapper处理，这里保持简洁
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final activeAiSettings = await _aiService.loadSettings();
    final aiSettingsByProvider = <AIProviderType, AIProviderSettings>{
      for (final provider in AIProviderType.values)
        provider: provider == activeAiSettings.provider
            ? activeAiSettings
            : await _aiService.loadSettings(provider),
    };
    bool migrateSimulationMode = false;
    if (!mounted) {
      return;
    }
    setState(() {
      _enableAutoSave = prefs.getBool('enableAutoSave') ?? true;
      _keepScreenOn = prefs.getBool('keepScreenOn') ?? false;
      _autoSaveInterval = prefs.getInt('autoSaveInterval') ?? 30;

      _enableAutoExtractCover = prefs.getBool('enableAutoExtractCover') ?? true;

      // 阅读设置
      final pageTurnMode = ReaderPageTurnAnimationPrefs.fromPrefValue(
        prefs.getString('reader_page_turn_mode_v1'),
      );
      if (pageTurnMode != null) {
        _pageTurnAnimation = pageTurnMode == ReaderPageTurnAnimation.simulation
            ? ReaderPageTurnAnimation.cover
            : pageTurnMode;
        if (_pageTurnAnimation != pageTurnMode) {
          migrateSimulationMode = true;
        }
      } else {
        final legacyEnable = prefs.getBool('enablePageAnimation') ?? true;
        _pageTurnAnimation = legacyEnable
            ? ReaderPageTurnAnimation.cover
            : ReaderPageTurnAnimation.slide;
      }
      _enableVolumeKeyTurn = prefs.getBool('enableVolumeKeyTurn') ?? true;
      _showSystemStatusBarInReader =
          prefs.getBool('readerShowSystemStatusBar') ?? false;
      // 其他设置
      _enableFullscreen = prefs.getBool('enableFullscreen') ?? false;

      // 开发者设置
      _enableDeveloperMode = prefs.getBool('enableDeveloperMode') ?? false;
      _enableDebugLogging = prefs.getBool('enableDebugLogging') ?? false;
      _enablePerformanceMonitor =
          prefs.getBool('enablePerformanceMonitor') ?? false;
      _enableMemoryStats = prefs.getBool('enableMemoryStats') ?? false;
      _showFPS = prefs.getBool('showFPS') ?? false;
      _aiDraftByProvider
        ..clear()
        ..addAll(aiSettingsByProvider);
      _selectedAiProvider = activeAiSettings.provider;
      _aiSettingsLoaded = true;
    });
    _applyAiDraft(_aiDraftByProvider[_selectedAiProvider]!);

    if (migrateSimulationMode) {
      await prefs.setString(
          'reader_page_turn_mode_v1', _pageTurnAnimation.prefValue);
    }

    if (prefs.getBool('enableAnimations') != true) {
      await prefs.setBool('enableAnimations', true);
    }

    // 初始化WebDAV服务
    await _webdavService.initialize();
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _loadAppVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      final version = info.version.trim();
      if (!mounted) {
        return;
      }
      setState(() {
        _appVersion = version.isNotEmpty ? version : '3.0.0';
      });
    } catch (_) {
      // Keep default version fallback.
    }
  }

  Future<void> _saveSettings() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('enableAnimations', true);
    await prefs.setBool('enableAutoSave', _enableAutoSave);
    await prefs.setBool('keepScreenOn', _keepScreenOn);
    await prefs.setInt('autoSaveInterval', _autoSaveInterval);

    await prefs.setBool('enableAutoExtractCover', _enableAutoExtractCover);

    // 阅读设置
    await prefs.setString(
      'reader_page_turn_mode_v1',
      _pageTurnAnimation.prefValue,
    );
    await prefs.setBool(
      'enablePageAnimation',
      _pageTurnAnimation != ReaderPageTurnAnimation.slide,
    );
    await prefs.setBool('enableVolumeKeyTurn', _enableVolumeKeyTurn);
    await prefs.setBool(
      'readerShowSystemStatusBar',
      _showSystemStatusBarInReader,
    );
    // 其他设置
    await prefs.setBool('enableFullscreen', _enableFullscreen);

    // 开发者设置
    await prefs.setBool('enableDeveloperMode', _enableDeveloperMode);
    await prefs.setBool('enableDebugLogging', _enableDebugLogging);
    await prefs.setBool('enablePerformanceMonitor', _enablePerformanceMonitor);
    await prefs.setBool('enableMemoryStats', _enableMemoryStats);
    await prefs.setBool('showFPS', _showFPS);
  }

  void _applyAiDraft(AIProviderSettings settings) {
    final normalized = settings.normalized();
    _aiApiKeyController.text = normalized.apiKey;
    _aiModelController.text = normalized.model;
    _aiBaseUrlController.text = normalized.baseUrl;
    _aiTempController.text = normalized.temperature.toStringAsFixed(2);
    _selectedAiPreset = AIModelPresets.match(normalized) ??
        AIModelPresets.defaultForProvider(normalized.provider);
  }

  AIProviderSettings _buildAiDraftFromInputs(
    AIProviderType provider, {
    bool allowFallbackTemp = true,
  }) {
    final previous =
        _aiDraftByProvider[provider] ?? AIProviderSettings.defaults(provider);
    final parsedTemp = double.tryParse(_aiTempController.text.trim());
    final nextTemp =
        parsedTemp ?? (allowFallbackTemp ? previous.temperature : double.nan);
    return previous
        .copyWith(
          provider: provider,
          apiKey: _aiApiKeyController.text,
          model: _aiModelController.text,
          baseUrl: _aiBaseUrlController.text,
          temperature: nextTemp,
        )
        .normalized();
  }

  void _stashCurrentAiDraft() {
    _aiDraftByProvider[_selectedAiProvider] =
        _buildAiDraftFromInputs(_selectedAiProvider);
  }

  void _onAiProviderChanged(AIProviderType provider) {
    _stashCurrentAiDraft();
    final nextDraft = _aiDraftByProvider[provider] ??
        AIModelPresets.defaultForProvider(provider).toSettings();
    setState(() {
      _selectedAiProvider = provider;
      _aiSettingsError = null;
      _applyAiDraft(nextDraft);
    });
  }

  void _onAiPresetChanged(AIModelPreset preset) {
    final applied = preset.toSettings(apiKey: _aiApiKeyController.text.trim());
    _aiDraftByProvider[preset.provider] = applied;
    setState(() {
      _selectedAiProvider = preset.provider;
      _aiSettingsError = null;
      _applyAiDraft(applied);
    });
  }

  bool _validateAiTemperature(AIProviderType provider, double value) {
    if (!value.isFinite || value < 0 || value > 2) {
      return false;
    }
    if (provider == AIProviderType.minimax) {
      return value > 0 && value <= 1;
    }
    if ((provider == AIProviderType.claude ||
            provider == AIProviderType.gemini) &&
        value > 1) {
      return false;
    }
    return true;
  }

  String _aiTemperatureHint(AIProviderType provider) {
    switch (provider) {
      case AIProviderType.minimax:
        return 'Temperature: MiniMax 建议 0.01 ~ 1.00';
      case AIProviderType.claude:
      case AIProviderType.gemini:
        return 'Temperature: 0.00 ~ 1.00';
      case AIProviderType.glm:
      case AIProviderType.openai:
        return 'Temperature: 0.00 ~ 2.00';
    }
  }

  Future<void> _showAiCustomConfigDialog() async {
    _stashCurrentAiDraft();
    final current = (_aiDraftByProvider[_selectedAiProvider] ??
            AIProviderSettings.defaults(_selectedAiProvider))
        .normalized();
    final modelController = TextEditingController(text: current.model);
    final baseUrlController = TextEditingController(text: current.baseUrl);
    final tempController = TextEditingController(
      text: current.temperature.toStringAsFixed(2),
    );
    String? errorText;

    final result = await showDialog<AIProviderSettings>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('自定义 AI 配置'),
              content: SizedBox(
                width: 440,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '当前服务商：${_selectedAiProvider.displayName}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.68),
                            ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: modelController,
                        decoration: const InputDecoration(
                          labelText: 'Model',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: baseUrlController,
                        decoration: const InputDecoration(
                          labelText: 'Base URL',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: tempController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Temperature',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _aiTemperatureHint(_selectedAiProvider),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.62),
                            ),
                      ),
                      if (errorText != null) ...[
                        const SizedBox(height: 10),
                        Text(
                          errorText!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('取消'),
                ),
                FilledButton(
                  onPressed: () {
                    final parsedTemp =
                        double.tryParse(tempController.text.trim());
                    if (parsedTemp == null ||
                        !_validateAiTemperature(
                          _selectedAiProvider,
                          parsedTemp,
                        )) {
                      setDialogState(() {
                        errorText =
                            _selectedAiProvider == AIProviderType.minimax
                                ? 'MiniMax 的 Temperature 必须在 0.01 ~ 1.00 之间'
                                : 'Temperature 超出范围，请按提示填写';
                      });
                      return;
                    }

                    final nextSettings = current
                        .copyWith(
                          provider: _selectedAiProvider,
                          apiKey: _aiApiKeyController.text.trim(),
                          model: modelController.text.trim(),
                          baseUrl: baseUrlController.text.trim(),
                          temperature: parsedTemp,
                        )
                        .normalized();
                    final validationError = validateAIProviderSettings(
                      nextSettings,
                      requireApiKey: false,
                    );
                    if (validationError != null) {
                      setDialogState(() {
                        errorText = validationError;
                      });
                      return;
                    }

                    Navigator.of(dialogContext).pop(
                      nextSettings,
                    );
                  },
                  child: const Text('应用'),
                ),
              ],
            );
          },
        );
      },
    );

    modelController.dispose();
    baseUrlController.dispose();
    tempController.dispose();

    if (result == null || !mounted) {
      return;
    }

    setState(() {
      _aiDraftByProvider[_selectedAiProvider] = result;
      _aiSettingsError = null;
      _applyAiDraft(result);
    });
    showSideToast(context, '已应用自定义参数，记得保存配置');
  }

  Future<void> _saveAiSettings() async {
    final apiKey = _aiApiKeyController.text.trim();
    if (apiKey.isEmpty) {
      setState(() {
        _aiSettingsError = 'API Key 不能为空';
      });
      return;
    }

    final model = _aiModelController.text.trim();
    if (model.isEmpty) {
      setState(() {
        _aiSettingsError = 'Model 不能为空';
      });
      return;
    }

    final baseUrl = _aiBaseUrlController.text.trim();
    final uri = Uri.tryParse(baseUrl);
    if (baseUrl.isEmpty ||
        uri == null ||
        !(uri.isScheme('http') || uri.isScheme('https'))) {
      setState(() {
        _aiSettingsError = 'Base URL 必须是合法的 http/https 地址';
      });
      return;
    }

    final parsedTemp = double.tryParse(_aiTempController.text.trim());
    if (parsedTemp == null ||
        !_validateAiTemperature(_selectedAiProvider, parsedTemp)) {
      setState(() {
        _aiSettingsError = _selectedAiProvider == AIProviderType.minimax
            ? 'MiniMax 的 Temperature 必须在 0.01 ~ 1.00 之间'
            : 'Temperature 超出范围，请按提示填写';
      });
      return;
    }

    final settings = AIProviderSettings(
      provider: _selectedAiProvider,
      apiKey: apiKey,
      baseUrl: baseUrl,
      model: model,
      temperature: parsedTemp,
    ).normalized();
    final validationError = validateAIProviderSettings(settings);
    if (validationError != null) {
      setState(() {
        _aiSettingsError = validationError;
      });
      return;
    }

    setState(() {
      _isSavingAiSettings = true;
      _aiSettingsError = null;
    });

    try {
      await _aiService.saveSettings(settings);
      if (!mounted) {
        return;
      }
      setState(() {
        _aiDraftByProvider[_selectedAiProvider] = settings;
        _selectedAiPreset = AIModelPresets.match(settings);
      });
      showSideToast(context, 'AI 设置已保存');
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _aiSettingsError = '保存失败: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSavingAiSettings = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeNotifier = Provider.of<ThemeNotifier>(context);
    final appSettings = Provider.of<AppSettingsNotifier>(context);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final isMaterial3Style = themeNotifier.uiStyle == AppUiStyle.material3;

    // 检查是否在侧边导航栏模式下
    final navContext = NavigationContext.of(context);
    final useRailNavigation = navContext?.useRailNavigation ?? false;

    // 在侧边导航栏模式下，不显示 Scaffold 和 AppBar
    if (useRailNavigation) {
      return _buildContent(context, themeNotifier, appSettings, isDarkMode);
    }

    // 手机模式：显示完整的 Scaffold + AppBar
    return Scaffold(
      extendBody: true,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: isMaterial3Style
            ? Theme.of(context).colorScheme.surface
            : Colors.transparent,
        elevation: 0,
        toolbarHeight: 0, // 关闭系统AppBar，使用自绘毛玻璃顶栏
        systemOverlayStyle: SystemUiHelper.overlayStyleForBrightness(
          Theme.of(context).brightness,
        ),
      ),
      body: _buildContent(context, themeNotifier, appSettings, isDarkMode),
    );
  }

  // 提取页面内容部分，在两种模式下共用
  Widget _buildContent(
    BuildContext context,
    ThemeNotifier themeNotifier,
    AppSettingsNotifier appSettings,
    bool isDarkMode,
  ) {
    final l10n = context.l10n;
    final useRailNavigation =
        NavigationContext.of(context)?.useRailNavigation ?? false;
    return Container(
      decoration: BoxDecoration(
        gradient: PageStyleHelper.backgroundGradient(context),
      ),
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          useRailNavigation
              ? MediaQuery.of(context).padding.top + 8
              : MediaQuery.of(context).padding.top +
                  kHomeMobileTopBarHeight +
                  8,
          16,
          24,
        ),
        children: [
          if (useRailNavigation) ...[
            _buildSettingsTopRow(l10n, useRailNavigation),
            const SizedBox(height: 10),
          ],
          _buildSectionCard(
            title: l10n.appearanceSettings,
            icon: Icons.palette_outlined,
            children: [
              _buildUiStyleSelector(themeNotifier),
              _buildThemeToggle(themeNotifier),
              _buildAppThemeSelector(themeNotifier),
              _buildAccentColorSelector(themeNotifier),
            ],
          ),
          const SizedBox(height: 20),
          _buildSectionCard(
            title: l10n.readingSettings,
            icon: Icons.book_outlined,
            children: [
              _buildActionSetting(
                title: l10n.pageTurningSettings,
                subtitle:
                    '${l10n.pageTurningMode}：${_pageTurnModeLabel(_pageTurnAnimation, l10n)}',
                onTap: () => _showPageTurningModal(l10n),
                icon: _pageTurnModeIcon(_pageTurnAnimation),
              ),
              _buildSwitchSetting(
                title: '音量键翻页',
                subtitle: '使用音量键控制翻页',
                value: _enableVolumeKeyTurn,
                onChanged: (value) =>
                    setState(() => _enableVolumeKeyTurn = value),
                icon: Icons.volume_up,
              ),
              _buildSwitchSetting(
                title: '阅读时显示系统状态栏',
                subtitle: _showSystemStatusBarInReader
                    ? '已隐藏阅读页电量/时间 UI'
                    : '使用阅读页电量/时间 UI',
                value: _showSystemStatusBarInReader,
                onChanged: (value) =>
                    setState(() => _showSystemStatusBarInReader = value),
                icon: Icons.vertical_align_top_rounded,
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildSectionCard(
            title: 'AI 阅读助手',
            icon: Icons.auto_awesome_outlined,
            children: [
              _buildAiSettingsSection(),
            ],
          ),
          const SizedBox(height: 20),
          _buildSectionCard(
            title: l10n.cloudSync,
            icon: Icons.cloud_sync,
            children: [
              if (Platform.isIOS)
                _buildActionSetting(
                  title: 'iCloud/文件夹同步',
                  subtitle: _isIosCloudSyncing
                      ? '正在整理书籍、进度、笔记并写入分类目录...'
                      : '在 iOS 文件 App / iCloud Drive 直接按分类保存副本',
                  onTap: _isIosCloudSyncing ? () {} : _syncToIosFiles,
                  icon: Icons.folder_copy_outlined,
                  trailing: _isIosCloudSyncing
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        )
                      : null,
                ),

              // WebDAV配置入口
              _buildActionSetting(
                title: l10n.webdavConfig,
                subtitle: _webdavService.isConfigured
                    ? l10n.webdavConfigured(_webdavService.serverUrl)
                    : l10n.webdavConfigHint,
                onTap: _showWebDavConfig,
                icon: Icons.cloud,
                trailing: _webdavService.isConfigured
                    ? const Icon(
                        Icons.check_circle,
                        color: Colors.green,
                        size: 20,
                      )
                    : null,
              ),

              // 同步功能说明
              if (_webdavService.isConfigured) ...[
                // 同步状态和时间
                Container(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .primaryContainer
                        .withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withValues(alpha: 0.2),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            _getSyncStatusIcon(_webdavService.status),
                            size: 16,
                            color: _getSyncStatusColor(_webdavService.status),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _webdavService.getStatusDescription(),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: _getSyncStatusColor(_webdavService.status),
                            ),
                          ),
                          const Spacer(),
                          if (_webdavService.lastSyncTime != null)
                            Text(
                              '上次: ${_formatSyncTime(_webdavService.lastSyncTime!)}',
                              style: TextStyle(
                                fontSize: 11,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withValues(alpha: 0.6),
                              ),
                            ),
                        ],
                      ),
                      if (_webdavService.status == SyncStatus.failed &&
                          _webdavService.lastErrorMessage.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          _webdavService.lastErrorMessage,
                          style: TextStyle(
                            fontSize: 11,
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // 同步内容说明
                Container(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest
                        .withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info_outline,
                              size: 14,
                              color: Theme.of(context).colorScheme.primary),
                          const SizedBox(width: 6),
                          Text(
                            '同步内容',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          _buildSyncChip('书籍', Icons.book),
                          _buildSyncChip('书签', Icons.bookmark),
                          _buildSyncChip('笔记', Icons.note),
                          _buildSyncChip('进度', Icons.timeline),
                          _buildSyncChip('统计', Icons.bar_chart),
                        ],
                      ),
                    ],
                  ),
                ),

                // 立即同步按钮
                _buildActionSetting(
                  title: '立即同步',
                  subtitle: '手动同步所有阅读数据',
                  onTap: _syncNow,
                  icon: Icons.sync,
                ),

                // 书籍文件同步设置
                _buildActionSetting(
                  title: '书籍文件同步',
                  subtitle:
                      '已选 ${_webdavService.getBooksSelectedForSync().length} 本，选择需要上传到云端的书籍文件',
                  onTap: _showBookFileSyncDialog,
                  icon: Icons.upload_file,
                ),
              ],
            ],
          ),
          const SizedBox(height: 20),
          _buildSectionCard(
            title: l10n.appSettings,
            icon: Icons.language,
            children: [
              _buildLanguageSelector(appSettings),
            ],
          ),
          const SizedBox(height: 20),
          _buildSectionCard(
            title: '系统设置',
            icon: Icons.settings_outlined,
            children: [
              _buildSwitchSetting(
                title: '保持屏幕常亮',
                subtitle: '阅读时防止屏幕自动关闭',
                value: _keepScreenOn,
                onChanged: (value) => setState(() => _keepScreenOn = value),
                icon: Icons.stay_current_portrait,
              ),
              _buildSwitchSetting(
                title: '自动保存',
                subtitle: '自动保存阅读进度',
                value: _enableAutoSave,
                onChanged: (value) => setState(() => _enableAutoSave = value),
                icon: Icons.save_outlined,
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildAboutCard(),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildSettingsTopRow(AppLocalizations l10n, bool useRailNavigation) {
    final palette = PageStyleHelper.palette(context);
    return Row(
      children: [
        Text(
          l10n.settings,
          style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                fontWeight: FontWeight.w700,
                height: 1.05,
              ),
        ),
        const Spacer(),
        InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: () => showSideToast(context, '这里可以放帮助说明'),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: palette.card,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Icon(
              Icons.question_mark_rounded,
              size: 20,
              color: palette.iconMuted,
            ),
          ),
        ),
      ],
    );
  }

  bool get _shouldDisableBlurForCurrentTheme {
    final isMaterial3Style = Theme.of(
          context,
        ).extension<UiStyleThemeExtension>()?.isMaterial3Style ??
        false;
    return isMaterial3Style;
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    final palette = PageStyleHelper.palette(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        enabled: !_shouldDisableBlurForCurrentTheme,
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          decoration: BoxDecoration(
            color: palette.card,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: palette.border,
              width: 1,
            ),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        icon,
                        color: Theme.of(context).colorScheme.primary,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ],
                ),
              ),
              ...children,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAiSettingsSection() {
    final colorScheme = Theme.of(context).colorScheme;
    final currentSettings = (_aiDraftByProvider[_selectedAiProvider] ??
            AIProviderSettings.defaults(_selectedAiProvider))
        .normalized();
    final matchedPreset = AIModelPresets.match(currentSettings);
    final providerPresets = AIModelPresets.byProvider(_selectedAiProvider);

    if (!_aiSettingsLoaded) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer.withValues(alpha: 0.28),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: colorScheme.primary.withValues(alpha: 0.18),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.auto_awesome_rounded,
                    size: 18,
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            currentSettings.isConfigured
                                ? 'AI 已配置'
                                : '尚未配置 API Key',
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: currentSettings.isConfigured
                                  ? Colors.green.withValues(alpha: 0.14)
                                  : colorScheme.secondary
                                      .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              currentSettings.isConfigured ? '可直接使用' : '待配置',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: currentSettings.isConfigured
                                    ? Colors.green.shade700
                                    : colorScheme.secondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        matchedPreset != null
                            ? '当前预设：${matchedPreset.vendor} · ${matchedPreset.label}'
                            : '当前配置：自定义 · ${currentSettings.model}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color:
                                  colorScheme.onSurface.withValues(alpha: 0.72),
                              height: 1.35,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '已内置常用服务商和模型，通常只需要选择预设并输入 API Key。',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color:
                                  colorScheme.onSurface.withValues(alpha: 0.64),
                              height: 1.35,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<AIProviderType>(
            key: ValueKey<String>('ai-provider-${_selectedAiProvider.value}'),
            initialValue: _selectedAiProvider,
            decoration: const InputDecoration(
              labelText: '服务商',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            items: AIProviderType.values
                .map(
                  (provider) => DropdownMenuItem(
                    value: provider,
                    child: Text(provider.displayName),
                  ),
                )
                .toList(),
            onChanged: (provider) {
              if (provider == null || provider == _selectedAiProvider) {
                return;
              }
              _onAiProviderChanged(provider);
            },
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<AIModelPreset>(
                  key: ValueKey<String>(
                    'ai-preset-${_selectedAiProvider.value}-${_selectedAiPreset?.id ?? 'custom'}',
                  ),
                  initialValue: matchedPreset,
                  hint: const Text('选择预设模型'),
                  decoration: const InputDecoration(
                    labelText: '预设模型',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: providerPresets
                      .map(
                        (preset) => DropdownMenuItem(
                          value: preset,
                          child: Text('${preset.vendor} · ${preset.label}'),
                        ),
                      )
                      .toList(),
                  onChanged: (preset) {
                    if (preset == null) {
                      return;
                    }
                    _onAiPresetChanged(preset);
                  },
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: _showAiCustomConfigDialog,
                icon: const Icon(Icons.tune_rounded),
                label: const Text('自定义'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            matchedPreset != null
                ? '选择预设后只需输入 API Key 即可使用。'
                : '当前使用自定义参数，可随时切回预设。',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.62),
                ),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _aiApiKeyController,
            obscureText: _obscureAiApiKey,
            onChanged: (_) {
              if (_aiSettingsError != null) {
                setState(() {
                  _aiSettingsError = null;
                });
              }
            },
            decoration: InputDecoration(
              labelText: 'API Key',
              hintText: '输入后即可启用当前预设',
              border: const OutlineInputBorder(),
              isDense: true,
              suffixIcon: IconButton(
                tooltip: _obscureAiApiKey ? '显示' : '隐藏',
                onPressed: () {
                  setState(() {
                    _obscureAiApiKey = !_obscureAiApiKey;
                  });
                },
                icon: Icon(
                  _obscureAiApiKey
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded,
                ),
              ),
            ),
          ),
          if (_aiSettingsError != null) ...[
            const SizedBox(height: 10),
            Text(
              _aiSettingsError!,
              style: TextStyle(
                color: colorScheme.error,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ],
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _isSavingAiSettings ? null : _saveAiSettings,
              icon: _isSavingAiSettings
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colorScheme.onPrimary,
                      ),
                    )
                  : const Icon(Icons.save_outlined),
              label: Text(_isSavingAiSettings ? '保存中...' : '保存 AI 配置'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThemeToggle(ThemeNotifier themeNotifier) {
    final mode = themeNotifier.themeMode;
    return _buildActionSetting(
      title: '夜间模式',
      subtitle: '当前：${_themeModeLabel(mode)}',
      onTap: () => _showThemeModeModal(themeNotifier),
      icon: _themeModeIcon(mode),
    );
  }

  Widget _buildUiStyleSelector(ThemeNotifier themeNotifier) {
    final currentStyle = themeNotifier.uiStyle;
    return _buildActionSetting(
      title: '界面风格',
      subtitle: '当前：${currentStyle.displayName}',
      onTap: () => _showUiStyleModal(themeNotifier),
      icon: currentStyle.icon,
    );
  }

  String _pageTurnModeLabel(
    ReaderPageTurnAnimation mode,
    AppLocalizations l10n,
  ) {
    switch (mode) {
      case ReaderPageTurnAnimation.cover:
        return l10n.pageTurningCover;
      case ReaderPageTurnAnimation.slide:
        return l10n.pageTurningSlide;
      case ReaderPageTurnAnimation.scroll:
        return l10n.pageTurningScroll;
      case ReaderPageTurnAnimation.chapterScroll:
        return '章节滚动';
      case ReaderPageTurnAnimation.simulation:
        return l10n.pageTurningSimulation;
    }
  }

  String _pageTurnModeHint(ReaderPageTurnAnimation mode) {
    switch (mode) {
      case ReaderPageTurnAnimation.cover:
        return '下一页覆盖当前页，纸张感更强';
      case ReaderPageTurnAnimation.slide:
        return '左右平移翻页，轻量稳定';
      case ReaderPageTurnAnimation.scroll:
        return '上下滚动翻页，连续阅读';
      case ReaderPageTurnAnimation.chapterScroll:
        return '整章上下滚动，底部可切换章节';
      case ReaderPageTurnAnimation.simulation:
        return '3D 仿真翻页，沉浸感更强';
    }
  }

  IconData _pageTurnModeIcon(ReaderPageTurnAnimation mode) {
    switch (mode) {
      case ReaderPageTurnAnimation.cover:
        return Icons.layers_rounded;
      case ReaderPageTurnAnimation.slide:
        return Icons.swipe_rounded;
      case ReaderPageTurnAnimation.scroll:
        return Icons.swap_vert_rounded;
      case ReaderPageTurnAnimation.chapterScroll:
        return Icons.article_rounded;
      case ReaderPageTurnAnimation.simulation:
        return Icons.auto_awesome_motion_rounded;
    }
  }

  void _showPageTurningModal(AppLocalizations l10n) {
    const modes = <ReaderPageTurnAnimation>[
      ReaderPageTurnAnimation.cover,
      ReaderPageTurnAnimation.slide,
      ReaderPageTurnAnimation.scroll,
      ReaderPageTurnAnimation.chapterScroll,
    ];
    final isMaterial3Style = Theme.of(context)
            .extension<UiStyleThemeExtension>()
            ?.isMaterial3Style ??
        false;
    final scheme = Theme.of(context).colorScheme;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor:
          isMaterial3Style ? scheme.surfaceContainerHigh : Colors.transparent,
      builder: (modalContext) {
        return Container(
          decoration: BoxDecoration(
            color: isMaterial3Style
                ? Theme.of(modalContext).colorScheme.surfaceContainerHigh
                : Theme.of(modalContext).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border(
              top: BorderSide(
                color: Theme.of(modalContext).colorScheme.outline.withValues(
                      alpha: isMaterial3Style ? 0.24 : 0.16,
                    ),
              ),
            ),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 14),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(modalContext)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 2, 24, 12),
                  child: Row(
                    children: [
                      Icon(
                        _pageTurnModeIcon(_pageTurnAnimation),
                        color: Theme.of(modalContext).colorScheme.primary,
                        size: 22,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        l10n.pageTurningSettings,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Theme.of(modalContext).colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
                ...modes.map((mode) {
                  final selected = _pageTurnAnimation == mode;
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () async {
                          if (selected) {
                            Navigator.of(modalContext).pop();
                            return;
                          }
                          setState(() => _pageTurnAnimation = mode);
                          Navigator.of(modalContext).pop();
                          unawaited(_saveSettings());
                          if (!mounted) {
                            return;
                          }
                          showSideToast(
                            context,
                            '翻页方式已切换为 ${_pageTurnModeLabel(mode, l10n)}',
                            icon: _pageTurnModeIcon(mode),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: selected
                                  ? Theme.of(modalContext).colorScheme.primary
                                  : Theme.of(modalContext)
                                      .colorScheme
                                      .outline
                                      .withValues(alpha: 0.35),
                              width: selected ? 1.6 : 1,
                            ),
                            color: selected
                                ? Theme.of(modalContext)
                                    .colorScheme
                                    .primary
                                    .withValues(alpha: 0.08)
                                : Colors.transparent,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _pageTurnModeIcon(mode),
                                color: selected
                                    ? Theme.of(modalContext).colorScheme.primary
                                    : Theme.of(modalContext)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.75),
                                size: 18,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _pageTurnModeLabel(mode, l10n),
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: selected
                                            ? Theme.of(
                                                modalContext,
                                              ).colorScheme.primary
                                            : Theme.of(
                                                modalContext,
                                              ).colorScheme.onSurface,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _pageTurnModeHint(mode),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Theme.of(modalContext)
                                            .colorScheme
                                            .onSurface
                                            .withValues(alpha: 0.62),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (selected)
                                Icon(
                                  Icons.check_circle,
                                  color: Theme.of(modalContext)
                                      .colorScheme
                                      .primary,
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showUiStyleModal(ThemeNotifier themeNotifier) {
    const options = [
      _UiStyleOption(style: AppUiStyle.glass),
      _UiStyleOption(style: AppUiStyle.material3),
    ];
    final isMaterial3Style = Theme.of(context)
            .extension<UiStyleThemeExtension>()
            ?.isMaterial3Style ??
        false;
    final scheme = Theme.of(context).colorScheme;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor:
          isMaterial3Style ? scheme.surfaceContainerHigh : Colors.transparent,
      builder: (modalContext) {
        return Container(
          decoration: BoxDecoration(
            color: isMaterial3Style
                ? Theme.of(modalContext).colorScheme.surfaceContainerHigh
                : Theme.of(modalContext).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border(
              top: BorderSide(
                color: Theme.of(modalContext).colorScheme.outline.withValues(
                      alpha: isMaterial3Style ? 0.24 : 0.16,
                    ),
              ),
            ),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 14),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(modalContext)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 2, 24, 12),
                  child: Row(
                    children: [
                      Icon(
                        themeNotifier.uiStyle.icon,
                        color: Theme.of(modalContext).colorScheme.primary,
                        size: 22,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '界面风格',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Theme.of(modalContext).colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
                ...options.map((item) {
                  final selected = themeNotifier.uiStyle == item.style;
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () async {
                          if (selected) {
                            Navigator.of(modalContext).pop();
                            return;
                          }

                          Navigator.of(modalContext).pop();
                          await themeNotifier.setUiStyle(item.style);
                          if (!mounted) return;
                          _showRestartDialog(
                            reason:
                                '界面风格已切换为 ${item.style.displayName}，重启后会完整应用到所有页面。',
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: selected
                                  ? Theme.of(modalContext).colorScheme.primary
                                  : Theme.of(modalContext)
                                      .colorScheme
                                      .outline
                                      .withValues(alpha: 0.35),
                              width: selected ? 1.6 : 1,
                            ),
                            color: selected
                                ? Theme.of(modalContext)
                                    .colorScheme
                                    .primary
                                    .withValues(alpha: 0.08)
                                : Colors.transparent,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                item.style.icon,
                                color: selected
                                    ? Theme.of(modalContext).colorScheme.primary
                                    : Theme.of(modalContext)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.75),
                                size: 18,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.style.displayName,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: selected
                                            ? Theme.of(
                                                modalContext,
                                              ).colorScheme.primary
                                            : Theme.of(
                                                modalContext,
                                              ).colorScheme.onSurface,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      item.style.subtitle,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Theme.of(modalContext)
                                            .colorScheme
                                            .onSurface
                                            .withValues(alpha: 0.62),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (selected)
                                Icon(
                                  Icons.check_circle,
                                  color: Theme.of(modalContext)
                                      .colorScheme
                                      .primary,
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAppThemeSelector(ThemeNotifier themeNotifier) {
    final accentSummary = themeNotifier.isUsingThemeAccent
        ? '强调色：跟随主题'
        : '强调色：${AppThemes.getAccentColorName(themeNotifier.effectiveAccentColor!)}';
    return Container(
      margin: const EdgeInsets.only(bottom: 1),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showAppThemeModal(themeNotifier),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(
                    AppThemes.getThemeIcon(themeNotifier.currentAppTheme.name),
                    size: 16,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '应用主题',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                      ),
                      Text(
                        '当前: ${themeNotifier.currentAppTheme.displayName} · $accentSummary',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurface.withValues(alpha: 0.6),
                            ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.4),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAccentColorSelector(ThemeNotifier themeNotifier) {
    final accentColor = themeNotifier.effectiveAccentColor;
    final subtitle = accentColor == null
        ? '跟随应用主题'
        : AppThemes.getAccentColorName(accentColor);

    return Container(
      margin: const EdgeInsets.only(bottom: 1),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showAccentColorModal(themeNotifier),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.secondary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(
                    Icons.color_lens_rounded,
                    size: 16,
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '强调色',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                      ),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurface.withValues(alpha: 0.6),
                            ),
                      ),
                    ],
                  ),
                ),
                if (accentColor != null)
                  Container(
                    width: 24,
                    height: 24,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: accentColor,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: Theme.of(
                          context,
                        ).colorScheme.outline.withValues(alpha: 0.3),
                      ),
                    ),
                  ),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.4),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _themeModeLabel(ThemeMode mode) {
    final l10n = context.l10n;
    switch (mode) {
      case ThemeMode.system:
        return l10n.systemMode;
      case ThemeMode.dark:
        return l10n.darkMode;
      case ThemeMode.light:
        return l10n.lightMode;
    }
  }

  IconData _themeModeIcon(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return Icons.brightness_auto;
      case ThemeMode.dark:
        return Icons.dark_mode;
      case ThemeMode.light:
        return Icons.light_mode;
    }
  }

  void _showThemeModeModal(ThemeNotifier themeNotifier) {
    final l10n = context.l10n;
    final options =
        <({ThemeMode mode, String label, String hint, IconData icon})>[
      (
        mode: ThemeMode.system,
        label: l10n.systemMode,
        hint: '跟随系统外观自动切换',
        icon: Icons.brightness_auto,
      ),
      (
        mode: ThemeMode.light,
        label: l10n.lightMode,
        hint: '始终使用浅色外观',
        icon: Icons.light_mode,
      ),
      (
        mode: ThemeMode.dark,
        label: l10n.darkMode,
        hint: '始终使用深色外观',
        icon: Icons.dark_mode,
      ),
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(modalContext).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 14),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(modalContext)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 2, 24, 12),
                  child: Row(
                    children: [
                      Icon(
                        _themeModeIcon(themeNotifier.themeMode),
                        color: Theme.of(modalContext).colorScheme.primary,
                        size: 22,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '夜间模式',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Theme.of(modalContext).colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
                ...options.map((item) {
                  final selected = themeNotifier.themeMode == item.mode;
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () {
                          themeNotifier.setThemeMode(item.mode);
                          Navigator.of(modalContext).pop();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: selected
                                  ? Theme.of(modalContext).colorScheme.primary
                                  : Theme.of(modalContext)
                                      .colorScheme
                                      .outline
                                      .withValues(alpha: 0.35),
                              width: selected ? 1.6 : 1,
                            ),
                            color: selected
                                ? Theme.of(modalContext)
                                    .colorScheme
                                    .primary
                                    .withValues(alpha: 0.08)
                                : Colors.transparent,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                item.icon,
                                color: selected
                                    ? Theme.of(modalContext).colorScheme.primary
                                    : Theme.of(modalContext)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.75),
                                size: 18,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.label,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: selected
                                            ? Theme.of(
                                                modalContext,
                                              ).colorScheme.primary
                                            : Theme.of(
                                                modalContext,
                                              ).colorScheme.onSurface,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      item.hint,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Theme.of(modalContext)
                                            .colorScheme
                                            .onSurface
                                            .withValues(alpha: 0.62),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (selected)
                                Icon(
                                  Icons.check_circle,
                                  color: Theme.of(modalContext)
                                      .colorScheme
                                      .primary,
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLanguageSelector(AppSettingsNotifier appSettings) {
    final l10n = context.l10n;
    final currentCode = appSettings.localeCode;
    final currentLabel = _languageLabel(l10n, currentCode);

    return _buildActionSetting(
      title: l10n.language,
      subtitle: currentLabel,
      icon: Icons.translate,
      onTap: () => _showLanguageModal(appSettings),
    );
  }

  String _languageLabel(AppLocalizations l10n, String code) {
    switch (code) {
      case 'zh':
      case 'zh-CN':
      case 'zh_CN':
        return l10n.languageChinese;
      case 'en':
      case 'en-US':
      case 'en_US':
        return l10n.languageEnglish;
      default:
        return l10n.languageSystem;
    }
  }

  void _showLanguageModal(AppSettingsNotifier appSettings) {
    final l10n = context.l10n;
    final options = [
      _LanguageOption(code: 'system', label: l10n.languageSystem),
      _LanguageOption(code: 'zh', label: l10n.languageChinese),
      _LanguageOption(code: 'en', label: l10n.languageEnglish),
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 16),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    Icon(
                      Icons.translate,
                      color: Theme.of(context).colorScheme.primary,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      l10n.language,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              ...options.map((option) {
                final isSelected = appSettings.localeCode == option.code;
                return ListTile(
                  title: Text(option.label),
                  trailing: isSelected
                      ? Icon(
                          Icons.check_circle,
                          color: Theme.of(context).colorScheme.primary,
                        )
                      : null,
                  onTap: () {
                    appSettings.setLocaleCode(option.code);
                    Navigator.pop(context);
                  },
                );
              }),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  void _showAppThemeModal(ThemeNotifier themeNotifier) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.65,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
            ),
            child: Column(
              children: [
                // 拖拽指示条
                Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 16),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // 标题
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      Icon(
                        Icons.palette,
                        color: Theme.of(context).colorScheme.primary,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '选择应用主题',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                // 主题网格
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 1.3,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemCount: AppThemes.allThemes.length,
                    itemBuilder: (context, index) {
                      final theme = AppThemes.allThemes[index];
                      final isSelected =
                          theme.name == themeNotifier.currentAppTheme.name;

                      return GestureDetector(
                        onTap: () {
                          themeNotifier.setAppTheme(theme);
                          setModalState(() {});
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected
                                  ? theme.lightColorScheme.primary
                                  : Theme.of(context)
                                      .colorScheme
                                      .outline
                                      .withValues(alpha: 0.2),
                              width: isSelected ? 3 : 1,
                            ),
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                theme.lightColorScheme.primaryContainer,
                                theme.lightColorScheme.secondaryContainer,
                              ],
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: theme.lightColorScheme.primary
                                      .withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  AppThemes.getThemeIcon(theme.name),
                                  color: theme.lightColorScheme.primary,
                                  size: 28,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                theme.displayName,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: theme.lightColorScheme.onSurface,
                                ),
                              ),
                              if (isSelected) ...[
                                const SizedBox(height: 6),
                                Icon(
                                  Icons.check_circle,
                                  color: theme.lightColorScheme.primary,
                                  size: 18,
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                // 底部按钮
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    24,
                    12,
                    24,
                    MediaQuery.of(context).padding.bottom + 12,
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => Navigator.pop(context),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        '完成',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showAccentColorModal(ThemeNotifier themeNotifier) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          final selectedColor = themeNotifier.effectiveAccentColor;
          return Container(
            height: MediaQuery.of(context).size.height * 0.58,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
            ),
            child: Column(
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 20),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      Icon(
                        Icons.color_lens_rounded,
                        color: Theme.of(context).colorScheme.primary,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '强调色',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    '推荐优先选择应用主题，再按需覆盖强调色。',
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () async {
                        await themeNotifier.setAccentColor(null);
                        setModalState(() {});
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: selectedColor == null
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(
                                    context,
                                  ).colorScheme.outline.withValues(alpha: 0.3),
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.auto_awesome,
                              color: selectedColor == null
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withValues(alpha: 0.6),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '跟随主题',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: selectedColor == null
                                          ? Theme.of(
                                              context,
                                            ).colorScheme.primary
                                          : Theme.of(
                                              context,
                                            ).colorScheme.onSurface,
                                    ),
                                  ),
                                  Text(
                                    '使用当前应用主题默认强调色',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withValues(alpha: 0.6),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (selectedColor == null)
                              Icon(
                                Icons.check_circle,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 24),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest
                          .withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Theme.of(
                          context,
                        ).colorScheme.outline.withValues(alpha: 0.2),
                      ),
                    ),
                    child: GridView.builder(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 4,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 1.2,
                      ),
                      itemCount: AppThemes.accentColors.length,
                      itemBuilder: (context, index) {
                        final color = AppThemes.accentColors[index];
                        final isSelected =
                            selectedColor?.toARGB32() == color.toARGB32();
                        final colorName = AppThemes.getAccentColorName(color);

                        return GestureDetector(
                          onTap: () async {
                            await themeNotifier.setAccentColor(color);
                            setModalState(() {});
                          },
                          child: Column(
                            children: [
                              Expanded(
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: color,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: isSelected
                                          ? Theme.of(
                                              context,
                                            ).colorScheme.onSurface
                                          : Colors.transparent,
                                      width: 2,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: color.withValues(alpha: 0.3),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: isSelected
                                      ? Icon(
                                          Icons.check,
                                          color: color.computeLuminance() > 0.5
                                              ? Colors.black
                                              : Colors.white,
                                          size: 20,
                                        )
                                      : null,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                colorName,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withValues(alpha: 0.8),
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    24,
                    16,
                    24,
                    MediaQuery.of(context).padding.bottom + 16,
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => Navigator.pop(context),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        '完成',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSwitchSetting({
    required String title,
    required String subtitle,
    required bool value,
    required Function(bool) onChanged,
    required IconData icon,
    bool enabled = true,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 1),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled
              ? () {
                  onChanged(!value);
                  _saveSettings();
                }
              : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.secondary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(
                    icon,
                    size: 16,
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                      ),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurface.withValues(alpha: 0.6),
                            ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: value,
                  onChanged: enabled
                      ? (newValue) {
                          onChanged(newValue);
                          _saveSettings();
                        }
                      : null,
                  activeTrackColor: Theme.of(context).colorScheme.primary,
                  thumbColor: WidgetStateProperty.resolveWith(
                    (states) => states.contains(WidgetState.selected)
                        ? Theme.of(context).colorScheme.onPrimary
                        : Theme.of(context).colorScheme.outline,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAboutCard() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        enabled: !_shouldDisableBlurForCurrentTheme,
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Theme.of(
                context,
              ).colorScheme.outline.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.tertiary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.info_outline,
                      color: Theme.of(context).colorScheme.tertiary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '关于应用',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Theme.of(
                        context,
                      ).colorScheme.primaryContainer.withValues(alpha: 0.3),
                      Theme.of(
                        context,
                      ).colorScheme.secondaryContainer.withValues(alpha: 0.3),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: AppBrandIcon(
                        size: 32,
                        borderRadius: 8,
                        border: Border.all(
                          color: Theme.of(context)
                              .colorScheme
                              .primary
                              .withValues(alpha: 0.28),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '小元阅读器',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'v$_appVersion',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '作者：小元Niki',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                    ),
                    const SizedBox(height: 4),
                    InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: _openGithubRepo,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 4,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.code_rounded,
                              size: 14,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.7),
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                'GitHub 仓库',
                                textAlign: TextAlign.center,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primary
                                          .withValues(alpha: 0.85),
                                      decoration: TextDecoration.underline,
                                      decorationColor: Theme.of(context)
                                          .colorScheme
                                          .primary
                                          .withValues(alpha: 0.6),
                                    ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '2026新年快乐！感谢大家的支持和反馈，祝大家在新的一年里阅读愉快，收获满满！',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withValues(alpha: 0.8),
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openGithubRepo() async {
    final uri = Uri.parse('https://github.com/KeloYuan/Origo-Reader');
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      showSideToast(context, '无法打开 GitHub 链接', icon: Icons.error_outline);
    }
  }

  // WebDAV配置对话框
  Future<void> _showWebDavConfig() async {
    await showDialog<bool>(
      context: context,
      builder: (context) => const WebDavConfigDialog(),
    );
    if (mounted) {
      setState(() {});
    }
  }

  // 立即同步
  Future<void> _syncNow() async {
    try {
      final success = await _webdavService.manualSync();
      if (mounted) {
        if (success) {
          showSideToast(context, '同步成功');
        } else {
          var reason = _webdavService.lastErrorMessage.trim();
          if (reason.startsWith('同步失败:')) {
            reason = reason.substring('同步失败:'.length).trim();
          }
          showSideToast(
            context,
            reason.isNotEmpty ? '同步失败: $reason' : '同步失败',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        showSideToast(context, '同步失败: $e');
      }
    }
  }

  // 同步到 iOS 文件 / iCloud Drive
  Future<void> _syncToIosFiles() async {
    if (!Platform.isIOS) {
      showSideToast(context, '该功能仅支持 iOS');
      return;
    }
    if (_isIosCloudSyncing) {
      return;
    }

    setState(() => _isIosCloudSyncing = true);
    try {
      final result = await _iosCloudSyncService.syncLibrarySnapshot(
        includeBookFiles: true,
        preferICloudDrive: true,
      );

      if (!mounted) return;

      if (!result.success) {
        showSideToast(context, '同步失败：未能获取目标目录');
        return;
      }

      final msg =
          '已同步到${result.storageLabel}\n书籍 ${result.booksCount} 本，文件复制 ${result.copiedBookFilesCount} 个';
      showSideToast(context, msg);
      debugPrint('☁️ iOS 同步目录: ${result.rootPath}');
      if (result.missingBookFilesCount > 0) {
        debugPrint('⚠️ 有 ${result.missingBookFilesCount} 本书原文件缺失，已跳过复制');
      }
    } catch (e) {
      if (!mounted) return;
      showSideToast(context, '同步失败: $e');
    } finally {
      if (mounted) {
        setState(() => _isIosCloudSyncing = false);
      }
    }
  }

  // 构建操作设置
  Widget _buildActionSetting({
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required IconData icon,
    Widget? trailing,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 1),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.tertiary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(
                    icon,
                    size: 16,
                    color: Theme.of(context).colorScheme.tertiary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                      ),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurface.withValues(alpha: 0.6),
                            ),
                      ),
                    ],
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: 8),
                  trailing,
                ] else
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.4),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 同步状态图标
  IconData _getSyncStatusIcon(SyncStatus status) {
    switch (status) {
      case SyncStatus.idle:
        return Icons.cloud_done;
      case SyncStatus.syncing:
        return Icons.sync;
      case SyncStatus.completed:
        return Icons.check_circle;
      case SyncStatus.failed:
        return Icons.error;
      case SyncStatus.noNetwork:
        return Icons.cloud_off;
      case SyncStatus.notConfigured:
        return Icons.cloud_queue;
    }
  }

  /// 同步状态颜色
  Color _getSyncStatusColor(SyncStatus status) {
    switch (status) {
      case SyncStatus.idle:
        return Colors.grey;
      case SyncStatus.syncing:
        return Colors.blue;
      case SyncStatus.completed:
        return Colors.green;
      case SyncStatus.failed:
        return Colors.red;
      case SyncStatus.noNetwork:
        return Colors.orange;
      case SyncStatus.notConfigured:
        return Colors.grey;
    }
  }

  /// 格式化同步时间
  String _formatSyncTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inMinutes < 1) {
      return '刚刚';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}分钟前';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}小时前';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}天前';
    } else {
      return '${time.month}-${time.day}';
    }
  }

  /// 构建同步内容标签
  Widget _buildSyncChip(String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  /// 显示书籍文件同步选择对话框
  Future<void> _showBookFileSyncDialog() async {
    final selectedSet = _webdavService.getBooksSelectedForSync();
    final bookDao = BookDao();
    final allBooks = await bookDao.getAllBooks();

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.upload_file, color: Colors.blue),
                SizedBox(width: 8),
                Text('书籍文件同步'),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 说明文字
                  const Text(
                    '选择需要上传到云端的书籍文件',
                    style: TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: Colors.amber.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline,
                            size: 16, color: Colors.amber),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '书籍文件较大，建议仅选择重要书籍同步',
                            style: TextStyle(
                                fontSize: 12, color: Colors.amber.shade700),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 全选/取消按钮
                  Row(
                    children: [
                      TextButton.icon(
                        onPressed: () {
                          if (selectedSet.length == allBooks.length) {
                            selectedSet.clear();
                          } else {
                            selectedSet.addAll(
                              allBooks
                                  .map((b) => b.id)
                                  .whereType<int>()
                                  .toList(),
                            );
                          }
                          setDialogState(() {});
                        },
                        icon: Icon(
                          selectedSet.length == allBooks.length
                              ? Icons.check_box
                              : Icons.check_box_outline_blank,
                          size: 18,
                        ),
                        label: Text(
                          selectedSet.length == allBooks.length ? '取消全选' : '全选',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '已选: ${selectedSet.length}/${allBooks.length}',
                        style:
                            const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // 书籍列表
                  SizedBox(
                    height: 300,
                    child: allBooks.isEmpty
                        ? const Center(
                            child: Text('暂无书籍'),
                          )
                        : ListView.builder(
                            itemCount: allBooks.length,
                            itemBuilder: (context, index) {
                              final book = allBooks[index];
                              final isSelected = selectedSet.contains(book.id);
                              final file = File(book.filePath);
                              final fileSize =
                                  file.existsSync() ? file.lengthSync() : 0;

                              return CheckboxListTile(
                                value: isSelected,
                                onChanged: (value) {
                                  if (book.id == null) return;
                                  if (value == true) {
                                    selectedSet.add(book.id!);
                                  } else {
                                    selectedSet.remove(book.id!);
                                  }
                                  setDialogState(() {});
                                },
                                title: Text(
                                  book.title,
                                  style: const TextStyle(fontSize: 14),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      book.author,
                                      style: const TextStyle(fontSize: 12),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (fileSize > 0)
                                      Text(
                                        _formatFileSize(fileSize),
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                  ],
                                ),
                                secondary: book.coverImagePath != null &&
                                        book.coverImagePath!.isNotEmpty &&
                                        File(book.coverImagePath!).existsSync()
                                    ? ClipRRect(
                                        borderRadius: BorderRadius.circular(4),
                                        child: Image.file(
                                          File(book.coverImagePath!),
                                          width: 40,
                                          height: 56,
                                          fit: BoxFit.cover,
                                        ),
                                      )
                                    : Container(
                                        width: 40,
                                        height: 56,
                                        decoration: BoxDecoration(
                                          color: Colors.grey
                                              .withValues(alpha: 0.2),
                                          borderRadius:
                                              BorderRadius.circular(4),
                                        ),
                                        child: const Icon(
                                          Icons.book,
                                          size: 20,
                                          color: Colors.grey,
                                        ),
                                      ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () async {
                  final previousSet = _webdavService.getBooksSelectedForSync();
                  for (final book in allBooks) {
                    final bookId = book.id;
                    if (bookId == null) continue;
                    final shouldSync = selectedSet.contains(bookId);
                    if (previousSet.contains(bookId) != shouldSync) {
                      await _webdavService.setBookForSync(bookId, shouldSync);
                    }
                  }
                  if (!context.mounted) return;
                  setState(() {});
                  Navigator.pop(context);
                  _showInfoPopup('已选择 ${selectedSet.length} 本书籍进行文件同步');
                },
                child: const Text('保存'),
              ),
            ],
          );
        },
      ),
    );
  }

  /// 格式化文件大小
  String _formatFileSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
    } else {
      return '${(bytes / 1024 / 1024 / 1024).toStringAsFixed(2)} GB';
    }
  }
}

class _LanguageOption {
  final String code;
  final String label;

  const _LanguageOption({
    required this.code,
    required this.label,
  });
}

class _UiStyleOption {
  final AppUiStyle style;

  const _UiStyleOption({required this.style});
}
