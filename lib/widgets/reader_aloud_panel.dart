import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../core/reader/reader_aloud_controller.dart';
import '../services/reader_aloud_service.dart';
import '../services/tts_service.dart';
import '../services/tts_service_translator.dart';
import '../utils/localization_extension.dart';
import '../utils/reader_themes.dart';

Future<void> showReaderAloudPanelSheet({
  required BuildContext context,
  required ReaderAloudController controller,
  required TtsService ttsService,
  required ReaderAloudService aloudService,
  required ReaderThemePalette palette,
  required ThemeData themeData,
}) => showModalBottomSheet<void>(
  context: context,
  useSafeArea: true,
  isScrollControlled: true,
  enableDrag: true,
  showDragHandle: true,
  backgroundColor: palette.controlBar,
  constraints: BoxConstraints(
    maxWidth: 720,
    maxHeight: MediaQuery.sizeOf(context).height * 0.72,
  ),
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
  ),
  clipBehavior: Clip.antiAlias,
  builder: (sheetContext) => Theme(
    data: themeData,
    child: ReaderAloudPanel(
      controller: controller,
      ttsService: ttsService,
      aloudService: aloudService,
      palette: palette,
    ),
  ),
);

class ReaderAloudPanel extends StatefulWidget {
  const ReaderAloudPanel({
    super.key,
    required this.controller,
    required this.ttsService,
    required this.aloudService,
    required this.palette,
  });

  final ReaderAloudController controller;
  final TtsService ttsService;
  final ReaderAloudService aloudService;
  final ReaderThemePalette palette;

  @override
  State<ReaderAloudPanel> createState() => _ReaderAloudPanelState();
}

class _ReaderAloudPanelState extends State<ReaderAloudPanel> {
  Timer? _sleepTimerTicker;
  double? _pendingSpeechRate;
  double? _pendingVolume;
  double? _pendingPitch;

