// 文件说明：当前主链路 TTS 服务，直接封装 FlutterTts 并管理朗读状态。
// 技术要点：服务层、Flutter TTS、SharedPreferences、渲染层、Flutter。

import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TtsVoiceOption {
  final String name;
  final String locale;
  final String? identifier;
  final String? displayName;
  final String? quality;
  final String? gender;

  const TtsVoiceOption({
    required this.name,
    required this.locale,
    this.identifier,
    this.displayName,
    this.quality,
    this.gender,
  });

  factory TtsVoiceOption.fromMap(Map<dynamic, dynamic> raw) {
    String readString(String key) {
      final value = raw[key];
      return value?.toString().trim() ?? '';
    }

    String? readNullable(String key) {
      final value = raw[key]?.toString().trim();
      if (value == null || value.isEmpty) {
        return null;
      }
      return value;
    }

    return TtsVoiceOption(
      name: readString('name'),
      locale: readString('locale'),
      identifier: readNullable('identifier'),
      displayName: readNullable('displayName'),
      quality: readNullable('quality'),
      gender: readNullable('gender'),
    );
  }

  TtsVoiceOption copyWith({
    String? name,
    String? locale,
    String? identifier,
    String? displayName,
    String? quality,
    String? gender,
  }) {
    return TtsVoiceOption(
      name: name ?? this.name,
      locale: locale ?? this.locale,
      identifier: identifier ?? this.identifier,
      displayName: displayName ?? this.displayName,
      quality: quality ?? this.quality,
      gender: gender ?? this.gender,
    );
  }

  String get normalizedLocale => locale.replaceAll('_', '-').trim();

  String get languageCode {
    final normalized = normalizedLocale.toLowerCase();
    if (normalized.isEmpty) {
      return '';
    }
    return normalized.split('-').first;
  }

  String get id {
    final trimmedIdentifier = identifier?.trim();
    if (trimmedIdentifier != null && trimmedIdentifier.isNotEmpty) {
      return trimmedIdentifier;
    }
    final normalizedName = name.trim().isNotEmpty ? name.trim() : 'default';
    final normalizedVoiceLocale = normalizedLocale.isNotEmpty
        ? normalizedLocale
        : 'und';
    return '$normalizedVoiceLocale::$normalizedName';
  }

  String get title {
    final preferredLabel = displayName?.trim();
    if (preferredLabel != null && preferredLabel.isNotEmpty) {
      return preferredLabel;
    }
    final trimmedName = name.trim();
    if (trimmedName.isNotEmpty) {
      return trimmedName;
    }
    return normalizedLocale.isNotEmpty ? normalizedLocale : 'System Voice';
  }

  String get subtitle {
    final parts = <String>[
      if (normalizedLocale.isNotEmpty) normalizedLocale,
      if (quality?.trim().isNotEmpty ?? false) _prettifyMeta(quality!),
      if (gender?.trim().isNotEmpty ?? false) _prettifyMeta(gender!),
    ];
    return parts.join(' · ');
  }

  bool matchesLanguage(String localeOrLanguage) {
    final normalized = localeOrLanguage.replaceAll('_', '-').trim();
    if (normalized.isEmpty) {
      return false;
    }
    return languageCode == normalized.toLowerCase().split('-').first;
  }

  bool matchesLocale(String localeOrLanguage) {
    return normalizedLocale.toLowerCase() ==
        localeOrLanguage.replaceAll('_', '-').trim().toLowerCase();
  }

  static String _prettifyMeta(String raw) {
    final normalized = raw.replaceAll('_', ' ').trim();
    if (normalized.isEmpty) {
      return raw;
    }
    return normalized[0].toUpperCase() + normalized.substring(1);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is TtsVoiceOption && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

/// 只使用系统 TTS（flutter_tts 封装平台系统引擎）。
class TtsService extends ChangeNotifier {
  static const String _voiceIdPrefKey = 'tts_voice_id';
  static const String _voiceIdentifierPrefKey = 'tts_voice_identifier';
  static const String _voiceNamePrefKey = 'tts_voice_name';
  static const String _voiceLocalePrefKey = 'tts_voice_locale';

  FlutterTts? _flutterTts;
  Future<void>? _initializationFuture;
  Future<void>? _voiceLoadingFuture;
  Timer? _parameterApplyDebounceTimer;
  bool _isDisposed = false;

  bool _isPlaying = false;
  bool _isPaused = false;
  bool _isInitialized = false;
  bool _isInitializing = false;
  double _speechRate = 0.5;
  double _speechVolume = 1.0;
  double _speechPitch = 1.0;
  String _currentLanguage = 'zh-CN';
  List<String> _availableLanguages = const <String>[];
  String _currentText = '';
  int _currentPosition = 0;
  String? _lastError;
  String? _lastErrorLanguage;
  bool _isLoadingVoices = false;
  String? _voiceLoadError;
  List<TtsVoiceOption> _availableVoices = const <TtsVoiceOption>[];
  TtsVoiceOption? _currentVoice;

  bool get isPlaying => _isPlaying;
  bool get isPaused => _isPaused;
  bool get isInitialized => _isInitialized;
  bool get isInitializing => _isInitializing;
  bool get isAvailable => _isInitialized;
  String? get lastError => _lastError;
  String? get lastErrorLanguage => _lastErrorLanguage;
  double get speechRate => _speechRate;
  double get speechVolume => _speechVolume;
  double get speechPitch => _speechPitch;
  String get currentLanguage => _currentLanguage;
  List<String> get availableLanguages => _availableLanguages;
  String get currentText => _currentText;
  int get currentPosition => _currentPosition;
  bool get isLoadingVoices => _isLoadingVoices;
  String? get voiceLoadError => _voiceLoadError;
  List<TtsVoiceOption> get availableVoices => _availableVoices;
  TtsVoiceOption? get currentVoice => _currentVoice;
  String get currentVoiceLabel => _currentVoice?.title ?? 'system_default';

  TtsService() {
    unawaited(initialize());
  }

  Future<void> initialize({bool force = false}) async {
    if (_isDisposed) return;

    if (_isInitializing) {
      final pending = _initializationFuture;
      if (pending != null) {
        await pending;
      }
      return;
    }

    if (!force && _isInitialized && _flutterTts != null) {
      return;
    }

    final completer = Completer<void>();
    _initializationFuture = completer.future;

    _isInitializing = true;
    _lastError = null;
    if (force) {
      _isInitialized = false;
    }
    _notifySafe();

    try {
      await _loadSettings();

      final tts = FlutterTts();
      _wireHandlers(tts);
      await _configureSystemTts(tts);
      await _safeSetSpeechRate(tts, _speechRate);
      await _safeSetVolume(tts, _speechVolume);
      await _safeSetPitch(tts, _speechPitch);
      await _refreshAvailableLanguages(tts);
      await _applyBestLanguage(tts);
      await _restoreSavedVoice(tts);

      _flutterTts = tts;
      _isInitialized = true;
      _lastError = null;
      debugPrint('TTS 初始化成功，语言: $_currentLanguage');
    } catch (e) {
      _isInitialized = false;
      _isPlaying = false;
      _isPaused = false;
      _lastError = _toErrorText(e);
      debugPrint('TTS 初始化失败: $e');
    } finally {
      _isInitializing = false;
      _notifySafe();

      if (!completer.isCompleted) {
        completer.complete();
      }
      if (identical(_initializationFuture, completer.future)) {
        _initializationFuture = null;
      }
    }
  }

  Future<void> retryInitialize() async {
    await initialize(force: true);
  }

  Future<void> _configureSystemTts(FlutterTts tts) async {
    await tts.awaitSpeakCompletion(true);

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      await tts.awaitSynthCompletion(true);
      // 0: flush，确保每次朗读直接替换旧任务，避免排队导致“没反应”。
      await tts.setQueueMode(0);
    }

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      await tts.setSharedInstance(true);
      await tts.autoStopSharedSession(true);
      await tts.setIosAudioCategory(
        IosTextToSpeechAudioCategory.playback,
        const [
          IosTextToSpeechAudioCategoryOptions.mixWithOthers,
          IosTextToSpeechAudioCategoryOptions.defaultToSpeaker,
        ],
        IosTextToSpeechAudioMode.voicePrompt,
      );
    }
  }

  void _wireHandlers(FlutterTts tts) {
    tts.setStartHandler(() {
      _isPlaying = true;
      _isPaused = false;
      _lastError = null;
      _notifySafe();
    });

    tts.setCompletionHandler(() {
      _isPlaying = false;
      _isPaused = false;
      _currentPosition = 0;
      _notifySafe();
    });

    tts.setPauseHandler(() {
      _isPlaying = false;
      _isPaused = true;
      _notifySafe();
    });

    tts.setContinueHandler(() {
      _isPlaying = true;
      _isPaused = false;
      _notifySafe();
    });

    tts.setCancelHandler(() {
      _isPlaying = false;
      _isPaused = false;
      _notifySafe();
    });

    tts.setProgressHandler((
      String text,
      int startOffset,
      int endOffset,
      String word,
    ) {
      _currentPosition = startOffset.clamp(0, _currentText.length);
      _notifySafe();
    });

    tts.setErrorHandler((message) {
      _isPlaying = false;
      _isPaused = false;
      _lastError = message;
      _notifySafe();
      debugPrint('TTS 运行错误: $message');
    });
  }

  Future<void> _refreshAvailableLanguages(FlutterTts tts) async {
    try {
      final result = await tts.getLanguages;
      if (result is Iterable) {
        final unique = <String>{};
        for (final item in result) {
          final value = item.toString().trim();
          if (value.isNotEmpty) {
            unique.add(value);
          }
        }
        _availableLanguages = unique.toList(growable: false)..sort();
      } else {
        _availableLanguages = const <String>[];
      }
    } catch (e) {
      _availableLanguages = const <String>[];
      debugPrint('获取 TTS 语言列表失败: $e');
    }
  }

  Future<void> ensureVoicesLoaded({bool force = false}) async {
    if (_isDisposed) return;

    if (!force && _availableVoices.isNotEmpty) {
      return;
    }

    final pending = _voiceLoadingFuture;
    if (pending != null) {
      await pending;
      return;
    }

    final completer = Completer<void>();
    _voiceLoadingFuture = completer.future;

    _isLoadingVoices = true;
    _voiceLoadError = null;
    _notifySafe();

    try {
      await initialize();
      final tts = _flutterTts;
      if (!_isInitialized || tts == null) {
        return;
      }

      final voices = await _loadVoicesFromEngine(tts);
      _availableVoices = voices;
      _currentVoice = _syncVoiceWithAvailableList(_currentVoice, voices);
      _voiceLoadError = null;
    } catch (e) {
      _voiceLoadError = _toErrorText(e);
      debugPrint('加载 TTS 音色失败: $e');
    } finally {
      _isLoadingVoices = false;
      _notifySafe();

      if (!completer.isCompleted) {
        completer.complete();
      }
      if (identical(_voiceLoadingFuture, completer.future)) {
        _voiceLoadingFuture = null;
      }
    }
  }

  Future<void> setVoice(TtsVoiceOption voice) async {
    await initialize();
    final tts = _flutterTts;
    if (!_isInitialized || tts == null) {
      _lastError = _lastError ?? 'tts_unavailable';
      _notifySafe();
      return;
    }

    try {
      _lastError = null;
      _voiceLoadError = null;

      await _applyVoiceToEngine(tts, voice);
      _currentLanguage = voice.normalizedLocale.isNotEmpty
          ? voice.normalizedLocale
          : voice.locale;
      _currentVoice =
          _syncVoiceWithAvailableList(voice, _availableVoices) ?? voice;

      await _saveSettings();
      if (_isPlaying && !_isPaused) {
        await _restartCurrentPlaybackWithLatestSettings();
      } else {
        _notifySafe();
      }
    } catch (e) {
      _lastError = _toErrorText(e);
      _notifySafe();
      debugPrint('设置 TTS 音色失败: $e');
    }
  }

  Future<void> clearSelectedVoice() async {
    await initialize();
    final tts = _flutterTts;
    if (!_isInitialized || tts == null) {
      _lastError = _lastError ?? 'tts_unavailable';
      _notifySafe();
      return;
    }

    try {
      _lastError = null;
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
        await tts.clearVoice();
      }
      await _trySetLanguage(tts, _currentLanguage);
      _currentVoice = null;
      await _saveSettings();

      if (_isPlaying && !_isPaused) {
        await _restartCurrentPlaybackWithLatestSettings();
      } else {
        _notifySafe();
      }
    } catch (e) {
      _lastError = _toErrorText(e);
      _notifySafe();
      debugPrint('清除 TTS 音色失败: $e');
    }
  }

  Future<void> _applyBestLanguage(FlutterTts tts) async {
    final locale = PlatformDispatcher.instance.locale;
    final deviceLocaleTag = _localeTag(locale);

    final candidates = <String>[
      _currentLanguage,
      if (deviceLocaleTag.isNotEmpty) deviceLocaleTag,
      if (locale.languageCode.isNotEmpty) locale.languageCode,
      'zh-CN',
      'zh_CN',
      'zh',
      'en-US',
      'en_US',
      'en',
    ];

    final tested = <String>{};
    for (final lang in candidates) {
      final value = lang.trim();
      if (value.isEmpty || !tested.add(value)) continue;
      if (await _trySetLanguage(tts, value)) {
        _currentLanguage = value;
        await _saveSettings();
        return;
      }
    }
  }

  String _localeTag(Locale locale) {
    if (locale.countryCode?.isNotEmpty ?? false) {
      return '${locale.languageCode}-${locale.countryCode}';
    }
    return locale.languageCode;
  }

  Future<bool> _trySetLanguage(FlutterTts tts, String language) async {
    try {
      final available = await tts.isLanguageAvailable(language);
      if (available == false) {
        return false;
      }
    } catch (_) {
      // 某些平台不支持 isLanguageAvailable，直接尝试设置。
    }

    try {
      await tts.setLanguage(language);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _safeSetSpeechRate(FlutterTts tts, double rate) async {
    try {
      await tts.setSpeechRate(rate.clamp(0.1, 1.0));
    } catch (e) {
      debugPrint('设置 TTS 语速失败: $e');
    }
  }

  Future<void> _safeSetVolume(FlutterTts tts, double volume) async {
    try {
      await tts.setVolume(volume.clamp(0.0, 1.0));
    } catch (e) {
      debugPrint('设置 TTS 音量失败: $e');
    }
  }

  Future<void> _safeSetPitch(FlutterTts tts, double pitch) async {
    try {
      await tts.setPitch(pitch.clamp(0.5, 2.0));
    } catch (e) {
      debugPrint('设置 TTS 音调失败: $e');
    }
  }

  Future<void> speak(String text) async {
    final content = text.trim();
    if (content.isEmpty) {
      return;
    }

    await initialize();
    final tts = _flutterTts;
    if (!_isInitialized || tts == null) {
      _lastError = _lastError ?? 'tts_unavailable';
      _notifySafe();
      return;
    }

    try {
      if (_isPlaying || _isPaused) {
        await tts.stop();
      }

      _currentText = content;
      _currentPosition = 0;
      _lastError = null;
      _notifySafe();

      await _applyCurrentVoiceIfNeeded(tts);
      await tts.speak(content);
    } catch (e) {
      _isPlaying = false;
      _isPaused = false;
      _lastError = _toErrorText(e);
      _notifySafe();
      debugPrint('TTS 播放失败: $e');
    }
  }

  Future<void> pause() async {
    final tts = _flutterTts;
    if (!_isInitialized || tts == null || !_isPlaying || _isPaused) {
      return;
    }

    try {
      await tts.pause();
      _isPlaying = false;
      _isPaused = true;
      _notifySafe();
    } catch (e) {
      _lastError = _toErrorText(e);
      _notifySafe();
      debugPrint('TTS 暂停失败: $e');
    }
  }

  Future<void> resume() async {
    final tts = _flutterTts;
    if (!_isInitialized || tts == null || !_isPaused) {
      return;
    }

    try {
      final fallbackText = _currentText;
      final startIndex = _currentPosition.clamp(0, fallbackText.length);
      final remainingText = startIndex < fallbackText.length
          ? fallbackText.substring(startIndex)
          : '';
      await _applyCurrentVoiceIfNeeded(tts);
      await tts.speak(remainingText.isEmpty ? fallbackText : remainingText);
      _isPlaying = true;
      _isPaused = false;
      _notifySafe();
    } catch (e) {
      _lastError = _toErrorText(e);
      _notifySafe();
      debugPrint('TTS 继续播放失败: $e');
    }
  }

  Future<void> stop() async {
    final tts = _flutterTts;
    if (tts == null) {
      return;
    }

    try {
      await tts.stop();
    } catch (e) {
      _lastError = _toErrorText(e);
      debugPrint('TTS 停止失败: $e');
    } finally {
      _isPlaying = false;
      _isPaused = false;
      _currentPosition = 0;
      _notifySafe();
    }
  }

  Future<void> setSpeechRate(double rate) async {
    _speechRate = rate.clamp(0.1, 1.0);
    final tts = _flutterTts;
    if (tts != null) {
      await _safeSetSpeechRate(tts, _speechRate);
    }
    _schedulePlaybackRefreshIfNeeded();
    await _saveSettings();
    _notifySafe();
  }

  Future<void> setVolume(double volume) async {
    _speechVolume = volume.clamp(0.0, 1.0);
    final tts = _flutterTts;
    if (tts != null) {
      await _safeSetVolume(tts, _speechVolume);
    }
    _schedulePlaybackRefreshIfNeeded();
    await _saveSettings();
    _notifySafe();
  }

  Future<void> setPitch(double pitch) async {
    _speechPitch = pitch.clamp(0.5, 2.0);
    final tts = _flutterTts;
    if (tts != null) {
      await _safeSetPitch(tts, _speechPitch);
    }
    _schedulePlaybackRefreshIfNeeded();
    await _saveSettings();
    _notifySafe();
  }

  void _schedulePlaybackRefreshIfNeeded() {
    _parameterApplyDebounceTimer?.cancel();
    if (!_isPlaying || _isPaused || _currentText.trim().isEmpty) {
      return;
    }
    _parameterApplyDebounceTimer = Timer(
      const Duration(milliseconds: 220),
      () => unawaited(_restartCurrentPlaybackWithLatestSettings()),
    );
  }

  Future<void> _restartCurrentPlaybackWithLatestSettings() async {
    final tts = _flutterTts;
    if (!_isInitialized ||
        tts == null ||
        !_isPlaying ||
        _isPaused ||
        _currentText.trim().isEmpty) {
      return;
    }

    final text = _currentText;
    final startIndex = _currentPosition.clamp(0, text.length);
    final remainingText = startIndex < text.length
        ? text.substring(startIndex).trimLeft()
        : '';
    final content = remainingText.isNotEmpty ? remainingText : text;
    try {
      await tts.stop();
      await _safeSetSpeechRate(tts, _speechRate);
      await _safeSetVolume(tts, _speechVolume);
      await _safeSetPitch(tts, _speechPitch);
      await _applyCurrentVoiceIfNeeded(tts);
      _currentText = content;
      _currentPosition = 0;
      await tts.speak(content);
    } catch (e) {
      _lastError = _toErrorText(e);
      _notifySafe();
      debugPrint('TTS 参数应用失败: $e');
    }
  }

  Future<void> setLanguage(String language) async {
    final normalized = language.trim();
    if (normalized.isEmpty) {
      return;
    }

    _currentLanguage = normalized;
    await _saveSettings();

    final tts = _flutterTts;
    if (!_isInitialized || tts == null) {
      return;
    }

    final success = await _trySetLanguage(tts, normalized);
    if (!success) {
      _lastError = 'tts_unsupported_language';
      _lastErrorLanguage = normalized;
    } else {
      if (_currentVoice != null &&
          !_currentVoice!.matchesLanguage(normalized)) {
        _currentVoice = null;
        await _saveSettings();
      }
      _lastError = null;
      _lastErrorLanguage = null;
    }
    _notifySafe();
  }

  double get playbackProgress {
    if (_currentText.isEmpty) return 0.0;
    return (_currentPosition / _currentText.length).clamp(0.0, 1.0);
  }

  Future<bool> isLanguageAvailable(String language) async {
    final tts = _flutterTts;
    if (!_isInitialized || tts == null) {
      return false;
    }

    try {
      final result = await tts.isLanguageAvailable(language);
      return result ?? false;
    } catch (e) {
      debugPrint('检查语言可用性失败: $e');
      return false;
    }
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _speechRate =
          (prefs.getDouble('tts_speech_rate') ??
                  prefs.getDouble('ttsSpeed') ??
                  0.5)
              .clamp(0.1, 1.0);
      _speechVolume =
          (prefs.getDouble('tts_speech_volume') ??
                  prefs.getDouble('ttsVolume') ??
                  1.0)
              .clamp(0.0, 1.0);
      _speechPitch =
          (prefs.getDouble('tts_speech_pitch') ??
                  prefs.getDouble('ttsPitch') ??
                  1.0)
              .clamp(0.5, 2.0);
      _currentLanguage = prefs.getString('tts_language') ?? 'zh-CN';
      final savedIdentifier = prefs.getString(_voiceIdentifierPrefKey)?.trim();
      final savedName = prefs.getString(_voiceNamePrefKey)?.trim() ?? '';
      final savedLocale =
          (prefs.getString(_voiceLocalePrefKey) ?? _currentLanguage).trim();
      if ((savedIdentifier?.isNotEmpty ?? false) ||
          savedName.isNotEmpty ||
          savedLocale.isNotEmpty) {
        _currentVoice = TtsVoiceOption(
          name: savedName,
          locale: savedLocale,
          identifier: savedIdentifier,
        );
      } else {
        _currentVoice = null;
      }
    } catch (e) {
      debugPrint('加载 TTS 设置失败: $e');
    }
  }

  Future<void> _saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('tts_speech_rate', _speechRate);
      await prefs.setDouble('tts_speech_volume', _speechVolume);
      await prefs.setDouble('tts_speech_pitch', _speechPitch);
      await prefs.setString('tts_language', _currentLanguage);

      // 兼容设置页旧键名，确保两处入口数据一致。
      await prefs.setDouble('ttsSpeed', _speechRate);
      await prefs.setDouble('ttsVolume', _speechVolume);
      await prefs.setDouble('ttsPitch', _speechPitch);

      final voice = _currentVoice;
      if (voice == null) {
        await prefs.remove(_voiceIdPrefKey);
        await prefs.remove(_voiceIdentifierPrefKey);
        await prefs.remove(_voiceNamePrefKey);
        await prefs.remove(_voiceLocalePrefKey);
      } else {
        await prefs.setString(_voiceIdPrefKey, voice.id);
        await prefs.setString(_voiceNamePrefKey, voice.name);
        await prefs.setString(
          _voiceLocalePrefKey,
          voice.normalizedLocale.isNotEmpty
              ? voice.normalizedLocale
              : _currentLanguage,
        );
        final identifier = voice.identifier?.trim();
        if (identifier != null && identifier.isNotEmpty) {
          await prefs.setString(_voiceIdentifierPrefKey, identifier);
        } else {
          await prefs.remove(_voiceIdentifierPrefKey);
        }
      }
    } catch (e) {
      debugPrint('保存 TTS 设置失败: $e');
    }
  }

  Future<void> _restoreSavedVoice(FlutterTts tts) async {
    final savedVoice = _currentVoice;
    if (savedVoice == null) {
      return;
    }

    try {
      await _applyVoiceToEngine(tts, savedVoice);
      _currentLanguage = savedVoice.normalizedLocale.isNotEmpty
          ? savedVoice.normalizedLocale
          : _currentLanguage;
    } catch (e) {
      debugPrint('恢复 TTS 音色失败: $e');
      _currentVoice = null;
    }
  }

  Future<void> _applyCurrentVoiceIfNeeded(FlutterTts tts) async {
    final voice = _currentVoice;
    if (voice != null) {
      await _applyVoiceToEngine(tts, voice);
      return;
    }
    if (_currentLanguage.trim().isNotEmpty) {
      await _trySetLanguage(tts, _currentLanguage);
    }
  }

  Future<void> _applyVoiceToEngine(FlutterTts tts, TtsVoiceOption voice) async {
    final locale = voice.normalizedLocale.isNotEmpty
        ? voice.normalizedLocale
        : _currentLanguage;
    if (locale.isNotEmpty) {
      await _trySetLanguage(tts, locale);
    }

    final identifier = voice.identifier?.trim();
    if (!kIsWeb &&
        defaultTargetPlatform == TargetPlatform.iOS &&
        identifier != null &&
        identifier.isNotEmpty) {
      await tts.setVoice(<String, String>{'identifier': identifier});
      return;
    }

    final payload = <String, String>{};
    final name = voice.name.trim();
    if (name.isNotEmpty) {
      payload['name'] = name;
    }
    if (locale.isNotEmpty) {
      payload['locale'] = locale;
    }
    if (payload.isNotEmpty) {
      await tts.setVoice(payload);
    }
  }

  Future<List<TtsVoiceOption>> _loadVoicesFromEngine(FlutterTts tts) async {
    final raw = await tts.getVoices;
    if (raw is! Iterable) {
      return const <TtsVoiceOption>[];
    }

    final deduped = <String, TtsVoiceOption>{};
    for (final item in raw) {
      if (item is! Map) {
        continue;
      }
      final voice = TtsVoiceOption.fromMap(item);
      if (voice.name.trim().isEmpty && voice.locale.trim().isEmpty) {
        continue;
      }

      final existing = deduped[voice.id];
      if (existing == null || _compareVoicePriority(voice, existing) < 0) {
        deduped[voice.id] = voice;
      }
    }

    final voices = deduped.values.toList(growable: false);
    voices.sort(_compareVoicePriority);
    return voices;
  }

  TtsVoiceOption? _syncVoiceWithAvailableList(
    TtsVoiceOption? current,
    List<TtsVoiceOption> voices,
  ) {
    if (current == null) {
      return null;
    }

    for (final voice in voices) {
      if (voice == current) {
        return voice;
      }
    }

    for (final voice in voices) {
      if (voice.name == current.name &&
          voice.normalizedLocale == current.normalizedLocale) {
        return voice;
      }
    }

    return current;
  }

  int _compareVoicePriority(TtsVoiceOption left, TtsVoiceOption right) {
    final languageScoreDiff = _languageMatchScore(
      left,
    ).compareTo(_languageMatchScore(right));
    if (languageScoreDiff != 0) {
      return languageScoreDiff;
    }

    final qualityDiff = _voiceQualityRank(
      left.quality,
    ).compareTo(_voiceQualityRank(right.quality));
    if (qualityDiff != 0) {
      return qualityDiff;
    }

    final localeDiff = left.normalizedLocale.toLowerCase().compareTo(
      right.normalizedLocale.toLowerCase(),
    );
    if (localeDiff != 0) {
      return localeDiff;
    }

    return left.title.toLowerCase().compareTo(right.title.toLowerCase());
  }

  int _languageMatchScore(TtsVoiceOption voice) {
    if (voice.matchesLocale(_currentLanguage)) {
      return 0;
    }
    if (voice.matchesLanguage(_currentLanguage)) {
      return 1;
    }
    return 2;
  }

  int _voiceQualityRank(String? quality) {
    switch (quality?.trim().toLowerCase()) {
      case 'premium':
        return 0;
      case 'enhanced':
        return 1;
      case 'default':
        return 2;
      default:
        return 3;
    }
  }

  String _toErrorText(Object error) {
    final raw = error.toString().trim();
    if (raw.isEmpty) return 'tts_call_failed';
    return raw.length > 220 ? raw.substring(0, 220) : raw;
  }

  void _notifySafe() {
    if (_isDisposed) return;
    notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _parameterApplyDebounceTimer?.cancel();
    _parameterApplyDebounceTimer = null;
    final tts = _flutterTts;
    _flutterTts = null;
    _initializationFuture = null;
    if (tts != null) {
      unawaited(tts.stop());
    }
    super.dispose();
  }
}
