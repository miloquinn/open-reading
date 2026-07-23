// 文件说明：设置页面，负责应用主题、语言、同步、备份和外观设置。
// 技术要点：Flutter UI、Icons Plus、Package Info、Provider、SharedPreferences、URL Launcher。

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:xxread/core/reader/reader_keep_screen_on.dart';
import 'package:xxread/core/reader/reader_settings.dart';
import 'package:xxread/core/reader/reader_system_ui.dart';
import 'package:xxread/l10n/app_localizations.dart';
import 'package:xxread/main.dart';
import 'package:xxread/pages/book_sources/book_source_management_page.dart';
import 'package:xxread/pages/home/home_mobile_chrome.dart';
import 'package:xxread/pages/home/home_shell_page.dart';
import 'package:xxread/pages/settings/about/changelog_page.dart';
import 'package:xxread/pages/settings/about/open_source_licenses_page.dart';
import 'package:xxread/pages/settings/cache_management_page.dart';
import 'package:xxread/pages/settings/floating_navigation_settings_page.dart';
import 'package:xxread/pages/settings/library_layout_settings_page.dart';
import 'package:xxread/pages/settings/sync/webdav_sync_page.dart';
import 'package:xxread/reader_core/ai/ai_service.dart';
import 'package:xxread/services/core/core_services.dart';
import 'package:xxread/services/core/online_font_models.dart';
import 'package:xxread/services/sync/sync_models.dart';
import 'package:xxread/services/sync/webdav_sync_controller.dart';
import 'package:xxread/utils/app_themes.dart';
import 'package:xxread/utils/app_themes_translator.dart';
import 'package:xxread/utils/font_catalog_helper.dart';
import 'package:xxread/utils/localization_extension.dart';
import 'package:xxread/utils/page_style_helper.dart';
import 'package:xxread/utils/reader_themes.dart';
import 'package:xxread/utils/system_ui_helper.dart';
import 'package:xxread/utils/ui_style.dart';
import 'package:xxread/widgets/app_brand_icon.dart';
import 'package:xxread/widgets/accent_color_picker_sheet.dart';
import 'package:xxread/widgets/contributors_view.dart';
import 'package:xxread/widgets/developer_support_card.dart';
import 'package:xxread/widgets/reader_settings_controls.dart';
import 'package:xxread/widgets/side_toast.dart';
import 'package:xxread/widgets/update_check_gate.dart';

import 'custom_fonts_page.dart';

part 'parts/settings_cover_actions_part.dart';

class _GithubMark extends StatelessWidget {
  const _GithubMark();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _GithubMarkPainter());
  }
}

class _GithubMarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white;
    canvas.save();
    canvas.scale(size.width / 24, size.height / 24);

    final mark = Path()
      ..moveTo(6.1, 7.2)
      ..lineTo(5.1, 3.1)
      ..quadraticBezierTo(8.2, 3.2, 10.1, 4.8)
      ..quadraticBezierTo(12, 4.35, 13.9, 4.8)
      ..quadraticBezierTo(15.8, 3.2, 18.9, 3.1)
      ..lineTo(17.9, 7.2)
      ..quadraticBezierTo(19.6, 9.0, 19.6, 11.8)
      ..quadraticBezierTo(19.6, 16.7, 15.8, 18.2)
      ..quadraticBezierTo(14.9, 18.55, 14.9, 20.0)
      ..lineTo(14.9, 22.0)
      ..lineTo(9.1, 22.0)
      ..lineTo(9.1, 20.3)
      ..quadraticBezierTo(7.5, 20.65, 6.7, 19.5)
      ..quadraticBezierTo(6.0, 18.45, 5.0, 17.75)
      ..quadraticBezierTo(4.4, 17.3, 4.7, 16.9)
      ..quadraticBezierTo(5.0, 16.55, 5.7, 17.0)
      ..quadraticBezierTo(6.9, 17.75, 7.4, 18.35)
      ..quadraticBezierTo(8.0, 19.0, 9.1, 18.7)
      ..quadraticBezierTo(9.15, 18.0, 9.55, 17.55)
      ..quadraticBezierTo(4.4, 16.95, 4.4, 11.8)
      ..quadraticBezierTo(4.4, 9.0, 6.1, 7.2)
      ..close();
    canvas.drawPath(mark, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _QqMark extends StatelessWidget {
  const _QqMark();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _QqMarkPainter());
  }
}

