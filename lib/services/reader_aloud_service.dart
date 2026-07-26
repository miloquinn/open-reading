import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/reader/reader_aloud_controller.dart';

enum ReaderAloudEngineType { system, cloud }

@immutable
class ReaderAloudCloudSettings {
  const ReaderAloudCloudSettings({
    this.baseUrl = 'https://api.openai.com/v1',
    this.model = 'gpt-4o-mini-tts',
    this.voice = 'alloy',
    this.responseFormat = 'mp3',
    this.fallbackToSystem = true,
  });

  final String baseUrl;
  final String model;
  final String voice;
  final String responseFormat;
  final bool fallbackToSystem;

  ReaderAloudCloudSettings copyWith({
    String? baseUrl,
    String? model,
    String? voice,
    String? responseFormat,
    bool? fallbackToSystem,
  }) => ReaderAloudCloudSettings(
    baseUrl: baseUrl ?? this.baseUrl,
    model: model ?? this.model,
    voice: voice ?? this.voice,
    responseFormat: responseFormat ?? this.responseFormat,
    fallbackToSystem: fallbackToSystem ?? this.fallbackToSystem,
  );

  ReaderAloudCloudSettings normalized() => copyWith(
    baseUrl: normalizeReaderAloudCloudBaseUrl(baseUrl),
    model: model.trim(),
    voice: voice.trim(),
    responseFormat: responseFormat.trim().toLowerCase(),
  );
}

String normalizeReaderAloudCloudBaseUrl(String value) {
  var normalized = value.trim();
  while (normalized.endsWith('/')) {
    normalized = normalized.substring(0, normalized.length - 1);
  }
  const suffix = '/audio/speech';
  if (normalized.toLowerCase().endsWith(suffix)) {
    normalized = normalized.substring(0, normalized.length - suffix.length);
  }
  return normalized;
}

Uri readerAloudCloudEndpoint(String baseUrl) {
  final normalized = normalizeReaderAloudCloudBaseUrl(baseUrl);
  final uri = Uri.tryParse(normalized);
  if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
    throw const ReaderAloudCloudException(
      'invalid_base_url',
      '请输入有效的 TTS API 地址',
    );
  }
  if (uri.userInfo.isNotEmpty || uri.hasFragment || uri.hasQuery) {
    throw const ReaderAloudCloudException(
      'invalid_base_url',
      'TTS API 地址不能包含账号、查询参数或片段',
    );
  }
  final localhost =
      uri.host == 'localhost' || uri.host == '127.0.0.1' || uri.host == '::1';
  if (uri.scheme != 'https' && !(uri.scheme == 'http' && localhost)) {
    throw const ReaderAloudCloudException(
      'insecure_base_url',
      'TTS API 必须使用 HTTPS（本机调试除外）',
    );
  }
  return uri.replace(
    path:
        '${uri.path.endsWith('/') ? uri.path.substring(0, uri.path.length - 1) : uri.path}/audio/speech',
  );
}

void validateReaderAloudCloudSettings(ReaderAloudCloudSettings settings) {
  readerAloudCloudEndpoint(settings.baseUrl);
  if (settings.model.trim().isEmpty) {
    throw const ReaderAloudCloudException('missing_model', '请填写 TTS 模型');
  }
  if (settings.voice.trim().isEmpty) {
    throw const ReaderAloudCloudException('missing_voice', '请填写 TTS 音色');
  }
  const supportedFormats = {'mp3', 'opus', 'aac', 'flac', 'wav', 'pcm'};
  if (!supportedFormats.contains(settings.responseFormat.toLowerCase())) {
    throw const ReaderAloudCloudException(
      'unsupported_format',
      '不支持的 TTS 音频格式',
    );
  }
}

class ReaderAloudCloudException implements Exception {
  const ReaderAloudCloudException(this.code, this.message, {this.statusCode});

  final String code;
  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

abstract interface class ReaderAloudSecretStorage {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class FlutterReaderAloudSecretStorage implements ReaderAloudSecretStorage {
  const FlutterReaderAloudSecretStorage({
    this.storage = const FlutterSecureStorage(),
  });

