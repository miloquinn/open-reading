// 文件说明：AI 阅读助手独立设置页，管理快捷模型卡片与 AI 预处理开关。
// 技术要点：Flutter UI、SharedPreferences、底部弹层表单。

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:xxread/reader_core/ai/ai_service.dart';
import 'package:xxread/services/ai/book_preprocess_service.dart';
import 'package:xxread/utils/localization_extension.dart';
import 'package:xxread/utils/page_style_helper.dart';
import 'package:xxread/widgets/side_toast.dart';

class AiSettingsPage extends StatefulWidget {
  const AiSettingsPage({super.key});

  @override
  State<AiSettingsPage> createState() => _AiSettingsPageState();
}

class _AiSettingsPageState extends State<AiSettingsPage> {
  static const _aiQuickModelsKey = 'reader_ai_quick_models_v1';
  static const _activeAiQuickModelKey = 'reader_ai_active_quick_model_v1';

  final ReaderHttpAIService _aiService = ReaderHttpAIService();

  final Map<AIProviderType, AIProviderSettings> _aiDraftByProvider =
      <AIProviderType, AIProviderSettings>{};
  AIProviderType _selectedAiProvider = AIProviderType.openai;
  List<_AiQuickModel> _aiQuickModels = const [];
  String? _activeAiQuickModelId;
  bool _aiSettingsLoaded = false;
  bool _aiPreprocessEnabled = false;
  bool _obscureAiApiKey = true;

  @override
  void initState() {
    super.initState();
    unawaited(_loadSettings());
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
    if (!mounted) return;
    setState(() {
      _aiDraftByProvider
        ..clear()
        ..addAll(aiSettingsByProvider);
      _selectedAiProvider = activeAiSettings.provider;
      _aiQuickModels = quickModels;
      _activeAiQuickModelId = activeQuickModelId;
      _aiPreprocessEnabled = prefs.getBool(aiPreprocessBooksPrefsKey) ?? false;
      _aiSettingsLoaded = true;
    });
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

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final palette = PageStyleHelper.palette(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsAiAssistantTitle)),
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: PageStyleHelper.backgroundGradient(context),
        ),
        child: !_aiSettingsLoaded
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                children: [
                  Text(
                    l10n.settingsAiQuickCardSubtitle,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildCard(
                    palette,
                    children: [
                      for (final item in _aiQuickModels) _buildAiModelRow(item),
                      _buildAddAiModelRow(),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _buildCard(palette, children: [_buildPreprocessSwitch()]),
                ],
              ),
      ),
    );
  }

  Widget _buildCard(
    PageVisualPalette palette, {
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }

  Widget _buildPreprocessSwitch() {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => unawaited(_setAiPreprocessEnabled(!_aiPreprocessEnabled)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: scheme.secondary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  Icons.auto_stories_outlined,
                  size: 16,
                  color: scheme.secondary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.settingsAiPreprocessTitle,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      l10n.settingsAiPreprocessSubtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: _aiPreprocessEnabled,
                onChanged: (value) => unawaited(_setAiPreprocessEnabled(value)),
                activeTrackColor: scheme.primary,
                thumbColor: WidgetStateProperty.resolveWith(
                  (states) => states.contains(WidgetState.selected)
                      ? scheme.onPrimary
                      : scheme.outline,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 开启前校验已有可用 AI 模型，并提示大量 token 消耗；关闭无需确认。
  Future<void> _setAiPreprocessEnabled(bool value) async {
    final l10n = context.l10n;
    if (value) {
      final settings = await _aiService.loadSettings();
      if (!mounted) return;
      if (!settings.isConfigured) {
        showSideToast(
          context,
          l10n.settingsAiPreprocessNeedModel,
          kind: SideToastKind.error,
        );
        return;
      }
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(l10n.settingsAiPreprocessTitle),
          content: Text(l10n.settingsAiPreprocessWarning),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n.cancel),
            ),
            FilledButton.tonal(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(l10n.confirm),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    setState(() => _aiPreprocessEnabled = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(aiPreprocessBooksPrefsKey, value);
  }

  Widget _buildAiModelRow(_AiQuickModel item) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final selected = item.id == _activeAiQuickModelId;
    final configured = item.settings.isConfigured;
    final host = Uri.tryParse(item.settings.baseUrl)?.host ?? '';
    final subtitle = configured
        ? '${item.settings.provider.displayName} · '
              '${host.isNotEmpty ? host : item.settings.baseUrl}'
        : l10n.settingsAiApiKeyTapToConfigure;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => unawaited(_activateAiQuickModel(item)),
        onLongPress: () => unawaited(_showAiQuickModelMenu(item)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 10, 10),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: (selected ? scheme.primary : scheme.onSurfaceVariant)
                      .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  selected
                      ? Icons.auto_awesome_rounded
                      : Icons.auto_awesome_outlined,
                  size: 16,
                  color: selected ? scheme.primary : scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.settings.model,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: configured
                            ? scheme.onSurfaceVariant
                            : scheme.error,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 160),
                child: selected
                    ? Icon(
                        Icons.check_circle_rounded,
                        key: const ValueKey('selected'),
                        size: 20,
                        color: scheme.primary,
                      )
                    : const SizedBox.square(
                        key: ValueKey('not-selected'),
                        dimension: 20,
                      ),
              ),
              IconButton(
                onPressed: () => unawaited(_showAiQuickModelMenu(item)),
                icon: const Icon(Icons.more_vert_rounded, size: 20),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAddAiModelRow() {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => unawaited(_showAiModelSheet()),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(Icons.add_rounded, size: 16, color: scheme.primary),
              ),
              const SizedBox(width: 12),
              Text(
                l10n.settingsAiAddModel,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: scheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
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

  Future<void> _showAiQuickModelMenu(_AiQuickModel item) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) {
        final scheme = Theme.of(sheetContext).colorScheme;
        return SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: Text(sheetContext.l10n.edit),
                onTap: () => Navigator.of(sheetContext).pop('edit'),
              ),
              if (item.isCustom && _aiQuickModels.length > 1)
                ListTile(
                  leading: Icon(Icons.delete_outline, color: scheme.error),
                  title: Text(
                    sheetContext.l10n.delete,
                    style: TextStyle(color: scheme.error),
                  ),
                  onTap: () => Navigator.of(sheetContext).pop('delete'),
                ),
            ],
          ),
        );
      },
    );
    if (!mounted) return;
    switch (action) {
      case 'edit':
        await _showAiModelSheet(editing: item);
      case 'delete':
        await _removeAiQuickModel(item);
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
          final l10n = sheetContext.l10n;
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

    // 弹窗 pop 后仍有退场动画，期间表单还会随键盘收起重建并读取这些控制器；
    // 立即释放会让 EditableText 在拆除中途崩溃，延迟到动画结束后再释放。
    unawaited(
      Future<void>.delayed(const Duration(seconds: 1), () {
        apiKeyController.dispose();
        baseUrlController.dispose();
        modelController.dispose();
        temperatureController.dispose();
      }),
    );

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
    });
    await _persistAiQuickModels();
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