  @override
  void initState() {
    super.initState();
    unawaited(widget.ttsService.ensureVoicesLoaded());
    unawaited(widget.aloudService.initialize());
    _sleepTimerTicker = Timer.periodic(const Duration(seconds: 20), (_) {
      if (mounted && widget.controller.sleepRemaining != null) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _sleepTimerTicker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: AnimatedBuilder(
        animation: Listenable.merge([
          widget.controller,
          widget.ttsService,
          widget.aloudService,
        ]),
        builder: (context, _) {
          final controller = widget.controller;
          final tts = widget.ttsService;
          final aloud = widget.aloudService;
          final errorCode = tts.lastError;
          final speechRate = _pendingSpeechRate ?? tts.speechRate;
          final volume = _pendingVolume ?? tts.speechVolume;
          final pitch = _pendingPitch ?? tts.speechPitch;
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(22, 16, 22, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.headphones_rounded,
                      color: widget.palette.accent,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        context.l10n.ttsPanelTitle,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: widget.palette.text,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Text(
                      _stateLabel(context, controller.state),
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: widget.palette.secondaryText,
                      ),
                    ),
                  ],
                ),
                if (controller.currentChapter != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    controller.currentChapter!.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: widget.palette.text,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: controller.chapterProgress,
                    minHeight: 5,
                    borderRadius: BorderRadius.circular(99),
                    color: widget.palette.accent,
                    backgroundColor: widget.palette.secondaryText.withValues(
                      alpha: 0.14,
                    ),
                  ),
                ],
                if (controller.currentSegment != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    controller.currentSegment!.text,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      height: 1.55,
                      color: widget.palette.secondaryText,
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                _engineSelector(context, controller, aloud),
                if (aloud.usesCloud) ...[
                  const SizedBox(height: 12),
                  _cloudConfigurationCard(context, aloud),
                ],
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _controlButton(
                      context,
                      icon: Icons.skip_previous_rounded,
                      tooltip: context.l10n.ttsPreviousSentence,
                      onPressed: () => unawaited(controller.previous()),
                    ),
                    _primaryControl(context, controller),
                    _controlButton(
                      context,
                      icon: Icons.skip_next_rounded,
                      tooltip: context.l10n.ttsNextSentence,
                      onPressed: () => unawaited(controller.next()),
                    ),
                    _controlButton(
                      context,
                      icon: Icons.stop_rounded,
                      tooltip: context.l10n.stop,
                      onPressed: controller.isActive
                          ? () => unawaited(controller.stop())
                          : null,
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _slider(
                  context,
                  label: context.l10n.ttsSpeed,
                  value: speechRate,
                  min: 0.1,
                  max: 1,
                  valueLabel: '${speechRate.toStringAsFixed(2)}×',
                  onChanged: (value) =>
                      setState(() => _pendingSpeechRate = value),
                  onChangeEnd: (value) =>
                      unawaited(_commitSpeechRate(value, controller, tts)),
                ),
                _slider(
                  context,
                  label: context.l10n.ttsVolume,
                  value: volume,
                  min: 0,
                  max: 1,
                  valueLabel: '${(volume * 100).round()}%',
                  onChanged: (value) => setState(() => _pendingVolume = value),
                  onChangeEnd: (value) =>
                      unawaited(_commitVolume(value, controller, tts, aloud)),
                ),
                _slider(
                  context,
                  label: context.l10n.ttsPitch,
                  value: pitch,
                  min: 0.5,
                  max: 2,
                  valueLabel: pitch.toStringAsFixed(2),
                  onChanged: aloud.usesCloud
                      ? null
                      : (value) => setState(() => _pendingPitch = value),
                  onChangeEnd: aloud.usesCloud
                      ? null
                      : (value) =>
                            unawaited(_commitPitch(value, controller, tts)),
                ),
                const SizedBox(height: 8),
                if (!aloud.usesCloud) _voicePicker(context, tts, controller),
                const SizedBox(height: 16),
                _sleepTimerCard(context, controller),
                if (errorCode != null ||
                    controller.lastError != null ||
                    aloud.cloudError != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    aloud.cloudError ??
                        (errorCode == null
                            ? context.l10n.ttsPlaybackFailed
                            : translateTtsError(
                                context,
                                errorCode,
                                tts.lastErrorLanguage,
                              )),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _primaryControl(
    BuildContext context,
    ReaderAloudController controller,
  ) {
    final loading = controller.state == ReaderAloudPlaybackState.loading;
    final playing = controller.state == ReaderAloudPlaybackState.playing;
    return Semantics(
      button: true,
      label: playing ? context.l10n.pause : context.l10n.play,
      child: IconButton.filled(
        onPressed: loading
            ? null
            : () {
                if (playing) {
                  unawaited(controller.pause());
                } else if (controller.state ==
                    ReaderAloudPlaybackState.paused) {
                  unawaited(controller.resume());
                } else {
                  unawaited(controller.start());
                }
              },
        tooltip: playing ? context.l10n.pause : context.l10n.play,
        iconSize: 32,
        padding: const EdgeInsets.all(16),
        style: IconButton.styleFrom(
          backgroundColor: widget.palette.accent,
          foregroundColor: widget.palette.brightness == Brightness.dark
              ? Colors.black
              : Colors.white,
        ),
        icon: loading
            ? const SizedBox.square(
                dimension: 26,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              )
            : Icon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded),
      ),
    );
  }

  Future<void> _commitSpeechRate(
    double value,
    ReaderAloudController controller,
    TtsService tts,
  ) async {
    try {
      await tts.setSpeechRate(value);
      await controller.refreshPlayback();
    } finally {
      if (mounted) setState(() => _pendingSpeechRate = null);
    }
  }

  Future<void> _commitVolume(
    double value,
    ReaderAloudController controller,
    TtsService tts,
    ReaderAloudService aloud,
  ) async {
    try {
      await tts.setVolume(value);
      if (aloud.activeEngineType == ReaderAloudEngineType.cloud) {
        await aloud.syncVolume();
      } else {
        await controller.refreshPlayback();
      }
    } finally {
      if (mounted) setState(() => _pendingVolume = null);
    }
  }

  Future<void> _commitPitch(
    double value,
    ReaderAloudController controller,
    TtsService tts,
  ) async {
    try {
      await tts.setPitch(value);
      await controller.refreshPlayback();
    } finally {
      if (mounted) setState(() => _pendingPitch = null);
    }
  }

  Widget _engineSelector(
    BuildContext context,
    ReaderAloudController controller,
    ReaderAloudService aloud,
  ) => SegmentedButton<ReaderAloudEngineType>(
    segments: [
      ButtonSegment(
        value: ReaderAloudEngineType.system,
        icon: const Icon(Icons.phone_android_rounded),
        label: Text(_copy(context, '系统语音', 'System', 'システム音声')),
      ),
      ButtonSegment(
        value: ReaderAloudEngineType.cloud,
        icon: const Icon(Icons.cloud_outlined),
        label: Text(_copy(context, '云端 TTS', 'Cloud TTS', 'クラウド TTS')),
      ),
    ],
    selected: {aloud.engineType},
    showSelectedIcon: false,
    onSelectionChanged: (selection) {
      final selected = selection.first;
      if (selected == aloud.engineType) return;
      unawaited(() async {
        final resumeAfterChange =
            controller.state == ReaderAloudPlaybackState.playing;
        if (resumeAfterChange) await controller.pause();
        await aloud.setEngineType(selected);
        if (resumeAfterChange) await controller.resume();
      }());
    },
  );

  Widget _cloudConfigurationCard(
    BuildContext context,
    ReaderAloudService aloud,
  ) => DecoratedBox(
    decoration: BoxDecoration(
      color: widget.palette.surface.withValues(alpha: 0.72),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: widget.palette.border.withValues(alpha: 0.72)),
    ),
    child: ListTile(
      leading: Icon(
        aloud.hasCloudApiKey ? Icons.cloud_done_outlined : Icons.key_outlined,
        color: aloud.hasCloudApiKey
            ? widget.palette.accent
            : widget.palette.secondaryText,
      ),
      title: Text(
        '${aloud.cloudSettings.model} · ${aloud.cloudSettings.voice}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        aloud.hasCloudApiKey
            ? _copy(
                context,
                'API Key 已安全保存',
                'API key saved securely',
                'API Key を安全に保存済み',
              )
            : _copy(
                context,
                '需要配置 API Key',
                'API key required',
                'API Key の設定が必要です',
              ),
      ),
      trailing: const Icon(Icons.tune_rounded),
      onTap: () => unawaited(_showCloudSettings(context, aloud)),
    ),
  );

  Future<void> _showCloudSettings(
    BuildContext context,
    ReaderAloudService aloud,
  ) async {
    final settings = aloud.cloudSettings;
    final baseUrlController = TextEditingController(text: settings.baseUrl);
    final modelController = TextEditingController(text: settings.model);
    final voiceController = TextEditingController(text: settings.voice);
    final apiKeyController = TextEditingController();
    var responseFormat = settings.responseFormat;
    var fallbackToSystem = settings.fallbackToSystem;
    String? validationError;
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(
            _copy(context, '云端 TTS 设置', 'Cloud TTS settings', 'クラウド TTS 設定'),
          ),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: baseUrlController,
                    keyboardType: TextInputType.url,
                    autocorrect: false,
                    decoration: const InputDecoration(
                      labelText: 'Base URL',
                      hintText: 'https://api.openai.com/v1',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: modelController,
                    autocorrect: false,
                    decoration: const InputDecoration(labelText: 'Model'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: voiceController,
                    autocorrect: false,
                    decoration: const InputDecoration(labelText: 'Voice'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: responseFormat,
                    decoration: const InputDecoration(labelText: 'Format'),
                    items: const [
                      DropdownMenuItem(value: 'mp3', child: Text('mp3')),
                      DropdownMenuItem(value: 'opus', child: Text('opus')),
                      DropdownMenuItem(value: 'aac', child: Text('aac')),
                      DropdownMenuItem(value: 'flac', child: Text('flac')),
                      DropdownMenuItem(value: 'wav', child: Text('wav')),
                    ],
                    onChanged: (value) {
                      if (value != null) responseFormat = value;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: apiKeyController,
                    obscureText: true,
                    enableSuggestions: false,
                    autocorrect: false,
                    decoration: InputDecoration(
                      labelText: 'API Key',
                      hintText: aloud.hasCloudApiKey
                          ? _copy(
                              context,
                              '留空保留已保存的密钥',
                              'Leave blank to keep saved key',
                              '空欄で保存済みキーを維持',
                            )
                          : null,
                    ),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      _copy(
                        context,
                        '失败时回退到系统语音',
                        'Fall back to system voice',
                        '失敗時はシステム音声に切り替え',
                      ),
                    ),
                    value: fallbackToSystem,
                    onChanged: (value) =>
                        setDialogState(() => fallbackToSystem = value),
                  ),
                  if (validationError != null)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        validationError!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            if (aloud.hasCloudApiKey)
              TextButton(
                onPressed: () async {
                  await aloud.clearCloudApiKey();
                  if (dialogContext.mounted) {
                    Navigator.of(dialogContext).pop(false);
                  }
                },
                child: Text(_copy(context, '清除密钥', 'Clear key', 'キーを削除')),
              ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
            ),
            FilledButton(
              onPressed: () async {
                try {
                  await aloud.updateCloudSettings(
                    ReaderAloudCloudSettings(
                      baseUrl: baseUrlController.text,
                      model: modelController.text,
                      voice: voiceController.text,
                      responseFormat: responseFormat,
                      fallbackToSystem: fallbackToSystem,
                    ),
                  );
                  if (apiKeyController.text.trim().isNotEmpty) {
                    await aloud.saveCloudApiKey(apiKeyController.text);
                  }
                  if (dialogContext.mounted) {
                    Navigator.of(dialogContext).pop(true);
                  }
                } on ReaderAloudCloudException catch (error) {
                  setDialogState(() => validationError = error.message);
                } catch (_) {
                  setDialogState(
                    () => validationError = _copy(
                      context,
                      '保存失败，请检查系统安全存储',
                      'Could not save settings or secure key',
                      '設定または安全なキーを保存できません',
                    ),
                  );
                }
              },
              child: Text(_copy(context, '保存', 'Save', '保存')),
            ),
          ],
        ),
      ),
    );
    baseUrlController.dispose();
    modelController.dispose();
    voiceController.dispose();
    apiKeyController.dispose();
    if (saved == true) {
      await widget.controller.refreshPlayback();
    }
  }

  String _copy(BuildContext context, String zh, String en, String ja) {
    return switch (Localizations.localeOf(context).languageCode) {
      'en' => en,
      'ja' => ja,
      _ => zh,
    };
  }

  Widget _controlButton(
    BuildContext context, {
    required IconData icon,
    required String tooltip,
    required VoidCallback? onPressed,
  }) => IconButton(
    onPressed: onPressed,
    tooltip: tooltip,
    iconSize: 30,
    color: widget.palette.text,
    disabledColor: widget.palette.secondaryText.withValues(alpha: 0.35),
    icon: Icon(icon),
  );

  Widget _slider(
    BuildContext context, {
    required String label,
    required double value,
    required double min,
    required double max,
    required String valueLabel,
    required ValueChanged<double>? onChanged,
    required ValueChanged<double>? onChangeEnd,
  }) => Row(
    children: [
      SizedBox(
        width: 48,
        child: Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: widget.palette.text),
        ),
      ),
      Expanded(
        child: Slider(
          value: value.clamp(min, max),
          min: min,
          max: max,
          onChanged: onChanged,
          onChangeEnd: onChangeEnd,
        ),
      ),
      SizedBox(
        width: 48,
        child: Text(
          valueLabel,
          textAlign: TextAlign.end,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: widget.palette.secondaryText,
          ),
        ),
      ),
    ],
  );

  Widget _voicePicker(
    BuildContext context,
    TtsService tts,
    ReaderAloudController controller,
  ) {
    final voices = tts.availableVoices;
    final selectedId = voices.any((voice) => voice.id == tts.currentVoice?.id)
        ? tts.currentVoice!.id
        : '';
    return DropdownButtonFormField<String>(
      key: ValueKey('reader-aloud-voice:$selectedId:${voices.length}'),
      initialValue: selectedId,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: context.l10n.ttsReading,
        border: const OutlineInputBorder(),
      ),
      items: [
        DropdownMenuItem(value: '', child: Text(context.l10n.ttsSystemDefault)),
        for (final voice in voices)
          DropdownMenuItem(
            value: voice.id,
            child: Text(
              voice.subtitle.isEmpty
                  ? voice.title
                  : '${voice.title} · ${voice.subtitle}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
      onChanged: tts.isLoadingVoices
          ? null
          : (id) {
              unawaited(() async {
                if (id == null || id.isEmpty) {
                  await tts.clearSelectedVoice();
                } else {
                  final voice = voices
                      .where((voice) => voice.id == id)
                      .firstOrNull;
                  if (voice == null) return;
                  await tts.setVoice(voice);
                }
                await controller.refreshPlayback();
              }());
            },
    );
  }

  Widget _sleepTimerCard(
    BuildContext context,
    ReaderAloudController controller,
  ) {
    final total = controller.sleepDuration;
    final remaining = controller.sleepRemaining;
    final active = total != null && remaining != null;
    final progress = active && total.inMilliseconds > 0
        ? (remaining.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;
    return Material(
      key: const ValueKey('reader-aloud-sleep-timer-card'),
      color: widget.palette.accent.withValues(
        alpha: active
            ? (widget.palette.brightness == Brightness.dark ? 0.16 : 0.10)
            : 0.05,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: active
              ? widget.palette.accent.withValues(alpha: 0.42)
              : widget.palette.border.withValues(alpha: 0.62),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => unawaited(_showSleepTimerPicker(context, controller)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 13, 10, 11),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: widget.palette.accent.withValues(
                        alpha: active ? 0.18 : 0.10,
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      active ? Icons.bedtime_rounded : Icons.timer_outlined,
                      color: widget.palette.accent,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                context.l10n.ttsTimerStop,
                                style: Theme.of(context).textTheme.titleSmall
                                    ?.copyWith(
                                      color: widget.palette.text,
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                            ),
                            if (active) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: widget.palette.accent.withValues(
                                    alpha: 0.16,
                                  ),
                                  borderRadius: BorderRadius.circular(99),
                                ),
                                child: Text(
                                  _copy(context, '已开启', 'Active', '有効'),
                                  style: Theme.of(context).textTheme.labelSmall
                                      ?.copyWith(
                                        color: widget.palette.accent,
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          active
                              ? _copy(
                                  context,
                                  '剩余 ${_formatTimerDuration(context, remaining)}',
                                  '${_formatTimerDuration(context, remaining)} remaining',
                                  '残り ${_formatTimerDuration(context, remaining)}',
                                )
                              : _copy(
                                  context,
                                  '自由选择小时和分钟',
                                  'Choose any hours and minutes',
                                  '時間と分を自由に選択',
                                ),
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: widget.palette.secondaryText),
                        ),
                      ],
                    ),
                  ),
                  if (active)
                    IconButton(
                      key: const ValueKey('reader-aloud-sleep-timer-clear'),
                      tooltip: context.l10n.ttsTimerOff,
                      onPressed: () => controller.setSleepTimer(null),
                      icon: const Icon(Icons.close_rounded),
                      color: widget.palette.secondaryText,
                    )
                  else
                    Icon(
                      Icons.chevron_right_rounded,
                      color: widget.palette.secondaryText,
                    ),
                ],
              ),
              if (active) ...[
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 4,
                    color: widget.palette.accent,
                    backgroundColor: widget.palette.accent.withValues(
                      alpha: 0.10,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showSleepTimerPicker(
    BuildContext context,
    ReaderAloudController controller,
  ) async {
    final remaining = controller.sleepRemaining;
    final initialMinutes = remaining == null
        ? 30
        : ((remaining.inSeconds + 59) ~/ 60).clamp(1, 1439).toInt();
    var selected = Duration(minutes: initialMinutes);
    final result = await showModalBottomSheet<Duration>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      enableDrag: true,
      showDragHandle: true,
      backgroundColor: widget.palette.controlBar,
      constraints: BoxConstraints(
        maxWidth: 620,
        maxHeight: MediaQuery.sizeOf(context).height * 0.62,
      ),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (sheetContext) => Theme(
        data: widget.palette.toThemeData(
          typography: Theme.of(context).textTheme,
        ),
        child: StatefulBuilder(
          builder: (context, setSheetState) => Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  context.l10n.ttsTimerStop,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: widget.palette.text,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _timerPickerSummary(selected),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: widget.palette.accent,
                    fontWeight: FontWeight.w800,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(height: 6),
                SizedBox(
                  height: 154,
                  child: CupertinoTheme(
                    data: CupertinoThemeData(
                      brightness: widget.palette.brightness,
                      primaryColor: widget.palette.accent,
                      textTheme: CupertinoTextThemeData(
                        pickerTextStyle: TextStyle(
                          color: widget.palette.text,
                          fontSize: 22,
                        ),
                      ),
                    ),
                    child: CupertinoTimerPicker(
                      key: const ValueKey('reader-aloud-sleep-timer-picker'),
                      mode: CupertinoTimerPickerMode.hm,
                      initialTimerDuration: selected,
                      minuteInterval: 1,
                      onTimerDurationChanged: (value) =>
                          setSheetState(() => selected = value),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    if (controller.sleepDuration != null) ...[
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () =>
                              Navigator.of(sheetContext).pop(Duration.zero),
                          child: Text(context.l10n.ttsTimerOff),
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: FilledButton.icon(
                        key: const ValueKey('reader-aloud-sleep-timer-confirm'),
                        onPressed: selected > Duration.zero
                            ? () => Navigator.of(sheetContext).pop(selected)
                            : null,
                        icon: const Icon(Icons.bedtime_rounded),
                        label: Text(
                          _copy(context, '开始计时', 'Start timer', 'タイマー開始'),
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
    if (result == null || !mounted) return;
    controller.setSleepTimer(result > Duration.zero ? result : null);
  }

  String _timerPickerSummary(Duration value) {
    final hours = value.inHours;
    final minutes = value.inMinutes.remainder(60);
    return '${hours.toString().padLeft(2, '0')} : '
        '${minutes.toString().padLeft(2, '0')}';
  }

  String _formatTimerDuration(BuildContext context, Duration value) {
    final roundedMinutes = ((value.inSeconds + 59) ~/ 60)
        .clamp(0, 1439)
        .toInt();
    final hours = roundedMinutes ~/ 60;
    final minutes = roundedMinutes.remainder(60);
    if (hours == 0) {
      return _copy(context, '$minutes 分钟', '$minutes min', '$minutes 分');
    }
    if (minutes == 0) {
      return _copy(context, '$hours 小时', '$hours hr', '$hours 時間');
    }
    return _copy(
      context,
      '$hours 小时 $minutes 分钟',
      '$hours hr $minutes min',
      '$hours 時間 $minutes 分',
    );
  }

  String _stateLabel(BuildContext context, ReaderAloudPlaybackState state) =>
      switch (state) {
        ReaderAloudPlaybackState.playing => context.l10n.ttsPlaying,
        ReaderAloudPlaybackState.paused => context.l10n.ttsPaused,
        ReaderAloudPlaybackState.loading => context.l10n.ttsReading,
        ReaderAloudPlaybackState.error => context.l10n.ttsPlaybackFailed,
        ReaderAloudPlaybackState.stopped => context.l10n.ttsStopped,
      };
}