  final FlutterSecureStorage storage;

  @override
  Future<void> delete(String key) => storage.delete(key: key);

  @override
  Future<String?> read(String key) => storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      storage.write(key: key, value: value);
}

abstract interface class ReaderAloudCloudSettingsStore {
  Future<ReaderAloudEngineType> loadEngineType();
  Future<void> saveEngineType(ReaderAloudEngineType type);
  Future<ReaderAloudCloudSettings> loadSettings();
  Future<void> saveSettings(ReaderAloudCloudSettings settings);
  Future<String?> readApiKey();
  Future<void> writeApiKey(String apiKey);
  Future<void> clearApiKey();
}

class PreferencesReaderAloudCloudSettingsStore
    implements ReaderAloudCloudSettingsStore {
  factory PreferencesReaderAloudCloudSettingsStore({
    SharedPreferences? preferences,
    ReaderAloudSecretStorage secretStorage =
        const FlutterReaderAloudSecretStorage(),
  }) => PreferencesReaderAloudCloudSettingsStore._(preferences, secretStorage);

  PreferencesReaderAloudCloudSettingsStore._(
    this._preferences,
    this._secretStorage,
  );

  static const _engineKey = 'reader_aloud_engine';
  static const _baseUrlKey = 'reader_aloud_cloud_base_url';
  static const _modelKey = 'reader_aloud_cloud_model';
  static const _voiceKey = 'reader_aloud_cloud_voice';
  static const _formatKey = 'reader_aloud_cloud_format';
  static const _fallbackKey = 'reader_aloud_cloud_fallback';
  static const _apiKeyKey = 'reader_aloud_cloud_api_key';

  final SharedPreferences? _preferences;
  final ReaderAloudSecretStorage _secretStorage;

  Future<SharedPreferences> get _prefs async =>
      _preferences ?? SharedPreferences.getInstance();

  @override
  Future<void> clearApiKey() => _secretStorage.delete(_apiKeyKey);

  @override
  Future<ReaderAloudEngineType> loadEngineType() async {
    final raw = (await _prefs).getString(_engineKey);
    return raw == ReaderAloudEngineType.cloud.name
        ? ReaderAloudEngineType.cloud
        : ReaderAloudEngineType.system;
  }

  @override
  Future<ReaderAloudCloudSettings> loadSettings() async {
    final prefs = await _prefs;
    return ReaderAloudCloudSettings(
      baseUrl: prefs.getString(_baseUrlKey) ?? 'https://api.openai.com/v1',
      model: prefs.getString(_modelKey) ?? 'gpt-4o-mini-tts',
      voice: prefs.getString(_voiceKey) ?? 'alloy',
      responseFormat: prefs.getString(_formatKey) ?? 'mp3',
      fallbackToSystem: prefs.getBool(_fallbackKey) ?? true,
    ).normalized();
  }

  @override
  Future<String?> readApiKey() async {
    final value = await _secretStorage.read(_apiKeyKey);
    final normalized = value?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }

  @override
  Future<void> saveEngineType(ReaderAloudEngineType type) async {
    await (await _prefs).setString(_engineKey, type.name);
  }

  @override
  Future<void> saveSettings(ReaderAloudCloudSettings settings) async {
    final normalized = settings.normalized();
    validateReaderAloudCloudSettings(normalized);
    final prefs = await _prefs;
    await prefs.setString(_baseUrlKey, normalized.baseUrl);
    await prefs.setString(_modelKey, normalized.model);
    await prefs.setString(_voiceKey, normalized.voice);
    await prefs.setString(_formatKey, normalized.responseFormat);
    await prefs.setBool(_fallbackKey, normalized.fallbackToSystem);
  }

  @override
  Future<void> writeApiKey(String apiKey) async {
    final normalized = apiKey.trim();
    if (normalized.isEmpty) {
      await clearApiKey();
      return;
    }
    await _secretStorage.write(_apiKeyKey, normalized);
  }
}

abstract interface class ReaderAloudCloudClient {
  Future<Uint8List> synthesize({
    required ReaderAloudCloudSettings settings,
    required String apiKey,
    required String text,
    required double speed,
  });
}

class OpenAiCompatibleReaderAloudCloudClient implements ReaderAloudCloudClient {
  OpenAiCompatibleReaderAloudCloudClient({
    Dio? dio,
    this.maxResponseBytes = 12 * 1024 * 1024,
    this.maxInputCharacters = 4096,
  }) : _dio =
           dio ??
           Dio(
             BaseOptions(
               connectTimeout: const Duration(seconds: 20),
               sendTimeout: const Duration(seconds: 30),
               receiveTimeout: const Duration(seconds: 90),
             ),
           );