class _QqMarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final white = Paint()..color = Colors.white;
    final blue = Paint()..color = const Color(0xFF1677FF);
    canvas.save();
    canvas.scale(size.width / 24, size.height / 24);

    canvas.drawOval(const Rect.fromLTWH(6.6, 2.2, 10.8, 17.8), white);
    canvas.drawOval(const Rect.fromLTWH(4.2, 9.0, 4.6, 8.3), white);
    canvas.drawOval(const Rect.fromLTWH(15.2, 9.0, 4.6, 8.3), white);
    canvas.drawOval(const Rect.fromLTWH(5.0, 18.0, 6.8, 3.2), white);
    canvas.drawOval(const Rect.fromLTWH(12.2, 18.0, 6.8, 3.2), white);
    canvas.drawOval(const Rect.fromLTWH(8.8, 6.2, 2.1, 2.8), blue);
    canvas.drawOval(const Rect.fromLTWH(13.1, 6.2, 2.1, 2.8), blue);
    canvas.drawOval(const Rect.fromLTWH(10.3, 9.1, 3.4, 2.0), blue);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(6.0, 13.1, 12.0, 2.25),
        const Radius.circular(1.1),
      ),
      blue,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class SettingsPageController extends ChangeNotifier {
  int _supportRevealRequest = 0;

  int get supportRevealRequest => _supportRevealRequest;

  void revealSupportSection() {
    _supportRevealRequest += 1;
    notifyListeners();
  }
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, this.controller, this.cacheManager});

  final SettingsPageController? controller;
  final AppCacheManager? cacheManager;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  static const _aiQuickModelsKey = 'reader_ai_quick_models_v1';
  static const _activeAiQuickModelKey = 'reader_ai_active_quick_model_v1';

  final ReaderHttpAIService _aiService = ReaderHttpAIService();
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _supportSectionKey = GlobalKey();
  late final AppCacheManager _cacheManager;
  late final TextEditingController _aiApiKeyController;
  late final TextEditingController _aiModelController;
  late final TextEditingController _aiBaseUrlController;
  late final TextEditingController _aiTempController;

  bool _enableAutoSave = true;
  bool _keepScreenOn = false;
  int _autoSaveInterval = 30;

  // 阅读设置
  bool _enableVolumeKeyTurn = true;
  ReaderTopBarStyle _readerTopBarStyle = ReaderTopBarStyle.reader;

  bool _enableAutoExtractCover = true;

  // 其他设置
  bool _enableFullscreen = false;

  // 开发者设置
  bool _enableDeveloperMode = false;
  bool _enableDebugLogging = false;
  bool _enablePerformanceMonitor = false;
  bool _enableMemoryStats = false;
  bool _showFPS = false;
  String _appVersion = '0.9.1';
  bool _isCheckingForUpdates = false;
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
  int _lastSupportRevealRequest = 0;
  AppCacheUsage? _cacheUsage;
  bool _loadingCacheUsage = true;

  @override
  void initState() {
    super.initState();
    _aiApiKeyController = TextEditingController();
    _aiModelController = TextEditingController();
    _aiBaseUrlController = TextEditingController();
    _aiTempController = TextEditingController();
    _cacheManager = widget.cacheManager ?? AppCacheManager();
    unawaited(_loadAppVersion());
    unawaited(_refreshCacheUsage());
    _loadSettings();
    _attachSettingsController(widget.controller);
    // 状态栏设置现在由_SettingsPageWrapper处理
  }

  @override
  void didUpdateWidget(covariant SettingsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller == widget.controller) return;
    oldWidget.controller?.removeListener(_handleSupportRevealRequest);
    _attachSettingsController(widget.controller);
  }

  void _attachSettingsController(SettingsPageController? controller) {
    _lastSupportRevealRequest = controller?.supportRevealRequest ?? 0;
    controller?.addListener(_handleSupportRevealRequest);
    if (_lastSupportRevealRequest > 0) {
      _scheduleSupportSectionReveal();
    }
  }

  void _handleSupportRevealRequest() {
    final request = widget.controller?.supportRevealRequest ?? 0;
    if (request == _lastSupportRevealRequest) return;
    _lastSupportRevealRequest = request;
    _scheduleSupportSectionReveal();
  }

  void _scheduleSupportSectionReveal() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final sectionContext = _supportSectionKey.currentContext;
      if (sectionContext == null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _revealSupportSection();
        });
        return;
      }
      _revealSupportSection();
    });
  }

  void _revealSupportSection() {
    final sectionContext = _supportSectionKey.currentContext;
    if (sectionContext == null) return;
    unawaited(
      Scrollable.ensureVisible(
        sectionContext,
        alignment: 0.12,
        duration: const Duration(milliseconds: 620),
        curve: Curves.easeInOutCubic,
      ),
    );
  }

  @override
  void dispose() {
    widget.controller?.removeListener(_handleSupportRevealRequest);
    _scrollController.dispose();
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
    final readerTopBarStyle = await ReaderSystemUiController.loadPreference();
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
      _keepScreenOn =
          prefs.getBool(ReaderKeepScreenOnController.preferenceKey) ?? false;
      _autoSaveInterval = prefs.getInt('autoSaveInterval') ?? 30;

      _enableAutoExtractCover = prefs.getBool('enableAutoExtractCover') ?? true;

      _enableVolumeKeyTurn = prefs.getBool('enableVolumeKeyTurn') ?? true;
      _readerTopBarStyle = readerTopBarStyle;
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
                (item) =>
                    _AiQuickModel.fromJson(Map<String, dynamic>.from(item)),
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
      final sameEndpoint =
          providerSettings != null &&
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
      await prefs.setString(_activeAiQuickModelKey, _activeAiQuickModelId!);
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
            : '0.9.1';
      });
    } catch (_) {
      // Keep default version fallback.
    }
  }

  Future<void> _refreshCacheUsage() async {
    try {
      final usage = await _cacheManager.usage();
      if (!mounted) return;
      setState(() {
        _cacheUsage = usage;
        _loadingCacheUsage = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingCacheUsage = false);
    }
  }

  Future<void> _openCacheManagement() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CacheManagementPage(cacheManager: _cacheManager),
      ),
    );
    if (mounted) await _refreshCacheUsage();
  }

  Future<void> _saveSettings() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('enableAnimations', true);
    await prefs.setBool('enableAutoSave', _enableAutoSave);
    await prefs.setInt('autoSaveInterval', _autoSaveInterval);

    await prefs.setBool('enableAutoExtractCover', _enableAutoExtractCover);

    await prefs.setBool('enableVolumeKeyTurn', _enableVolumeKeyTurn);
    await ReaderSystemUiController.savePreference(_readerTopBarStyle);
    // 其他设置
    await prefs.setBool('enableFullscreen', _enableFullscreen);

    // 开发者设置
    await prefs.setBool('enableDeveloperMode', _enableDeveloperMode);
    await prefs.setBool('enableDebugLogging', _enableDebugLogging);
    await prefs.setBool('enablePerformanceMonitor', _enablePerformanceMonitor);
    await prefs.setBool('enableMemoryStats', _enableMemoryStats);
    await prefs.setBool('showFPS', _showFPS);
  }

  void _setKeepScreenOn(bool value) {
    setState(() => _keepScreenOn = value);
    unawaited(ReaderKeepScreenOnController.setPreference(value));
  }

  String _readerTopBarStyleTitle(ReaderTopBarStyle style) => switch (style) {
    ReaderTopBarStyle.system => context.l10n.readerTopBarStyleSystem,
    ReaderTopBarStyle.reader => context.l10n.readerTopBarStyleReader,
    ReaderTopBarStyle.hidden => context.l10n.readerTopBarStyleHidden,
  };

  String _readerTopBarStyleHint(ReaderTopBarStyle style) => switch (style) {
    ReaderTopBarStyle.system => context.l10n.readerTopBarStyleSystemHint,
    ReaderTopBarStyle.reader => context.l10n.readerTopBarStyleReaderHint,
    ReaderTopBarStyle.hidden => context.l10n.readerTopBarStyleHiddenHint,
  };

  Future<void> _showReaderTopBarStylePicker() async {
    final prefs = await SharedPreferences.getInstance();
    final palette = ReaderThemes.byId(
      prefs.getString(ReaderSettingsStore.themeKey) ??
          ReaderSettings.defaultThemeId,
    );
    if (!mounted) return;
    final selected = await showModalBottomSheet<ReaderTopBarStyle>(
      context: context,
      backgroundColor: palette.surface,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => ReaderTopBarStyleSheet(
        palette: palette,
        title: context.l10n.readerTopBarStyleTitle,
        selectedStyle: _readerTopBarStyle,
        titleFor: _readerTopBarStyleTitle,
        hintFor: _readerTopBarStyleHint,
        onSelected: (style) => Navigator.of(sheetContext).pop(style),
      ),
    );
    if (selected == null || !mounted) return;
    setState(() => _readerTopBarStyle = selected);
    await ReaderSystemUiController.savePreference(selected);
  }

  void _applyAiDraft(AIProviderSettings settings) {
    final normalized = settings.normalized();
    _aiApiKeyController.text = normalized.apiKey;
    _aiModelController.text = normalized.model;
    _aiBaseUrlController.text = normalized.baseUrl;
    _aiTempController.text = normalized.temperature.toStringAsFixed(2);
    _selectedAiPreset =
        AIModelPresets.match(normalized) ??
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
    _aiDraftByProvider[_selectedAiProvider] = _buildAiDraftFromInputs(
      _selectedAiProvider,
    );
  }

  void _onAiProviderChanged(AIProviderType provider) {
    _stashCurrentAiDraft();
    final nextDraft =
        _aiDraftByProvider[provider] ??
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
    final current =
        (_aiDraftByProvider[_selectedAiProvider] ??
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
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.68),
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
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.62),
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
                    final parsedTemp = double.tryParse(
                      tempController.text.trim(),
                    );
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

                    Navigator.of(dialogContext).pop(nextSettings);
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
    showSideToast(
      context,
      l10n.settingsAiCustomApplied,
      kind: SideToastKind.success,
    );
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
      showSideToast(
        context,
        context.l10n.settingsAiSettingsSaved,
        kind: SideToastKind.success,
      );
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
    final webDavSync = Provider.of<WebDavSyncController>(context);
    final useRailNavigation =
        NavigationContext.of(context)?.useRailNavigation ?? false;
    final mobileChrome = HomeMobileChromeScope.of(context);
    final viewPadding = MediaQuery.viewPaddingOf(context);
    return Container(
      decoration: BoxDecoration(
        gradient: PageStyleHelper.backgroundGradient(context),
      ),
      child: ListView(
        controller: _scrollController,
        padding: EdgeInsets.fromLTRB(
          16,
          useRailNavigation ? viewPadding.top + 8 : mobileChrome.pageTopPadding,
          16,
          useRailNavigation
              ? viewPadding.bottom + 24
              : mobileChrome.pageBottomPadding,
        ),
        children: [
          if (useRailNavigation) ...[
            _buildSettingsTopRow(l10n, useRailNavigation),
            const SizedBox(height: 24),
          ],
          _buildSectionCard(
            title: l10n.appearanceSettings,
            icon: Icons.palette_outlined,
            children: [
              _buildUiStyleSelector(themeNotifier),
              _buildThemeToggle(themeNotifier),
              _buildAccentColorSelector(themeNotifier),
              _buildActionSetting(
                title: l10n.settingsLibraryLayoutTitle,
                subtitle: l10n.settingsCurrentValue(
                  appSettings.libraryLayoutMode == LibraryLayoutMode.card
                      ? l10n.settingsLibraryLayoutCard
                      : l10n.settingsLibraryLayoutGrid,
                ),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const LibraryLayoutSettingsPage(),
                  ),
                ),
                icon: Icons.view_module_outlined,
              ),
              _buildActionSetting(
                title: l10n.settingsFloatingNavigationTitle,
                subtitle: l10n.settingsFloatingNavigationSubtitle,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const FloatingNavigationSettingsPage(),
                  ),
                ),
                icon: Icons.dock_outlined,
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildSectionCard(
            title: l10n.typographySettings,
            icon: Icons.text_fields_rounded,
            children: [
              _buildAppFontSelector(appSettings),
              _buildReaderFontSelector(appSettings),
              _buildCustomFontsManager(appSettings),
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
              _buildActionSetting(
                title: l10n.readerTopBarStyleTitle,
                subtitle: _readerTopBarStyleTitle(_readerTopBarStyle),
                onTap: _showReaderTopBarStylePicker,
                icon: Icons.vertical_align_top_rounded,
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildSectionCard(
            title: l10n.settingsContentSourcesTitle,
            icon: Icons.hub_outlined,
            children: [
              _buildActionSetting(
                title: l10n.bookSourceManagementTitle,
                subtitle: l10n.settingsContentSourcesSubtitle,
                onTap: _openBookSourceManagement,
                icon: Icons.travel_explore_outlined,
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildSectionCard(
            title: l10n.settingsDataSyncTitle,
            icon: Icons.cloud_sync_outlined,
            children: [
              _buildActionSetting(
                title: l10n.settingsWebDavSyncTitle,
                badge: l10n.webDavBetaBadge,
                subtitle: _webDavSyncSubtitle(webDavSync),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const WebDavSyncPage(),
                  ),
                ),
                icon: Icons.cloud_outlined,
                trailing: _webDavSyncTrailing(webDavSync),
              ),
              _buildActionSetting(
                title: l10n.settingsCacheManagementTitle,
                subtitle: l10n.settingsCacheManagementSubtitle(
                  _loadingCacheUsage
                      ? l10n.settingsCacheCalculating
                      : AppCacheManager.formatBytes(
                          _cacheUsage?.totalBytes ?? 0,
                        ),
                ),
                onTap: () => unawaited(_openCacheManagement()),
                icon: Icons.cleaning_services_outlined,
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildSectionCard(
            title: l10n.settingsAiAssistantTitle,
            icon: Icons.auto_awesome_outlined,
            children: [_buildAiSettingsSection()],
          ),
          const SizedBox(height: 20),
          _buildSectionCard(
            title: l10n.appSettings,
            icon: Icons.language,
            children: [_buildLanguageSelector(appSettings)],
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
                onChanged: _setKeepScreenOn,
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
          KeyedSubtree(
            key: _supportSectionKey,
            child: _buildSectionCard(
              title: l10n.settingsSupportDevelopmentTitle,
              icon: Icons.volunteer_activism_outlined,
              children: [
                DeveloperSupportCard(
                  onWechatTap: () =>
                      _showDonationDialog(DeveloperDonationMethod.wechat),
                  onAlipayTap: () =>
                      _showDonationDialog(DeveloperDonationMethod.alipay),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _buildAboutCard(),
          const SizedBox(height: 20),
          const ContributorsView(
            repositoryOwner: 'miloquinn',
            repositoryName: 'open-reading',
          ),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  String _webDavSyncSubtitle(WebDavSyncController sync) {
    final l10n = context.l10n;
    if (!sync.isConfigured) return l10n.webDavConfigureSubtitle;
    if (sync.status == WebDavSyncStatus.syncing ||
        sync.status == WebDavSyncStatus.testing) {
      return l10n.webDavSyncing;
    }
    if (sync.status == WebDavSyncStatus.failed) {
      return l10n.webDavSyncFailed;
    }
    if (sync.status == WebDavSyncStatus.partialFailure) {
      return l10n.webDavPartialFailure;
    }
    if (sync.pendingChanges > 0) {
      return l10n.webDavPendingChanges(sync.pendingChanges);
    }
    final lastSuccess = sync.lastSuccessfulSync;
    if (lastSuccess == null) return l10n.webDavNeverSynced;
    final local = lastSuccess.toLocal();
    final material = MaterialLocalizations.of(context);
    final date = material.formatShortDate(local);
    final time = material.formatTimeOfDay(TimeOfDay.fromDateTime(local));
    return l10n.webDavLastSync('$date $time');
  }

  Widget _webDavSyncTrailing(WebDavSyncController sync) {
    if (sync.status == WebDavSyncStatus.syncing ||
        sync.status == WebDavSyncStatus.testing) {
      return const SizedBox.square(
        dimension: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    if (sync.status == WebDavSyncStatus.failed ||
        sync.status == WebDavSyncStatus.partialFailure) {
      return Icon(
        Icons.error_outline_rounded,
        color: Theme.of(context).colorScheme.error,
      );
    }
    return const Icon(Icons.chevron_right_rounded);
  }

  void _openBookSourceManagement() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const BookSourceManagementPage()),
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
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
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
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 9),
            child: Row(
              children: [
                Icon(
                  Icons.swipe_rounded,
                  size: 15,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    l10n.settingsAiSwipeHint,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      height: 1.2,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 112,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              physics: const BouncingScrollPhysics(),
              itemCount: _aiQuickModels.length + 1,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
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
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final selected = item.id == _activeAiQuickModelId;
    final configured = item.settings.isConfigured;
    return SizedBox(
      width: 172,
      child: Material(
        color: selected
            ? Color.alphaBlend(
                scheme.primary.withValues(alpha: 0.09),
                scheme.surfaceContainerLow,
              )
            : scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _activateAiQuickModel(item),
          onLongPress: item.isCustom ? () => _removeAiQuickModel(item) : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.fromLTRB(12, 11, 12, 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected ? scheme.primary : scheme.outlineVariant,
                width: selected ? 1.4 : 1,
              ),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: scheme.primary.withValues(alpha: 0.12),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: selected
                            ? scheme.primary.withValues(alpha: 0.11)
                            : scheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.auto_awesome_rounded,
                            size: 11,
                            color: selected
                                ? scheme.primary
                                : scheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            item.settings.provider.displayName,
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: selected
                                      ? scheme.primary
                                      : scheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w700,
                                  height: 1.1,
                                ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 160),
                      child: selected
                          ? Icon(
                              Icons.check_circle_rounded,
                              key: const ValueKey('selected'),
                              size: 18,
                              color: scheme.primary,
                            )
                          : const SizedBox.square(
                              key: ValueKey('not-selected'),
                              dimension: 18,
                            ),
                    ),
                  ],
                ),
                const Spacer(),
                Text(
                  item.settings.model,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 7),
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: configured ? scheme.primary : scheme.error,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        configured
                            ? l10n.settingsAiApiKeyConfigured
                            : l10n.settingsAiApiKeyTapToConfigure,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: configured
                              ? scheme.onSurfaceVariant
                              : scheme.error,
                          fontSize: 11,
                          height: 1.1,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAddAiModelCard() {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 94,
      child: Material(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _showAiModelSheet(),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.add_rounded,
                    size: 21,
                    color: scheme.primary,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  l10n.settingsAiAddModel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
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
        showSideToast(
          context,
          context.l10n.settingsAiSwitchedToModel(item.settings.model),
          kind: SideToastKind.success,
        );
      }
    } catch (error) {
      if (mounted) {
        showSideToast(context, '$error', kind: SideToastKind.error);
      }
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
    final initial =
        editing?.settings ??
        AIModelPresets.defaultForProvider(_selectedAiProvider).toSettings(
          apiKey: _aiDraftByProvider[_selectedAiProvider]?.apiKey ?? '',
        );
    var provider = initial.provider;
    var customMode = editing?.isCustom ?? false;
    var selectedPreset =
        AIModelPresets.match(initial) ??
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
          final l10n = context.l10n;
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
                errorText = l10n.settingsAiFillBaseUrlAndApiKey;
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
            final temperature = double.tryParse(
              temperatureController.text.trim(),
            );
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
                                  editing == null
                                      ? l10n.settingsAiAddModel
                                      : l10n.settingsAiEditModelTitle,
                                  style: Theme.of(sheetContext)
                                      .textTheme
                                      .titleLarge
                                      ?.copyWith(fontWeight: FontWeight.w800),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  l10n.settingsAiQuickCardSubtitle,
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
                            segments: [
                              ButtonSegment(
                                value: false,
                                label: Text(l10n.settingsAiPresetModel),
                                icon: const Icon(Icons.auto_awesome_outlined),
                              ),
                              ButtonSegment(
                                value: true,
                                label: Text(l10n.settingsAiCustomButton),
                                icon: const Icon(Icons.tune_rounded),
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
                            decoration: InputDecoration(
                              labelText: l10n.settingsAiProviderLabel,
                              prefixIcon: const Icon(Icons.hub_outlined),
                              border: const OutlineInputBorder(),
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
                              decoration: InputDecoration(
                                labelText: l10n.settingsAiPresetModel,
                                prefixIcon: const Icon(Icons.memory_rounded),
                                border: const OutlineInputBorder(),
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
                            decoration: InputDecoration(
                              labelText: l10n.settingsAiBaseUrlLabel,
                              prefixIcon: const Icon(Icons.link_rounded),
                              border: const OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: apiKeyController,
                            obscureText: _obscureAiApiKey,
                            decoration: InputDecoration(
                              labelText: l10n.settingsAiApiKeyLabel,
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
                              labelText: l10n.settingsAiModelNameLabel,
                              prefixIcon: const Icon(Icons.smart_toy_outlined),
                              border: const OutlineInputBorder(),
                              suffixIcon: customMode
                                  ? IconButton(
                                      tooltip:
                                          l10n.settingsAiFetchModelsTooltip,
                                      onPressed: loadingModels
                                          ? null
                                          : fetchModels,
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
                                label: Text(l10n.settingsAiFetchModelsList),
                              ),
                            ),
                          ],
                          if (fetchedModels.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              l10n.settingsAiSelectModel,
                              style: Theme.of(sheetContext).textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              constraints: const BoxConstraints(maxHeight: 220),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: scheme.outlineVariant,
                                ),
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
                              decoration: InputDecoration(
                                labelText: l10n.settingsAiTemperatureLabel,
                                prefixIcon: const Icon(
                                  Icons.thermostat_rounded,
                                ),
                                border: const OutlineInputBorder(),
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
                          label: Text(
                            editing == null
                                ? l10n.settingsAiAddAndEnable
                                : l10n.settingsAiSaveAndEnable,
                          ),
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
      final existingIndex = _aiQuickModels.indexWhere(
        (item) => item.id == result.id,
      );
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
    final l10n = context.l10n;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (routeContext) => StatefulBuilder(
          builder: (routeContext, setRouteState) => Scaffold(
            appBar: AppBar(
              title: Text(l10n.settingsAiAssistantTitle),
              scrolledUnderElevation: 0,
            ),
            body: SafeArea(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                children: [
                  Text(
                    l10n.settingsAiLegacyIntro,
                    style: Theme.of(routeContext).textTheme.bodyMedium
                        ?.copyWith(
                          color: Theme.of(
                            routeContext,
                          ).colorScheme.onSurfaceVariant,
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
    final currentSettings =
        (_aiDraftByProvider[_selectedAiProvider] ??
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
            labelText: l10n.settingsAiProviderLabel,
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
            labelText: l10n.settingsAiModelLabel,
            prefixIcon: const Icon(Icons.memory_rounded),
            border: const OutlineInputBorder(),
            helperText: matchedPreset == null
                ? l10n.settingsAiUsingCustomParams
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
            labelText: l10n.settingsAiApiKeyLabel,
            hintText: l10n.settingsAiApiKeyStoredLocally,
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
              Icon(
                Icons.error_outline_rounded,
                size: 17,
                color: colorScheme.error,
              ),
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
                : l10n.settingsAiSaveAndEnable,
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
    final l10n = context.l10n;
    return _buildSwitchSetting(
      title: l10n.settingsUiStyleTitle,
      subtitle: l10n.settingsGlassEffectSubtitle,
      value: themeNotifier.isGlassEffectsEnabled,
      onChanged: themeNotifier.setGlassEffectsEnabled,
      icon: Icons.blur_on_rounded,
    );
  }

  Widget _buildAccentColorSelector(ThemeNotifier themeNotifier) {
    final l10n = context.l10n;
    final accentColor = themeNotifier.accentColor;
    final colorName = accentColorDisplayName(
      context,
      AppThemes.getAccentColorName(accentColor),
    );
    final subtitle = '$colorName · ${_hexColor(accentColor)}';

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
                    color: Theme.of(
                      modalContext,
                    ).colorScheme.onSurface.withValues(alpha: 0.3),
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
                                  : Theme.of(modalContext).colorScheme.outline
                                        .withValues(alpha: 0.35),
                              width: selected ? 1.6 : 1,
                            ),
                            color: selected
                                ? Theme.of(
                                    modalContext,
                                  ).colorScheme.primary.withValues(alpha: 0.08)
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
                                  color: Theme.of(
                                    modalContext,
                                  ).colorScheme.primary,
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

  Widget _buildAppFontSelector(AppSettingsNotifier appSettings) {
    final l10n = context.l10n;
    final selected = appSettings.appFont;
    return _buildActionSetting(
      title: l10n.appFont,
      subtitle:
          '${FontCatalog.labelFor(l10n, selected)} · ${l10n.appFontDescription}',
      icon: Icons.font_download_outlined,
      onTap: () => _showFontModal(
        appSettings: appSettings,
        domain: FontDomain.app,
        title: l10n.appFont,
        description: l10n.appFontDescription,
      ),
    );
  }

  Widget _buildReaderFontSelector(AppSettingsNotifier appSettings) {
    final l10n = context.l10n;
    final selected = appSettings.readerFont;
    return _buildActionSetting(
      title: l10n.readerFont,
      subtitle:
          '${FontCatalog.labelFor(l10n, selected)} · ${l10n.readerFontDescription}',
      icon: Icons.chrome_reader_mode_outlined,
      onTap: () => _showFontModal(
        appSettings: appSettings,
        domain: FontDomain.reader,
        title: l10n.readerFont,
        description: l10n.readerFontDescription,
      ),
    );
  }

  Widget _buildCustomFontsManager(AppSettingsNotifier appSettings) {
    final l10n = context.l10n;
    return _buildActionSetting(
      title: l10n.customFonts,
      subtitle: appSettings.customFonts.isEmpty
          ? l10n.customFontsEmpty
          : l10n.customFontsCount(appSettings.customFonts.length),
      icon: Icons.folder_copy_outlined,
      onTap: () => Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => const CustomFontsPage())),
    );
  }

  Future<void> _showFontModal({
    required AppSettingsNotifier appSettings,
    required FontDomain domain,
    required String title,
    required String description,
  }) async {
    final l10n = context.l10n;
    await appSettings.prepareCustomFontPreviews();
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) {
        return ListenableBuilder(
          listenable: appSettings,
          builder: (context, _) {
            var importing = false;
            return StatefulBuilder(
              builder: (context, setModalState) {
                final allBuiltIn = domain == FontDomain.app
                    ? FontCatalog.appFonts
                    : FontCatalog.readerFonts;
                final systemOptions = allBuiltIn
                    .where((option) => !option.isOnline)
                    .toList(growable: false);
                final onlineOptions = allBuiltIn
                    .where((option) => option.isOnline)
                    .toList(growable: false);
                final customOptions = appSettings.availableCustomFonts;
                final selectedId = domain == FontDomain.app
                    ? appSettings.appFontId
                    : appSettings.readerFontId;
                final colorScheme = Theme.of(context).colorScheme;

                Future<void> importFont() async {
                  setModalState(() => importing = true);
                  try {
                    final result = await appSettings.importCustomFont(domain);
                    if (result.status == CustomFontImportStatus.cancelled) {
                      if (modalContext.mounted) {
                        setModalState(() => importing = false);
                      }
                      return;
                    }
                    if (modalContext.mounted) {
                      Navigator.of(modalContext).pop();
                    }
                    if (mounted) {
                      final message =
                          result.status == CustomFontImportStatus.duplicate
                          ? l10n.customFontAlreadyImported
                          : domain == FontDomain.app
                          ? l10n.customFontAppliedToApp
                          : l10n.customFontAppliedToReader;
                      showSideToast(
                        this.context,
                        message,
                        kind: SideToastKind.success,
                      );
                    }
                  } on CustomFontException catch (error) {
                    if (modalContext.mounted) {
                      setModalState(() => importing = false);
                      showSideToast(
                        modalContext,
                        _customFontErrorText(l10n, error),
                        kind: SideToastKind.error,
                      );
                    }
                  }
                }

                Future<void> selectFont(String id) async {
                  if (domain == FontDomain.app) {
                    await appSettings.setAppFontId(id);
                  } else {
                    await appSettings.setReaderFontId(id);
                  }
                  if (modalContext.mounted) {
                    Navigator.of(modalContext).pop();
                  }
                }

                return Container(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.sizeOf(context).height * 0.86,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(28),
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
                            color: colorScheme.onSurface.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(24, 2, 24, 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.text_fields_rounded,
                                    color: colorScheme.primary,
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    title,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge
                                        ?.copyWith(fontWeight: FontWeight.w700),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                description,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                      height: 1.45,
                                    ),
                              ),
                              const SizedBox(height: 14),
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton.tonalIcon(
                                  onPressed:
                                      importing ||
                                          !appSettings.customFontImportSupported
                                      ? null
                                      : importFont,
                                  icon: importing
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(Icons.add_rounded),
                                  label: Text(
                                    importing
                                        ? l10n.importingFont
                                        : l10n.importFont,
                                  ),
                                ),
                              ),
                              if (!appSettings.customFontImportSupported) ...[
                                const SizedBox(height: 6),
                                Text(
                                  l10n.customFontImportUnsupported,
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        Flexible(
                          child: ListView(
                            shrinkWrap: true,
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            children: [
                              _fontSectionLabel(context, l10n.builtInFonts),
                              ...systemOptions.map(
                                (option) => _fontOptionCard(
                                  context: context,
                                  appSettings: appSettings,
                                  domain: domain,
                                  option: option,
                                  selected: option.id == selectedId,
                                  onTap: () => selectFont(option.id),
                                ),
                              ),
                              ListenableBuilder(
                                listenable:
                                    appSettings.onlineFontProgressListenable,
                                builder: (context, _) => Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    _fontSectionLabel(
                                      context,
                                      l10n.onlineFonts,
                                    ),
                                    ...onlineOptions.map(
                                      (option) => _fontOptionCard(
                                        context: context,
                                        appSettings: appSettings,
                                        domain: domain,
                                        option: option,
                                        selected:
                                            option.id ==
                                            (domain == FontDomain.app
                                                ? appSettings.appFontId
                                                : appSettings.readerFontId),
                                        onTap: () => selectFont(option.id),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (customOptions.isNotEmpty) ...[
                                _fontSectionLabel(context, l10n.customFonts),
                                ...customOptions.map(
                                  (option) => _fontOptionCard(
                                    context: context,
                                    appSettings: appSettings,
                                    domain: domain,
                                    option: option,
                                    selected: option.id == selectedId,
                                    onTap: () => selectFont(option.id),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _fontSectionLabel(BuildContext context, String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 14, 8, 6),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _fontOptionCard({
    required BuildContext context,
    required AppSettingsNotifier appSettings,
    required FontDomain domain,
    required FontOption option,
    required bool selected,
    required Future<void> Function() onTap,
  }) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    final isOnline = option.isOnline;
    final isDownloaded =
        !isOnline || appSettings.isOnlineFontDownloaded(option.id);
    final progress = isOnline
        ? appSettings.onlineFontProgress(option.id)
        : null;
    final isDownloading =
        progress != null &&
        (progress.status == OnlineFontDownloadStatus.downloading ||
            progress.status == OnlineFontDownloadStatus.verifying ||
            progress.status == OnlineFontDownloadStatus.registering);
    final isFailed = progress?.status == OnlineFontDownloadStatus.failed;

    String description;
    if (option.isCustom) {
      description =
          '${option.sourceFileName} · ${_formatFileSize(option.fileSize ?? 0)}';
    } else if (isOnline && !isDownloaded && !isDownloading) {
      description =
          '${l10n.fontDownloadHint} · ${_formatFileSize(option.onlineTotalBytes)}';
    } else if (isOnline && isDownloading) {
      final percent = (progress.fraction * 100).round();
      description = '${l10n.fontDownloading} $percent%';
    } else if (isOnline && isFailed) {
      description = l10n.fontDownloadFailed;
    } else {
      description = FontCatalog.descriptionFor(l10n, option);
    }

    Future<void> handleTap() async {
      if (isOnline && !isDownloaded && !isDownloading) {
        // 未下载：触发下载（不关闭弹窗，下载进度会通过 notifyListeners 刷新 UI）
        await appSettings.downloadOnlineFont(option.id, domain: domain);
        return;
      }
      if (isOnline && isDownloading) {
        return; // 下载中禁用
      }
      // 系统字体 / 已下载在线字体 / 自定义字体：选中
      await onTap();
    }

    final showCheck = selected && (isDownloaded || option.isCustom);
    final showDownloadBadge = isOnline && !isDownloaded && !isDownloading;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: handleTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected
                    ? colorScheme.primary
                    : colorScheme.outline.withValues(alpha: 0.35),
                width: selected ? 1.6 : 1,
              ),
              color: selected
                  ? colorScheme.primary.withValues(alpha: 0.08)
                  : Colors.transparent,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        FontCatalog.labelFor(l10n, option),
                        style: TextStyle(
                          inherit: false,
                          fontFamily: option.family,
                          fontFamilyFallback: option.fallbackFamilies.isEmpty
                              ? null
                              : option.fallbackFamilies,
                          color: selected
                              ? colorScheme.primary
                              : colorScheme.onSurface,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (showDownloadBadge)
                      _downloadBadge(context, l10n.fontDownload),
                    if (isOnline && isDownloaded && !selected)
                      _downloadedBadge(context, l10n.fontDownloaded),
                    if (isFailed)
                      _failedBadge(context, l10n.fontDownloadFailed),
                    if (showCheck)
                      Icon(Icons.check_circle, color: colorScheme.primary),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
                if (isOnline && isDownloading) ...[
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress.fraction,
                      minHeight: 4,
                      backgroundColor: colorScheme.outline.withValues(
                        alpha: 0.2,
                      ),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        colorScheme.primary,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 7),
                Text(
                  l10n.fontPreviewText,
                  style: TextStyle(
                    inherit: false,
                    fontFamily: option.family,
                    fontFamilyFallback: option.fallbackFamilies.isEmpty
                        ? null
                        : option.fallbackFamilies,
                    color: colorScheme.onSurface,
                    fontSize: 15,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _downloadBadge(BuildContext context, String label) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: colorScheme.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: colorScheme.primary.withValues(alpha: 0.4),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.cloud_download_outlined,
            size: 14,
            color: colorScheme.primary,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: colorScheme.primary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _downloadedBadge(BuildContext context, String label) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: colorScheme.tertiary.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_rounded, size: 12, color: colorScheme.tertiary),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              color: colorScheme.tertiary,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _failedBadge(BuildContext context, String label) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: colorScheme.error.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, size: 12, color: colorScheme.error),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              color: colorScheme.error,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / 1024).toStringAsFixed(0)} KB';
  }

  String _customFontErrorText(
    AppLocalizations l10n,
    CustomFontException error,
  ) {
    switch (error.code) {
      case CustomFontErrorCode.unsupported:
        return l10n.customFontImportUnsupported;
      case CustomFontErrorCode.unsupportedFormat:
        return l10n.customFontUnsupportedFormat;
      case CustomFontErrorCode.invalidFont:
        return l10n.customFontInvalid;
      case CustomFontErrorCode.fileTooLarge:
        return l10n.customFontTooLarge;
      case CustomFontErrorCode.readFailed:
        return l10n.customFontReadFailed;
      case CustomFontErrorCode.loadFailed:
        return l10n.customFontLoadFailed;
      case CustomFontErrorCode.storageFailed:
        return l10n.customFontStorageFailed;
    }
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
      case 'zh-TW':
      case 'zh_TW':
      case 'zh-Hant':
      case 'zh_Hant':
        return l10n.languageTraditionalChinese;
      case 'ja':
      case 'ja-JP':
      case 'ja_JP':
        return l10n.languageJapanese;
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
      _LanguageOption(code: 'zh-TW', label: l10n.languageTraditionalChinese),
      _LanguageOption(code: 'en', label: l10n.languageEnglish),
      _LanguageOption(code: 'ja', label: l10n.languageJapanese),
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

  Future<void> _showAccentColorModal(ThemeNotifier themeNotifier) async {
    final selectedColor = await showModalBottomSheet<Color>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      enableDrag: true,
      showDragHandle: false,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          AccentColorPickerSheet(initialColor: themeNotifier.accentColor),
    );
    if (selectedColor == null || !mounted) return;
    await themeNotifier.setAccentColor(selectedColor);
  }

  Widget _buildSwitchSetting({
    required String title,
    required String subtitle,
    required bool value,
    required Function(bool) onChanged,
    required IconData icon,
    bool enabled = true,
    bool persistPageSettings = true,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 1),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled
              ? () {
                  onChanged(!value);
                  if (persistPageSettings) {
                    unawaited(_saveSettings());
                  }
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
                          if (persistPageSettings) {
                            unawaited(_saveSettings());
                          }
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
                border: Border.all(
                  color: scheme.primary.withValues(alpha: 0.22),
                ),
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
                      l10n.settingsAboutTagline,
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
          _buildAboutLine(l10n.settingsVersionLabel, _appVersion),
          _buildAboutLine(l10n.settingsLicenseLabel, 'AGPL-3.0'),
          const SizedBox(height: 8),
          _buildOpenSourceLicensesLink(),
          const SizedBox(height: 10),
          _buildChangelogLink(),
          const SizedBox(height: 14),
          _buildCommunityButton(
            onPressed: _checkForUpdates,
            backgroundColor: scheme.primary,
            foregroundColor: scheme.onPrimary,
            icon: _isCheckingForUpdates
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: scheme.onPrimary,
                    ),
                  )
                : const Icon(Icons.system_update_alt_rounded),
            title: l10n.updateCheckNow,
            subtitle: l10n.updateCheckNowSubtitle,
          ),
          const SizedBox(height: 10),
          _buildCommunityButton(
            onPressed: _openOfficialWebsite,
            backgroundColor: const Color(0xFF2D6A4F),
            foregroundColor: Colors.white,
            icon: const Icon(Icons.language_rounded),
            title: l10n.settingsOfficialWebsite,
            subtitle: l10n.settingsOfficialWebsiteSubtitle,
          ),
          const SizedBox(height: 10),
          _buildCommunityButton(
            onPressed: _openGithubRepo,
            backgroundColor: const Color(0xFF181717),
            foregroundColor: Colors.white,
            icon: const _GithubMark(),
            title: 'GitHub',
            subtitle: l10n.settingsViewSourceSubtitle,
          ),
          const SizedBox(height: 10),
          _buildCommunityButton(
            onPressed: _openTelegramChannel,
            backgroundColor: const Color(0xFF229ED9),
            foregroundColor: Colors.white,
            icon: const Icon(Icons.send_rounded),
            title: l10n.settingsTelegramChannel,
            subtitle: l10n.settingsTelegramSubtitle,
          ),
          const SizedBox(height: 10),
          _buildCommunityButton(
            onPressed: _openQqChannel,
            backgroundColor: const Color(0xFF12B7F5),
            foregroundColor: Colors.white,
            icon: const _QqMark(),
            title: l10n.settingsQqChannel,
            subtitle: l10n.settingsQqChannelSubtitle,
          ),
          const SizedBox(height: 10),
          _buildCommunityButton(
            onPressed: _openQqGroup,
            backgroundColor: const Color(0xFF1677FF),
            foregroundColor: Colors.white,
            icon: const _QqMark(),
            title: l10n.settingsJoinQqGroup,
            subtitle: '1003560209',
          ),
        ],
      ),
    );
  }

  Widget _buildChangelogLink() {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.58),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        key: const ValueKey('settings-changelog-link'),
        onTap: _openChangelogHistory,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.changelogHistoryTitle,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      l10n.changelogHistorySubtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOpenSourceLicensesLink() {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.58),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        key: const ValueKey('settings-open-source-licenses-link'),
        onTap: _openSourceLicenses,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.openSourceLicensesTitle,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      l10n.openSourceLicensesSubtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }

  void _openChangelogHistory() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const ChangelogPage()));
  }

  void _openSourceLicenses() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => OpenSourceLicensesPage(appVersion: _appVersion),
      ),
    );
  }

  Widget _buildCommunityButton({
    required VoidCallback onPressed,
    required Color backgroundColor,
    required Color foregroundColor,
    required Widget icon,
    required String title,
    required String subtitle,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: FilledButton(
        onPressed: onPressed,
        style:
            FilledButton.styleFrom(
              backgroundColor: backgroundColor,
              foregroundColor: foregroundColor,
              padding: const EdgeInsets.symmetric(horizontal: 18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              elevation: 0,
            ).copyWith(
              overlayColor: WidgetStatePropertyAll(
                foregroundColor.withValues(alpha: 0.12),
              ),
            ),
        child: Row(
          children: [
            SizedBox(width: 24, height: 24, child: icon),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.1,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                      color: foregroundColor.withValues(alpha: 0.72),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_outward_rounded,
              size: 19,
              color: foregroundColor.withValues(alpha: 0.78),
            ),
          ],
        ),
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
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
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
      showSideToast(
        context,
        context.l10n.settingsGithubOpenFailed,
        icon: Icons.error_outline,
        kind: SideToastKind.error,
      );
    }
  }

  Future<void> _openOfficialWebsite() async {
    final ok = await launchUrl(
      Uri.parse('https://open.xxread.top/'),
      mode: LaunchMode.externalApplication,
    );
    if (!ok && mounted) {
      showSideToast(
        context,
        context.l10n.settingsOfficialWebsiteOpenFailed,
        icon: Icons.error_outline,
        kind: SideToastKind.error,
      );
    }
  }

  void _showDonationDialog(DeveloperDonationMethod method) {
    showDialog<void>(
      context: context,
      builder: (_) => DeveloperDonationDialog(method: method),
    );
  }

  Future<void> _openTelegramChannel() async {
    final uri = Uri.parse('https://t.me/origoreading');
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      showSideToast(
        context,
        context.l10n.settingsTelegramOpenFailed,
        icon: Icons.error_outline,
        kind: SideToastKind.error,
      );
    }
  }

  Future<void> _openQqChannel() async {
    final uri = Uri.parse('https://pd.qq.com/s/diin97dya?b=9');
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      showSideToast(
        context,
        context.l10n.settingsQqChannelOpenFailed,
        icon: Icons.error_outline,
        kind: SideToastKind.error,
      );
    }
  }

  Future<void> _checkForUpdates() async {
    if (_isCheckingForUpdates) return;
    setState(() => _isCheckingForUpdates = true);
    await UpdatePromptController.check(context, manual: true);
    if (mounted) {
      setState(() => _isCheckingForUpdates = false);
    }
  }

  Future<void> _openQqGroup() async {
    final uri = Uri.parse(
      'mqqapi://card/show_pslcard?src_type=internal&version=1&uin=1003560209&card_type=group&source=qrcode',
    );
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      showSideToast(
        context,
        context.l10n.settingsQqOpenFailed,
        icon: Icons.error_outline,
        kind: SideToastKind.error,
      );
    }
  }

  // 构建操作设置
  Widget _buildActionSetting({
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required IconData icon,
    String? badge,
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
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            title,
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(fontWeight: FontWeight.w500),
                          ),
                          if (badge != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Theme.of(
                                  context,
                                ).colorScheme.secondaryContainer,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                badge,
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSecondaryContainer,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                            ),
                        ],
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

  const _LanguageOption({required this.code, required this.label});
}

String _hexColor(Color color) =>
    '#${color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
