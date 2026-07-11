// 文件说明：设置页面，负责应用主题、语言、同步、备份和外观设置。
// 技术要点：Flutter UI、Icons Plus、Package Info、Provider、SharedPreferences、URL Launcher。

import 'dart:async';
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
      _aiSettingsLoaded = true;
    });
    _applyAiDraft(_aiDraftByProvider[_selectedAiProvider]!);

    if (prefs.getBool('enableAnimations') != true) {
      await prefs.setBool('enableAnimations', true);
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
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    final isZh = Localizations.localeOf(context).languageCode == 'zh';
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
      padding: const EdgeInsets.fromLTRB(20, 2, 20, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isZh
                          ? '让 AI 读懂你正在看的内容'
                          : 'Let AI understand what you are reading',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2,
                          ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      isZh
                          ? '选一个服务商和模型，填入 API Key 即可。高级参数保持可选。'
                          : 'Choose a provider and model, then add an API key. Advanced settings stay optional.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            height: 1.45,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: currentSettings.isConfigured
                      ? colorScheme.primary.withValues(alpha: 0.1)
                      : colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      currentSettings.isConfigured
                          ? Icons.check_circle_rounded
                          : Icons.circle_outlined,
                      size: 15,
                      color: currentSettings.isConfigured
                          ? colorScheme.primary
                          : colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      currentSettings.isConfigured
                          ? (isZh ? '已就绪' : 'Ready')
                          : (isZh ? '未配置' : 'Not set'),
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: currentSettings.isConfigured
                                ? colorScheme.primary
                                : colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            isZh ? '服务商' : 'Provider',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 9),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: AIProviderType.values.map((provider) {
              final selected = provider == _selectedAiProvider;
              return ChoiceChip(
                selected: selected,
                label: Text(provider.displayName),
                showCheckmark: false,
                avatar: selected
                    ? Icon(Icons.check_rounded,
                        size: 16, color: colorScheme.onPrimaryContainer)
                    : null,
                onSelected: (_) {
                  if (!selected) _onAiProviderChanged(provider);
                },
                side: BorderSide(
                  color: selected
                      ? colorScheme.primary.withValues(alpha: 0.35)
                      : colorScheme.outlineVariant,
                ),
                selectedColor: colorScheme.primaryContainer,
                backgroundColor: Colors.transparent,
                labelStyle: TextStyle(
                  color: selected
                      ? colorScheme.onPrimaryContainer
                      : colorScheme.onSurfaceVariant,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 18),
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
              if (preset != null) _onAiPresetChanged(preset);
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
              }
            },
            decoration: InputDecoration(
              labelText: 'API Key',
              hintText: isZh ? '仅保存在当前设备' : 'Stored on this device only',
              prefixIcon: const Icon(Icons.key_rounded),
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                tooltip:
                    _obscureAiApiKey ? l10n.settingsShow : l10n.settingsHide,
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
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _showAiCustomConfigDialog,
                  icon: const Icon(Icons.tune_rounded),
                  label: Text(isZh ? '高级设置' : 'Advanced'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
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
                      : const Icon(Icons.check_rounded),
                  label: Text(_isSavingAiSettings
                      ? l10n.settingsAiSaving
                      : (isZh ? '保存并启用' : 'Save and enable')),
                ),
              ),
            ],
          ),
        ],
      ),
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