  final Dio _dio;
  final int maxResponseBytes;
  final int maxInputCharacters;

  @override
  Future<Uint8List> synthesize({
    required ReaderAloudCloudSettings settings,
    required String apiKey,
    required String text,
    required double speed,
  }) async {
    final normalizedSettings = settings.normalized();
    validateReaderAloudCloudSettings(normalizedSettings);
    final normalizedKey = apiKey.trim();
    if (normalizedKey.isEmpty) {
      throw const ReaderAloudCloudException(
        'missing_api_key',
        '请先配置 TTS API Key',
      );
    }
    final input = text.trim();
    if (input.isEmpty) return Uint8List(0);
    if (input.length > maxInputCharacters) {
      throw const ReaderAloudCloudException('input_too_long', 'TTS 文本超过单次请求限制');
    }

    try {
      final response = await _dio.post<ResponseBody>(
        readerAloudCloudEndpoint(normalizedSettings.baseUrl).toString(),
        data: <String, Object>{
          'model': normalizedSettings.model,
          'input': input,
          'voice': normalizedSettings.voice,
          'response_format': normalizedSettings.responseFormat,
          'speed': speed.clamp(0.25, 4.0),
        },
        options: Options(
          responseType: ResponseType.stream,
          followRedirects: false,
          headers: <String, String>{
            'Authorization': 'Bearer $normalizedKey',
            Headers.contentTypeHeader: Headers.jsonContentType,
            Headers.acceptHeader: 'audio/*, application/octet-stream',
          },
        ),
      );
      final contentLength = int.tryParse(
        response.headers.value(Headers.contentLengthHeader) ?? '',
      );
      if (contentLength != null && contentLength > maxResponseBytes) {
        throw const ReaderAloudCloudException(
          'response_too_large',
          'TTS 音频响应过大',
        );
      }
      final contentType = response.headers
          .value(Headers.contentTypeHeader)
          ?.toLowerCase();
      if (contentType != null &&
          contentType.isNotEmpty &&
          !contentType.startsWith('audio/') &&
          !contentType.startsWith('application/octet-stream')) {
        throw const ReaderAloudCloudException(
          'invalid_audio_response',
          'TTS API 未返回音频数据',
        );
      }
      final body = response.data;
      if (body == null) {
        throw const ReaderAloudCloudException(
          'empty_response',
          'TTS API 返回了空音频',
        );
      }
      final builder = BytesBuilder(copy: false);
      var received = 0;
      await for (final chunk in body.stream) {
        received += chunk.length;
        if (received > maxResponseBytes) {
          throw const ReaderAloudCloudException(
            'response_too_large',
            'TTS 音频响应过大',
          );
        }
        builder.add(chunk);
      }
      final data = builder.takeBytes();
      if (data.isEmpty) {
        throw const ReaderAloudCloudException(
          'empty_response',
          'TTS API 返回了空音频',
        );
      }
      return data;
    } on ReaderAloudCloudException {
      rethrow;
    } on DioException catch (error) {
      final statusCode = error.response?.statusCode;
      final message = switch (statusCode) {
        401 || 403 => 'TTS API 鉴权失败，请检查 API Key',
        429 => 'TTS API 请求过于频繁，请稍后再试',
        int code when code >= 500 => 'TTS 服务暂时不可用',
        _ => 'TTS API 请求失败',
      };
      throw ReaderAloudCloudException(
        'request_failed',
        message,
        statusCode: statusCode,
      );
    }
  }
}

class ReaderAloudCloudAudioCache {
  ReaderAloudCloudAudioCache({
    this.maximumEntries = 20,
    this.maximumBytes = 32 * 1024 * 1024,
  });

