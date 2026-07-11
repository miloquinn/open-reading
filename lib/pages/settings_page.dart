// 文件说明：设置页面，负责应用主题、语言、同步、备份和外观设置。
// 技术要点：Flutter UI、Icons Plus、Package Info、Provider、SharedPreferences、URL Launcher。

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../main.dart';
import '../utils/app_themes.dart';
import '../l10n/app_localizations.dart';
import '../reader_core/ai/ai_service.dart';
import '../services/core/core_services.dart';
import '../widgets/side_toast.dart';
import '../widgets/app_brand_icon.dart';
import 'home_shell_page.dart';
import 'home_layout_constants.dart';
import '../utils/localization_extension.dart';
import '../utils/page_style_helper.dart';
import '../utils/system_ui_helper.dart';
import '../utils/ui_style.dart';

part 'settings_page_cover_actions_part.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  static const _aiQuickModelsKey = 'reader_ai_quick_models_v1';
  static const _activeAiQuickModelKey = 'reader_ai_active_quick_model_v1';

  final ReaderHttpAIService _aiService = ReaderHttpAIService();
  late final TextEditingController _aiApiKeyController;
  late final TextEditingController _aiModelController;
  late final TextEditingController _aiBaseUrlController;
  late final TextEditingController _aiTempController;

  bool _enableAutoSave = true;
  bool _keepScreenOn = false;
  int _autoSaveInterval = 30;

  // 阅读设置
  bool _enableVolumeKeyTurn = true;
  bool _showSystemStatusBarInReader = false;

  bool _enableAutoExtractCover = true;

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
  List<_AiQuickModel> _aiQuickModels = const [];
  String? _activeAiQuickModelId;

  @override
  void initState() {
    super.initState();
    _aiApiKeyController = TextEditingController();
    _aiModelController = TextEditingController();
    _aiBaseUrlController = TextEditingController();
    _aiTempController = TextEditingController();
    unawaited(_loadAppVersion());
    _loadSettings();
    // 状态栏设置现在由_SettingsPageWrapper处理
  }

  @override
  void dispose() {
    _aiApiKeyController.dispose();
    _aiModelController.dispose();
    _aiBaseUrlController.dispose();
    _aiTempController.dispose();
    super.dispose();
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
    final quickModels = _loadAiQuickModels(
      prefs,
      activeAiSettings,
      aiSettingsByProvider,
    );
    var activeQuickModelId = prefs.getString(_activeAiQuickModelKey);
    if (activeQuickModelId == null) {
      for (final item in quickModels) {
        if (item.matches(activeAiSettings)) {
          activeQuickModelId = item.id;
          break;
        }
      }
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _enableAutoSave = prefs.getBool('enableAutoSave') ?? true;
      _keepScreenOn = prefs.getBool('keepScreenOn') ?? false;
      _autoSaveInterval = prefs.getInt('autoSaveInterval') ?? 30;

      _enableAutoExtractCover = prefs.getBool('enableAutoExtractCover') ?? true;

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
      _aiQuickModels = quickModels;
      _activeAiQuickModelId = activeQuickModelId;
      _aiSettingsLoaded = true;
    });
    _applyAiDraft(_aiDraftByProvider[_selectedAiProvider]!);

    if (prefs.getBool('enableAnimations') != true) {
      await prefs.setBool('enableAnimations', true);
    }
  }

  List<_AiQuickModel> _loadAiQuickModels(
    SharedPreferences prefs,
    AIProviderSettings activeSettings,
    Map<AIProviderType, AIProviderSettings> settingsByProvider,
  ) {
    final raw = prefs.getString(_aiQuickModelsKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          final saved = decoded
              .whereType<Map>()
              .map(
                (item) => _AiQuickModel.fromJson(
                  Map<String, dynamic>.from(item),
                ),
              )
              .whereType<_AiQuickModel>()
              .toList(growable: false);
          if (saved.isNotEmpty) return saved;
        }
      } catch (_) {
        // Fall back to the curated starter cards below.
      }
    }

    final result = <_AiQuickModel>[
      _AiQuickModel.fromSettings(activeSettings, isCustom: true),
    ];
    const starterPresetIds = <String>[
      'deepseek_chat',
      'openai_gpt_4_1_mini',
      'gemini_2_flash',
    ];
    for (final presetId in starterPresetIds) {
      final preset = AIModelPresets.all.firstWhere(
        (item) => item.id == presetId,
        orElse: () => AIModelPresets.all.first,
      );
      final providerSettings = settingsByProvider[preset.provider];
      final sameEndpoint = providerSettings != null &&
          providerSettings.baseUrl == preset.toSettings().baseUrl;
      final settings = preset.toSettings(
        apiKey: sameEndpoint ? providerSettings.apiKey : '',
      );
      if (result.any((item) => item.matches(settings))) continue;
      result.add(
        _AiQuickModel(
          id: 'preset-${preset.id}',
          settings: settings,
          isCustom: false,
        ),
      );
    }
    return result;
  }

  Future<void> _persistAiQuickModels() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _aiQuickModelsKey,
      jsonEncode(_aiQuickModels.map((item) => item.toJson()).toList()),
    );
    if (_activeAiQuickModelId != null) {
      await prefs.setString(
        _activeAiQuickModelKey,
        _activeAiQuickModelId!,
      );
    }
  }

  String _knownAiApiKey(AIProviderType provider, String baseUrl) {
    final normalizedBase = normalizeAIBaseUrl(provider, baseUrl);
    for (final item in _aiQuickModels) {
      if (item.settings.provider == provider &&
          item.settings.baseUrl == normalizedBase &&
          item.settings.apiKey.isNotEmpty) {
        return item.settings.apiKey;
      }
    }
    final draft = _aiDraftByProvider[provider];
    if (draft != null &&
        draft.baseUrl == normalizedBase &&
        draft.apiKey.isNotEmpty) {
      return draft.apiKey;
    }
    return '';
  }

  Future<void> _loadAppVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      final version = info.version.trim();
      if (!mounted) {
        return;
      }
      setState(() {
        final buildNumber = info.buildNumber.trim();
        _appVersion = version.isNotEmpty
            ? (buildNumber.isNotEmpty ? '$version ($buildNumber)' : version)
            : '3.0.0';
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
        return context.l10n.settingsAiTempHintMinimax;
      case AIProviderType.claude:
      case AIProviderType.gemini:
        return 'Temperature: 0.00 ~ 1.00';
      case AIProviderType.glm:
      case AIProviderType.openai:
        return 'Temperature: 0.00 ~ 2.00';
    }
  }

  // ignore: unused_element
  Future<void> _showAiCustomConfigDialog() async {
    final l10n = context.l10n;
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
              title: Text(l10n.settingsAiCustomConfigTitle),
              content: SizedBox(
                width: 440,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.settingsAiCurrentProvider(
                          _selectedAiProvider.displayName,
                        ),
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
                  child: Text(l10n.cancel),
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
                                ? l10n.settingsAiTempErrorMinimax
                                : l10n.settingsAiTempErrorOutOfRange;
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
                  child: Text(l10n.settingsApply),
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
    showSideToast(context, l10n.settingsAiCustomApplied);
  }

  Future<void> _saveAiSettings() async {
    final apiKey = _aiApiKeyController.text.trim();
    if (apiKey.isEmpty) {
      setState(() {
        _aiSettingsError = context.l10n.settingsAiApiKeyRequired;
      });
      return;
    }

    final model = _aiModelController.text.trim();
    if (model.isEmpty) {
      setState(() {
        _aiSettingsError = context.l10n.settingsAiModelRequired;
      });
      return;
    }

    final baseUrl = _aiBaseUrlController.text.trim();
    final uri = Uri.tryParse(baseUrl);
    if (baseUrl.isEmpty ||
        uri == null ||
        !(uri.isScheme('http') || uri.isScheme('https'))) {
      setState(() {
        _aiSettingsError = context.l10n.settingsAiBaseUrlInvalid;
      });
      return;
    }

    final parsedTemp = double.tryParse(_aiTempController.text.trim());
    if (parsedTemp == null ||
        !_validateAiTemperature(_selectedAiProvider, parsedTemp)) {
      setState(() {
        _aiSettingsError = _selectedAiProvider == AIProviderType.minimax
            ? context.l10n.settingsAiTempErrorMinimax
            : context.l10n.settingsAiTempErrorOutOfRange;
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
      showSideToast(context, context.l10n.settingsAiSettingsSaved);
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _aiSettingsError = context.l10n.settingsSaveFailed('$e');
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
            const SizedBox(height: 18),
          ],
          _buildSettingsIntro(),
          const SizedBox(height: 24),
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
              _buildSwitchSetting(
                title: l10n.settingsVolumeKeyTurnTitle,
                subtitle: l10n.settingsVolumeKeyTurnSubtitle,
                value: _enableVolumeKeyTurn,
                onChanged: (value) =>
                    setState(() => _enableVolumeKeyTurn = value),
                icon: Icons.volume_up,
              ),
              _buildSwitchSetting(
                title: l10n.settingsShowStatusBarTitle,
                subtitle: _showSystemStatusBarInReader
                    ? l10n.settingsShowStatusBarOnSubtitle
                    : l10n.settingsShowStatusBarOffSubtitle,
                value: _showSystemStatusBarInReader,
                onChanged: (value) =>
                    setState(() => _showSystemStatusBarInReader = value),
                icon: Icons.vertical_align_top_rounded,
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildSectionCard(
            title: l10n.settingsAiAssistantTitle,
            icon: Icons.auto_awesome_outlined,
            children: [
              _buildAiSettingsSection(),
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
            title: l10n.settingsSystemSettingsTitle,
            icon: Icons.settings_outlined,
            children: [
              _buildSwitchSetting(
                title: l10n.settingsKeepScreenOnTitle,
                subtitle: l10n.settingsKeepScreenOnSubtitle,
                value: _keepScreenOn,
                onChanged: (value) => setState(() => _keepScreenOn = value),
                icon: Icons.stay_current_portrait,
              ),
              _buildSwitchSetting(
                title: l10n.settingsAutoSaveTitle,
                subtitle: l10n.settingsAutoSaveSubtitle,
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

  Widget _buildSettingsIntro() {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 4,
            height: 52,
            decoration: BoxDecoration(
              color: scheme.primary,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.settings,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  Localizations.localeOf(context).languageCode == 'zh'
                      ? '只保留真正影响阅读体验的选项。'
                      : 'Only the options that shape your reading experience.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                        height: 1.45,
                      ),
                ),
              ],
            ),
          ),
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
          onTap: () =>
              showSideToast(context, context.l10n.settingsHelpPlaceholder),
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

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    final palette = PageStyleHelper.palette(context);
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
          child: Row(
            children: [
              Icon(icon, color: scheme.primary, size: 18),
              const SizedBox(width: 9),
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ],
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: palette.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: palette.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildAiSettingsSection() {
    if (!_aiSettingsLoaded) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final isZh = Localizations.localeOf(context).languageCode == 'zh';
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 2, 20, 12),
            child: Text(
              isZh
                  ? '左右滑动选择模型，点击卡片即可切换。'
                  : 'Swipe through models and tap a card to switch.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
          SizedBox(
            height: 154,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              physics: const BouncingScrollPhysics(),
              itemCount: _aiQuickModels.length + 1,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                if (index == _aiQuickModels.length) {
                  return _buildAddAiModelCard();
                }
                return _buildAiModelCard(_aiQuickModels[index]);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAiModelCard(_AiQuickModel item) {
    final scheme = Theme.of(context).colorScheme;
    final selected = item.id == _activeAiQuickModelId;
    final configured = item.settings.isConfigured;
    return SizedBox(
      width: 184,
      child: Material(
        color: selected
            ? scheme.primaryContainer.withValues(alpha: 0.7)
            : scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => _activateAiQuickModel(item),
          onLongPress: item.isCustom ? () => _removeAiQuickModel(item) : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: selected ? scheme.primary : scheme.outlineVariant,
                width: selected ? 1.6 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: scheme.surface.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        item.settings.provider.displayName,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      selected
                          ? Icons.check_circle_rounded
                          : configured
                              ? Icons.circle_rounded
                              : Icons.key_off_rounded,
                      size: 18,
                      color: selected
                          ? scheme.primary
                          : configured
                              ? scheme.onSurfaceVariant
                              : scheme.error,
                    ),
                  ],
                ),
                const Spacer(),
                Text(
                  item.settings.model,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                      ),
                ),
                const SizedBox(height: 7),
                Text(
                  configured ? 'API Key 已配置' : '点击完成配置',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color:
                            configured ? scheme.onSurfaceVariant : scheme.error,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAddAiModelCard() {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 112,
      child: Material(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => _showAiModelSheet(),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.add_rounded, color: scheme.primary),
                ),
                const SizedBox(height: 10),
                Text(
                  '添加模型',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _activateAiQuickModel(_AiQuickModel item) async {
    if (!item.settings.isConfigured) {
      await _showAiModelSheet(editing: item);
      return;
    }
    try {
      await _aiService.saveSettings(item.settings);
      if (!mounted) return;
      setState(() {
        _activeAiQuickModelId = item.id;
        _selectedAiProvider = item.settings.provider;
        _aiDraftByProvider[item.settings.provider] = item.settings;
        _applyAiDraft(item.settings);
      });
      await _persistAiQuickModels();
      if (mounted) {
        showSideToast(context, '已切换到 ${item.settings.model}');
      }
    } catch (error) {
      if (mounted) showSideToast(context, '$error');
    }
  }

  Future<void> _removeAiQuickModel(_AiQuickModel item) async {
    if (_aiQuickModels.length <= 1) return;
    setState(() {
      _aiQuickModels = _aiQuickModels
          .where((candidate) => candidate.id != item.id)
          .toList(growable: false);
      if (_activeAiQuickModelId == item.id) {
        _activeAiQuickModelId = _aiQuickModels.first.id;
      }
    });
    await _persistAiQuickModels();
  }

  Future<void> _showAiModelSheet({_AiQuickModel? editing}) async {
    final initial = editing?.settings ??
        AIModelPresets.defaultForProvider(_selectedAiProvider).toSettings(
          apiKey: _aiDraftByProvider[_selectedAiProvider]?.apiKey ?? '',
        );
    var provider = initial.provider;
    var customMode = editing?.isCustom ?? false;
    var selectedPreset = AIModelPresets.match(initial) ??
        AIModelPresets.defaultForProvider(provider);
    final apiKeyController = TextEditingController(text: initial.apiKey);
    final baseUrlController = TextEditingController(text: initial.baseUrl);
    final modelController = TextEditingController(text: initial.model);
    final temperatureController = TextEditingController(
      text: initial.temperature.toStringAsFixed(2),
    );
    var fetchedModels = <String>[];
    var loadingModels = false;
    String? errorText;

    final result = await showModalBottomSheet<_AiQuickModel>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          final scheme = Theme.of(sheetContext).colorScheme;
          final presets = AIModelPresets.byProvider(provider);

          void applyPreset(AIModelPreset preset) {
            selectedPreset = preset;
            baseUrlController.text = preset.baseUrl;
            modelController.text = preset.model;
            temperatureController.text = preset.temperature.toStringAsFixed(2);
            apiKeyController.text = _knownAiApiKey(
              preset.provider,
              preset.baseUrl,
            );
          }

          Future<void> fetchModels() async {
            final apiKey = apiKeyController.text.trim();
            final baseUrl = baseUrlController.text.trim();
            if (apiKey.isEmpty || baseUrl.isEmpty) {
              setSheetState(() {
                errorText = '请先填写 Base URL 和 API Key';
              });
              return;
            }
            setSheetState(() {
              loadingModels = true;
              errorText = null;
            });
            try {
              final models = await _aiService.fetchAvailableModels(
                AIProviderSettings(
                  provider: provider,
                  apiKey: apiKey,
                  baseUrl: baseUrl,
                  model: modelController.text.trim(),
                  temperature:
                      double.tryParse(temperatureController.text) ?? 0.7,
                ),
              );
              if (!sheetContext.mounted) return;
              setSheetState(() {
                fetchedModels = models;
                loadingModels = false;
              });
            } catch (error) {
              if (!sheetContext.mounted) return;
              setSheetState(() {
                loadingModels = false;
                errorText = '$error';
              });
            }
          }

          Future<void> saveModel() async {
            final temperature =
                double.tryParse(temperatureController.text.trim());
            final settings = AIProviderSettings(
              provider: provider,
              apiKey: apiKeyController.text.trim(),
              baseUrl: baseUrlController.text.trim(),
              model: modelController.text.trim(),
              temperature: temperature ?? 0.7,
            ).normalized();
            final validation = validateAIProviderSettings(settings);
            if (validation != null) {
              setSheetState(() => errorText = validation);
              return;
            }
            try {
              await _aiService.saveSettings(settings);
              if (!sheetContext.mounted) return;
              Navigator.of(sheetContext).pop(
                _AiQuickModel(
                  id: editing?.id ?? _AiQuickModel.idFor(settings),
                  settings: settings,
                  isCustom: customMode,
                ),
              );
            } catch (error) {
              if (sheetContext.mounted) {
                setSheetState(() => errorText = '$error');
              }
            }
          }

          return AnimatedPadding(
            duration: const Duration(milliseconds: 180),
            padding: EdgeInsets.only(
              bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
            ),
            child: FractionallySizedBox(
              heightFactor: 0.92,
              child: Material(
                color: scheme.surface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    Container(
                      width: 42,
                      height: 4,
                      margin: const EdgeInsets.only(top: 10, bottom: 8),
                      decoration: BoxDecoration(
                        color: scheme.outlineVariant,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 12, 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  editing == null ? '添加模型' : '配置模型',
                                  style: Theme.of(sheetContext)
                                      .textTheme
                                      .titleLarge
                                      ?.copyWith(fontWeight: FontWeight.w800),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  '每张快捷卡片只绑定一个模型',
                                  style: Theme.of(sheetContext)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        color: scheme.onSurfaceVariant,
                                      ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(sheetContext).pop(),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
                        children: [
                          SegmentedButton<bool>(
                            segments: const [
                              ButtonSegment(
                                value: false,
                                label: Text('预设模型'),
                                icon: Icon(Icons.auto_awesome_outlined),
                              ),
                              ButtonSegment(
                                value: true,
                                label: Text('自定义'),
                                icon: Icon(Icons.tune_rounded),
                              ),
                            ],
                            selected: {customMode},
                            onSelectionChanged: (selection) {
                              setSheetState(() {
                                customMode = selection.first;
                                errorText = null;
                                fetchedModels = [];
                                if (!customMode) applyPreset(selectedPreset);
                              });
                            },
                          ),
                          const SizedBox(height: 18),
                          DropdownButtonFormField<AIProviderType>(
                            initialValue: provider,
                            decoration: const InputDecoration(
                              labelText: '大模型服务商',
                              prefixIcon: Icon(Icons.hub_outlined),
                              border: OutlineInputBorder(),
                            ),
                            items: AIProviderType.values
                                .map(
                                  (item) => DropdownMenuItem(
                                    value: item,
                                    child: Text(item.displayName),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              if (value == null) return;
                              setSheetState(() {
                                provider = value;
                                selectedPreset =
                                    AIModelPresets.defaultForProvider(value);
                                fetchedModels = [];
                                errorText = null;
                                if (!customMode) {
                                  applyPreset(selectedPreset);
                                } else {
                                  apiKeyController.text = _knownAiApiKey(
                                    value,
                                    baseUrlController.text,
                                  );
                                }
                              });
                            },
                          ),
                          if (!customMode) ...[
                            const SizedBox(height: 16),
                            DropdownButtonFormField<AIModelPreset>(
                              key: ValueKey(
                                'sheet-${provider.value}-${selectedPreset.id}',
                              ),
                              initialValue: selectedPreset,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: '预设模型',
                                prefixIcon: Icon(Icons.memory_rounded),
                                border: OutlineInputBorder(),
                              ),
                              items: presets
                                  .map(
                                    (preset) => DropdownMenuItem(
                                      value: preset,
                                      child: Text(
                                        '${preset.vendor} · ${preset.label}',
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (preset) {
                                if (preset == null) return;
                                setSheetState(() => applyPreset(preset));
                              },
                            ),
                          ],
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: baseUrlController,
                            enabled: customMode,
                            decoration: const InputDecoration(
                              labelText: 'Base URL',
                              prefixIcon: Icon(Icons.link_rounded),
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: apiKeyController,
                            obscureText: _obscureAiApiKey,
                            decoration: InputDecoration(
                              labelText: 'API Key',
                              prefixIcon: const Icon(Icons.key_rounded),
                              border: const OutlineInputBorder(),
                              suffixIcon: IconButton(
                                onPressed: () {
                                  setState(() {
                                    _obscureAiApiKey = !_obscureAiApiKey;
                                  });
                                  setSheetState(() {});
                                },
                                icon: Icon(
                                  _obscureAiApiKey
                                      ? Icons.visibility_off_rounded
                                      : Icons.visibility_rounded,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: modelController,
                            enabled: customMode,
                            decoration: InputDecoration(
                              labelText: '模型型号',
                              prefixIcon: const Icon(Icons.smart_toy_outlined),
                              border: const OutlineInputBorder(),
                              suffixIcon: customMode
                                  ? IconButton(
                                      tooltip: '自动获取模型',
                                      onPressed:
                                          loadingModels ? null : fetchModels,
                                      icon: loadingModels
                                          ? const SizedBox(
                                              width: 18,
                                              height: 18,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                              ),
                                            )
                                          : const Icon(Icons.refresh_rounded),
                                    )
                                  : null,
                            ),
                          ),
                          if (customMode) ...[
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton.icon(
                                onPressed: loadingModels ? null : fetchModels,
                                icon: const Icon(Icons.travel_explore_rounded),
                                label: const Text('自动获取模型列表'),
                              ),
                            ),
                          ],
                          if (fetchedModels.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              '选择一个模型',
                              style: Theme.of(sheetContext)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              constraints: const BoxConstraints(maxHeight: 220),
                              decoration: BoxDecoration(
                                border:
                                    Border.all(color: scheme.outlineVariant),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: ListView.builder(
                                shrinkWrap: true,
                                itemCount: fetchedModels.length,
                                itemBuilder: (_, index) {
                                  final model = fetchedModels[index];
                                  final selected =
                                      modelController.text.trim() == model;
                                  return ListTile(
                                    dense: true,
                                    title: Text(model),
                                    trailing: Icon(
                                      selected
                                          ? Icons.check_circle_rounded
                                          : Icons.circle_outlined,
                                      color: selected ? scheme.primary : null,
                                    ),
                                    onTap: () {
                                      modelController.text = model;
                                      setSheetState(() {});
                                    },
                                  );
                                },
                              ),
                            ),
                          ],
                          if (customMode) ...[
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: temperatureController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              decoration: const InputDecoration(
                                labelText: 'Temperature',
                                prefixIcon: Icon(Icons.thermostat_rounded),
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ],
                          if (errorText != null) ...[
                            const SizedBox(height: 12),
                            Text(
                              errorText!,
                              style: TextStyle(
                                color: scheme.error,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                      child: SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: saveModel,
                          icon: const Icon(Icons.add_task_rounded),
                          label: Text(editing == null ? '添加并启用' : '保存并启用'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );

    apiKeyController.dispose();
    baseUrlController.dispose();
    modelController.dispose();
    temperatureController.dispose();

    if (result == null || !mounted) return;
    setState(() {
      final existingIndex =
          _aiQuickModels.indexWhere((item) => item.id == result.id);
      if (existingIndex >= 0) {
        final next = [..._aiQuickModels];
        next[existingIndex] = result;
        _aiQuickModels = next;
      } else {
        _aiQuickModels = [..._aiQuickModels, result];
      }
      _activeAiQuickModelId = result.id;
      _selectedAiProvider = result.settings.provider;
      _aiDraftByProvider[result.settings.provider] = result.settings;
      _applyAiDraft(result.settings);
    });
    await _persistAiQuickModels();
  }

  // Kept temporarily for migration from the previous full-page AI editor.
  // ignore: unused_element
  Future<void> _openAiSettingsPage() async {
    final isZh = Localizations.localeOf(context).languageCode == 'zh';
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (routeContext) => StatefulBuilder(
          builder: (routeContext, setRouteState) => Scaffold(
            appBar: AppBar(
              title: Text(isZh ? 'AI 阅读助手' : 'AI Reading Assistant'),
              scrolledUnderElevation: 0,
            ),
            body: SafeArea(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                children: [
                  Text(
                    isZh
                        ? '选择服务商和模型，填写 API Key 即可。其余参数保持默认。'
                        : 'Choose a provider and model, then enter your API key.',
                    style:
                        Theme.of(routeContext).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(routeContext)
                                  .colorScheme
                                  .onSurfaceVariant,
                              height: 1.5,
                            ),
                  ),
                  const SizedBox(height: 24),
                  _buildAiConfigurationForm(setRouteState),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  Widget _buildAiConfigurationForm(StateSetter setRouteState) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    final isZh = Localizations.localeOf(context).languageCode == 'zh';
    final currentSettings = (_aiDraftByProvider[_selectedAiProvider] ??
            AIProviderSettings.defaults(_selectedAiProvider))
        .normalized();
    final matchedPreset = AIModelPresets.match(currentSettings);
    final providerPresets = AIModelPresets.byProvider(_selectedAiProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<AIProviderType>(
          key: ValueKey<String>('ai-provider-${_selectedAiProvider.value}'),
          initialValue: _selectedAiProvider,
          decoration: InputDecoration(
            labelText: isZh ? '服务商' : 'Provider',
            prefixIcon: const Icon(Icons.cloud_outlined),
            border: const OutlineInputBorder(),
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
            if (provider == null || provider == _selectedAiProvider) return;
            _onAiProviderChanged(provider);
            setRouteState(() {});
          },
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<AIModelPreset>(
          key: ValueKey<String>(
            'ai-preset-${_selectedAiProvider.value}-${_selectedAiPreset?.id ?? 'custom'}',
          ),
          initialValue: matchedPreset,
          hint: Text(l10n.settingsAiPresetHint),
          isExpanded: true,
          decoration: InputDecoration(
            labelText: isZh ? '模型' : 'Model',
            prefixIcon: const Icon(Icons.memory_rounded),
            border: const OutlineInputBorder(),
            helperText: matchedPreset == null
                ? (isZh ? '正在使用自定义模型参数' : 'Using custom model settings')
                : '${matchedPreset.vendor} · ${matchedPreset.model}',
          ),
          items: providerPresets
              .map(
                (preset) => DropdownMenuItem(
                  value: preset,
                  child: Text(
                    '${preset.vendor} · ${preset.label}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )
              .toList(),
          onChanged: (preset) {
            if (preset != null) {
              _onAiPresetChanged(preset);
              setRouteState(() {});
            }
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _aiApiKeyController,
          obscureText: _obscureAiApiKey,
          onChanged: (_) {
            if (_aiSettingsError != null) {
              setState(() {
                _aiSettingsError = null;
              });
              setRouteState(() {});
            }
          },
          decoration: InputDecoration(
            labelText: 'API Key',
            hintText: isZh ? '仅保存在当前设备' : 'Stored on this device only',
            prefixIcon: const Icon(Icons.key_rounded),
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              tooltip: _obscureAiApiKey ? l10n.settingsShow : l10n.settingsHide,
              onPressed: () {
                setState(() {
                  _obscureAiApiKey = !_obscureAiApiKey;
                });
                setRouteState(() {});
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
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.error_outline_rounded,
                  size: 17, color: colorScheme.error),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  _aiSettingsError!,
                  style: TextStyle(
                    color: colorScheme.error,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: _isSavingAiSettings
              ? null
              : () async {
                  await _saveAiSettings();
                  setRouteState(() {});
                },
          icon: _isSavingAiSettings
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: colorScheme.onPrimary,
                  ),
                )
              : const Icon(Icons.check_rounded),
          label: Text(
            _isSavingAiSettings
                ? l10n.settingsAiSaving
                : (isZh ? '保存并启用' : 'Save and enable'),
          ),
        ),
      ],
    );
  }

  Widget _buildThemeToggle(ThemeNotifier themeNotifier) {
    final mode = themeNotifier.themeMode;
    final l10n = context.l10n;
    return _buildActionSetting(
      title: l10n.settingsDarkModeTitle,
      subtitle: l10n.settingsCurrentValue(_themeModeLabel(mode)),
      onTap: () => _showThemeModeModal(themeNotifier),
      icon: _themeModeIcon(mode),
    );
  }

  Widget _buildUiStyleSelector(ThemeNotifier themeNotifier) {
    final currentStyle = themeNotifier.uiStyle;
    final l10n = context.l10n;
    return _buildActionSetting(
      title: l10n.settingsUiStyleTitle,
      subtitle: l10n.settingsCurrentValue(currentStyle.displayName),
      onTap: () => _showUiStyleModal(themeNotifier),
      icon: currentStyle.icon,
    );
  }

  void _showUiStyleModal(ThemeNotifier themeNotifier) {
    final l10n = context.l10n;
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
                        l10n.settingsUiStyleTitle,
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
                            reason: l10n.settingsUiStyleSwitchedRestart(
                              item.style.displayName,
                            ),
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
    final l10n = context.l10n;
    final accentSummary = themeNotifier.isUsingThemeAccent
        ? l10n.settingsAccentFollowTheme
        : l10n.settingsAccentValue(
            AppThemes.getAccentColorName(themeNotifier.effectiveAccentColor!));
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
                        l10n.settingsAppThemeTitle,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                      ),
                      Text(
                        l10n.settingsCurrentThemeSummary(
                          themeNotifier.currentAppTheme.displayName,
                          accentSummary,
                        ),
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
    final l10n = context.l10n;
    final accentColor = themeNotifier.effectiveAccentColor;
    final subtitle = accentColor == null
        ? l10n.settingsFollowAppTheme
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
                        l10n.settingsAccentColorTitle,
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
        hint: l10n.settingsThemeModeSystemHint,
        icon: Icons.brightness_auto,
      ),
      (
        mode: ThemeMode.light,
        label: l10n.lightMode,
        hint: l10n.settingsThemeModeLightHint,
        icon: Icons.light_mode,
      ),
      (
        mode: ThemeMode.dark,
        label: l10n.darkMode,
        hint: l10n.settingsThemeModeDarkHint,
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
                        l10n.settingsDarkModeTitle,
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
    final l10n = context.l10n;
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
                        l10n.settingsSelectAppTheme,
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
                      child: Text(
                        l10n.settingsDone,
                        style: const TextStyle(
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
    final l10n = context.l10n;
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
                        l10n.settingsAccentColorTitle,
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
                    l10n.settingsAccentColorAdvice,
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
                                    l10n.settingsAccentFollowThemeOption,
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
                                    l10n.settingsAccentFollowThemeDesc,
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
                      child: Text(
                        l10n.settingsDone,
                        style: const TextStyle(
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
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final palette = PageStyleHelper.palette(context);
    final isZh = Localizations.localeOf(context).languageCode == 'zh';
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppBrandIcon(
                size: 48,
                borderRadius: 12,
                border:
                    Border.all(color: scheme.primary.withValues(alpha: 0.22)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.settingsAppName,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                          ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      isZh
                          ? '开源、跨平台、专注阅读'
                          : 'Open source, cross-platform, focused on reading',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Divider(height: 1),
          const SizedBox(height: 14),
          _buildAboutLine(isZh ? '版本' : 'Version', _appVersion),
          _buildAboutLine(isZh ? '维护者' : 'Maintainer', 'miloquinn'),
          _buildAboutLine(isZh ? '许可证' : 'License', 'MIT'),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _openGithubRepo,
              icon: const Icon(Icons.code_rounded),
              label: const Text('github.com/miloquinn/open-reading'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAboutLine(String label, String value) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          SizedBox(
            width: 76,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openGithubRepo() async {
    final uri = Uri.parse('https://github.com/miloquinn/open-reading');
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      showSideToast(context, context.l10n.settingsGithubOpenFailed,
          icon: Icons.error_outline);
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
}

class _AiQuickModel {
  const _AiQuickModel({
    required this.id,
    required this.settings,
    required this.isCustom,
  });

  final String id;
  final AIProviderSettings settings;
  final bool isCustom;

  factory _AiQuickModel.fromSettings(
    AIProviderSettings settings, {
    required bool isCustom,
  }) {
    final normalized = settings.normalized();
    return _AiQuickModel(
      id: idFor(normalized),
      settings: normalized,
      isCustom: isCustom,
    );
  }

  static String idFor(AIProviderSettings settings) {
    final source =
        '${settings.provider.value}|${settings.baseUrl}|${settings.model}';
    return 'model-${base64Url.encode(utf8.encode(source)).replaceAll('=', '')}';
  }

  bool matches(AIProviderSettings other) {
    final normalized = other.normalized();
    return settings.provider == normalized.provider &&
        settings.baseUrl == normalized.baseUrl &&
        settings.model == normalized.model;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'provider': settings.provider.value,
        'apiKey': settings.apiKey,
        'baseUrl': settings.baseUrl,
        'model': settings.model,
        'temperature': settings.temperature,
        'isCustom': isCustom,
      };

  static _AiQuickModel? fromJson(Map<String, dynamic> json) {
    final id = json['id']?.toString() ?? '';
    final model = json['model']?.toString() ?? '';
    final baseUrl = json['baseUrl']?.toString() ?? '';
    if (id.isEmpty || model.isEmpty || baseUrl.isEmpty) return null;
    final settings = AIProviderSettings(
      provider: AIProviderTypeX.fromValue(json['provider']?.toString()),
      apiKey: json['apiKey']?.toString() ?? '',
      baseUrl: baseUrl,
      model: model,
      temperature: (json['temperature'] as num?)?.toDouble() ?? 0.7,
    ).normalized();
    return _AiQuickModel(
      id: id,
      settings: settings,
      isCustom: json['isCustom'] == true,
    );
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