  final int maximumEntries;
  final int maximumBytes;
  final Map<String, Uint8List> _entries = <String, Uint8List>{};
  int _bytes = 0;

  Uint8List? read(String key) {
    final value = _entries.remove(key);
    if (value == null) return null;
    _entries[key] = value;
    return value;
  }

  void write(String key, Uint8List value) {
    if (value.isEmpty || value.length > maximumBytes) return;
    final previous = _entries.remove(key);
    if (previous != null) _bytes -= previous.length;
    _entries[key] = value;
    _bytes += value.length;
    while (_entries.length > maximumEntries || _bytes > maximumBytes) {
      final oldestKey = _entries.keys.first;
      final removed = _entries.remove(oldestKey);
      if (removed != null) _bytes -= removed.length;
    }
  }

  String keyFor({
    required ReaderAloudCloudSettings settings,
    required String text,
    required double speed,
  }) => sha256
      .convert(
        utf8.encode(
          '${settings.baseUrl}\n${settings.model}\n${settings.voice}\n'
          '${settings.responseFormat}\n${speed.toStringAsFixed(3)}\n$text',
        ),
      )
      .toString();
}

abstract interface class ReaderAloudBytesPlayer implements Listenable {
  bool get isPlaying;
  bool get isPaused;
  Duration get position;
  Duration get duration;

  Future<void> play(
    Uint8List bytes, {
    required String mimeType,
    required double volume,
  });
  Future<void> pause();
  Future<void> stop();
  Future<void> setVolume(double volume);
  void dispose();
}

class AudioplayersReaderAloudBytesPlayer extends ChangeNotifier
    implements ReaderAloudBytesPlayer {
  AudioplayersReaderAloudBytesPlayer({AudioPlayer? player})
    : _player = player ?? AudioPlayer() {
    _subscriptions.addAll([
      _player.onPositionChanged.listen((value) {
        _position = value;
        notifyListeners();
      }),
      _player.onDurationChanged.listen((value) {
        _duration = value;
        notifyListeners();
      }),
      _player.onPlayerComplete.listen((_) {
        _position = _duration;
        _isPlaying = false;
        _isPaused = false;
        _completeActivePlayback();
        notifyListeners();
      }),
    ]);
  }

  final AudioPlayer _player;
  final List<StreamSubscription<Object?>> _subscriptions = [];
  Completer<void>? _activePlayback;
  bool _isPlaying = false;
  bool _isPaused = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _disposed = false;

  @override
  Duration get duration => _duration;
  @override
  bool get isPaused => _isPaused;
  @override
  bool get isPlaying => _isPlaying;
  @override
  Duration get position => _position;

  @override
  Future<void> play(
    Uint8List bytes, {
    required String mimeType,
    required double volume,
  }) async {
    if (_disposed) return;
    await stop();
    final completer = Completer<void>();
    _activePlayback = completer;
    _position = Duration.zero;
    _duration = Duration.zero;
    _isPlaying = true;
    _isPaused = false;
    notifyListeners();
    try {
      await _player.play(
        BytesSource(bytes, mimeType: mimeType),
        volume: volume.clamp(0.0, 1.0),
      );
      await completer.future;
    } catch (error, stackTrace) {
      _isPlaying = false;
      _isPaused = false;
      _completeActivePlayback();
      notifyListeners();
      Error.throwWithStackTrace(error, stackTrace);
    } finally {
      if (identical(_activePlayback, completer)) _activePlayback = null;
    }
  }

  @override
  Future<void> pause() async {
    if (!_isPlaying || _disposed) return;
    await _player.pause();
    _isPlaying = false;
    _isPaused = true;
    _completeActivePlayback();
    notifyListeners();
  }

  @override
  Future<void> setVolume(double volume) =>
      _player.setVolume(volume.clamp(0.0, 1.0));

  @override
  Future<void> stop() async {
    if (_disposed) return;
    _completeActivePlayback();
    await _player.stop();
    _isPlaying = false;
    _isPaused = false;
    _position = Duration.zero;
    _duration = Duration.zero;
    notifyListeners();
  }

  void _completeActivePlayback() {
    final active = _activePlayback;
    if (active != null && !active.isCompleted) active.complete();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _completeActivePlayback();
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    unawaited(_player.dispose());
    super.dispose();
  }
}

class ReaderAloudService extends ChangeNotifier implements ReaderAloudEngine {
  ReaderAloudService({
    required this.systemEngine,
    ReaderAloudCloudSettingsStore? settingsStore,
    ReaderAloudCloudClient? cloudClient,
    ReaderAloudBytesPlayer? bytesPlayer,
    ReaderAloudCloudAudioCache? cache,
  }) : _settingsStore =
           settingsStore ?? PreferencesReaderAloudCloudSettingsStore(),
       _cloudClient = cloudClient ?? OpenAiCompatibleReaderAloudCloudClient(),
       _bytesPlayer = bytesPlayer ?? AudioplayersReaderAloudBytesPlayer(),
       _cache = cache ?? ReaderAloudCloudAudioCache() {
    systemEngine.addListener(_relayEngineChange);
    _bytesPlayer.addListener(_relayEngineChange);
    unawaited(initialize());
  }

  final ReaderAloudAdjustableEngine systemEngine;
  final ReaderAloudCloudSettingsStore _settingsStore;
  final ReaderAloudCloudClient _cloudClient;
  final ReaderAloudBytesPlayer _bytesPlayer;
  final ReaderAloudCloudAudioCache _cache;

  ReaderAloudEngineType _engineType = ReaderAloudEngineType.system;
  ReaderAloudEngineType _activeEngineType = ReaderAloudEngineType.system;
  ReaderAloudCloudSettings _cloudSettings = const ReaderAloudCloudSettings();
  Future<void>? _initialization;
  bool _initialized = false;
  bool _hasCloudApiKey = false;
  String _currentCloudText = '';
  String? _cloudError;
  bool _disposed = false;
  int _operationGeneration = 0;

  ReaderAloudEngineType get engineType => _engineType;
  ReaderAloudEngineType get activeEngineType => _activeEngineType;
  ReaderAloudCloudSettings get cloudSettings => _cloudSettings;
  bool get hasCloudApiKey => _hasCloudApiKey;
  String? get cloudError => _cloudError;
  bool get usesCloud => _engineType == ReaderAloudEngineType.cloud;

  @override
  int get currentPosition {
    if (_activeEngineType == ReaderAloudEngineType.system) {
      return systemEngine.currentPosition;
    }
    final durationMs = _bytesPlayer.duration.inMilliseconds;
    if (durationMs <= 0 || _currentCloudText.isEmpty) return 0;
    return (_currentCloudText.length *
            _bytesPlayer.position.inMilliseconds /
            durationMs)
        .round()
        .clamp(0, _currentCloudText.length);
  }

  @override
  bool get isPaused => _activeEngineType == ReaderAloudEngineType.system
      ? systemEngine.isPaused
      : _bytesPlayer.isPaused;

  @override
  bool get isPlaying => _activeEngineType == ReaderAloudEngineType.system
      ? systemEngine.isPlaying
      : _bytesPlayer.isPlaying;

  Future<void> initialize() {
    if (_initialized) return Future.value();
    final pending = _initialization;
    if (pending != null) return pending;
    final future = _loadSettings();
    _initialization = future;
    return future;
  }

  Future<void> _loadSettings() async {
    try {
      _engineType = await _settingsStore.loadEngineType();
      _cloudSettings = await _settingsStore.loadSettings();
      try {
        _hasCloudApiKey = (await _settingsStore.readApiKey()) != null;
      } catch (_) {
        _hasCloudApiKey = false;
        _cloudError = '无法访问系统安全存储';
      }
    } catch (_) {
      _engineType = ReaderAloudEngineType.system;
      _cloudSettings = const ReaderAloudCloudSettings();
      _hasCloudApiKey = false;
      _cloudError = '无法加载云端 TTS 设置';
    } finally {
      _initialized = true;
      _initialization = null;
      _notifySafe();
    }
  }

  Future<void> setEngineType(ReaderAloudEngineType value) async {
    await initialize();
    if (_engineType == value) return;
    await stop();
    _engineType = value;
    _activeEngineType = value;
    _cloudError = null;
    await _settingsStore.saveEngineType(value);
    _notifySafe();
  }

  Future<void> updateCloudSettings(ReaderAloudCloudSettings settings) async {
    final normalized = settings.normalized();
    validateReaderAloudCloudSettings(normalized);
    await _settingsStore.saveSettings(normalized);
    _cloudSettings = normalized;
    _cloudError = null;
    _notifySafe();
  }

  Future<void> saveCloudApiKey(String apiKey) async {
    final normalized = apiKey.trim();
    await _settingsStore.writeApiKey(normalized);
    _hasCloudApiKey = normalized.isNotEmpty;
    _cloudError = null;
    _notifySafe();
  }

  Future<void> clearCloudApiKey() async {
    await _settingsStore.clearApiKey();
    _hasCloudApiKey = false;
    _notifySafe();
  }

  @override
  Future<void> speak(String text) async {
    await initialize();
    final operation = ++_operationGeneration;
    if (_engineType == ReaderAloudEngineType.system) {
      _activeEngineType = ReaderAloudEngineType.system;
      await systemEngine.speak(text);
      return;
    }

    try {
      final apiKey = await _settingsStore.readApiKey();
      if (apiKey == null) {
        throw const ReaderAloudCloudException(
          'missing_api_key',
          '请先配置 TTS API Key',
        );
      }
      validateReaderAloudCloudSettings(_cloudSettings);
      _activeEngineType = ReaderAloudEngineType.cloud;
      _currentCloudText = text;
      _cloudError = null;
      final cloudSpeed = (systemEngine.speechRate * 2).clamp(0.25, 2.0);
      final cacheKey = _cache.keyFor(
        settings: _cloudSettings,
        text: text,
        speed: cloudSpeed,
      );
      var audio = _cache.read(cacheKey);
      audio ??= await _cloudClient.synthesize(
        settings: _cloudSettings,
        apiKey: apiKey,
        text: text,
        speed: cloudSpeed,
      );
      if (!_isCurrentOperation(operation)) return;
      _cache.write(cacheKey, audio);
      await _bytesPlayer.play(
        audio,
        mimeType: _mimeTypeFor(_cloudSettings.responseFormat),
        volume: systemEngine.speechVolume,
      );
    } catch (error, stackTrace) {
      if (!_isCurrentOperation(operation)) return;
      _cloudError = error is ReaderAloudCloudException
          ? error.message
          : 'TTS 云端播放失败';
      _notifySafe();
      if (_cloudSettings.fallbackToSystem) {
        _activeEngineType = ReaderAloudEngineType.system;
        await systemEngine.speak(text);
        return;
      }
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  @override
  Future<void> pause() async {
    _operationGeneration++;
    if (_activeEngineType == ReaderAloudEngineType.system) {
      await systemEngine.pause();
    } else {
      await _bytesPlayer.pause();
    }
  }

  @override
  Future<void> stop() async {
    _operationGeneration++;
    await Future.wait<void>([systemEngine.stop(), _bytesPlayer.stop()]);
    _currentCloudText = '';
    _activeEngineType = _engineType;
    _notifySafe();
  }

  Future<void> syncVolume() =>
      _bytesPlayer.setVolume(systemEngine.speechVolume);

  String _mimeTypeFor(String responseFormat) => switch (responseFormat) {
    'opus' => 'audio/opus',
    'aac' => 'audio/aac',
    'flac' => 'audio/flac',
    'wav' => 'audio/wav',
    'pcm' => 'audio/pcm',
    _ => 'audio/mpeg',
  };

  void _relayEngineChange() => _notifySafe();

  bool _isCurrentOperation(int operation) =>
      !_disposed && operation == _operationGeneration;

  void _notifySafe() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _operationGeneration++;
    systemEngine.removeListener(_relayEngineChange);
    _bytesPlayer.removeListener(_relayEngineChange);
    _bytesPlayer.dispose();
    super.dispose();
  }
}
