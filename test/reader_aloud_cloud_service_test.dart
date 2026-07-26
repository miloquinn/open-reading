import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xxread/core/reader/reader_aloud_controller.dart';
import 'package:xxread/services/reader_aloud_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('cloud endpoint requires HTTPS except for localhost', () {
    expect(
      () => readerAloudCloudEndpoint('http://tts.example.com/v1'),
      throwsA(
        isA<ReaderAloudCloudException>().having(
          (error) => error.code,
          'code',
          'insecure_base_url',
        ),
      ),
    );
    expect(
      readerAloudCloudEndpoint('http://localhost:8080/v1/audio/speech'),
      Uri.parse('http://localhost:8080/v1/audio/speech'),
    );
  });

  test('API key is stored separately from non-secret preferences', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final secrets = _FakeSecretStorage();
    final store = PreferencesReaderAloudCloudSettingsStore(
      preferences: preferences,
      secretStorage: secrets,
    );

    await store.saveSettings(
      const ReaderAloudCloudSettings(
        baseUrl: 'https://tts.example.com/v1/',
        model: 'voice-model',
        voice: 'reader',
      ),
    );
    await store.writeApiKey(' secret-key ');

    expect(await store.readApiKey(), 'secret-key');
    expect(secrets.values.values, contains('secret-key'));
    expect(
      preferences.getKeys(),
      isNot(contains('reader_aloud_cloud_api_key')),
    );
    expect((await store.loadSettings()).baseUrl, 'https://tts.example.com/v1');
  });

  test(
    'OpenAI-compatible client sends bounded authenticated audio request',
    () async {
      late RequestOptions request;
      final dio = Dio()
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              request = options;
              handler.resolve(
                Response<ResponseBody>(
                  requestOptions: options,
                  statusCode: 200,
                  data: ResponseBody.fromBytes([1, 2, 3], 200),
                ),
              );
            },
          ),
        );
      final client = OpenAiCompatibleReaderAloudCloudClient(
        dio: dio,
        maxResponseBytes: 8,
      );

      final bytes = await client.synthesize(
        settings: const ReaderAloudCloudSettings(
          baseUrl: 'https://tts.example.com/v1',
          model: 'voice-model',
          voice: 'reader',
        ),
        apiKey: 'secret',
        text: '你好。',
        speed: 1,
      );

      expect(bytes, [1, 2, 3]);
      expect(request.uri.path, '/v1/audio/speech');
      expect(request.headers['Authorization'], 'Bearer secret');
      expect(request.data, containsPair('input', '你好。'));
      expect(request.responseType, ResponseType.stream);
      expect(request.followRedirects, isFalse);
    },
  );

  test('cloud audio is cached and reused for the same sentence', () async {
    final system = _FakeSystemEngine();
    final client = _FakeCloudClient();
    final player = _FakeBytesPlayer();
    final service = ReaderAloudService(
      systemEngine: system,
      settingsStore: _FakeSettingsStore(),
      cloudClient: client,
      bytesPlayer: player,
    );
    addTearDown(service.dispose);

    await service.setEngineType(ReaderAloudEngineType.cloud);
    await service.speak('同一句。');
    await service.speak('同一句。');

    expect(client.calls, 1);
    expect(player.played, 2);
    expect(system.spoken, isEmpty);
  });

  test('changed speech rate produces fresh cloud audio immediately', () async {
    final system = _FakeSystemEngine();
    final client = _FakeCloudClient();
    final service = ReaderAloudService(
      systemEngine: system,
      settingsStore: _FakeSettingsStore(),
      cloudClient: client,
      bytesPlayer: _FakeBytesPlayer(),
    );
    addTearDown(service.dispose);

    await service.setEngineType(ReaderAloudEngineType.cloud);
    await service.speak('调速句子。');
    system.speechRateValue = 0.8;
    await service.speak('调速句子。');

    expect(client.calls, 2);
    expect(client.speeds, [1.0, 1.6]);
  });

  test('cloud failure falls back to the system engine when enabled', () async {
    final system = _FakeSystemEngine();
    final service = ReaderAloudService(
      systemEngine: system,
      settingsStore: _FakeSettingsStore(),
      cloudClient: _FakeCloudClient(fail: true),
      bytesPlayer: _FakeBytesPlayer(),
    );
    addTearDown(service.dispose);

    await service.setEngineType(ReaderAloudEngineType.cloud);
    await service.speak('回退句子。');

    expect(system.spoken, ['回退句子。']);
    expect(service.activeEngineType, ReaderAloudEngineType.system);
    expect(service.cloudError, isNotNull);
  });

  test('stopping during cloud synthesis never starts stale audio', () async {
    final system = _FakeSystemEngine();
    final client = _PendingCloudClient();
    final player = _FakeBytesPlayer();
    final service = ReaderAloudService(
      systemEngine: system,
      settingsStore: _FakeSettingsStore(),
      cloudClient: client,
      bytesPlayer: player,
    );
    addTearDown(service.dispose);

    await service.setEngineType(ReaderAloudEngineType.cloud);
    final speaking = service.speak('取消的句子。');
    await client.started.future;
    await service.stop();
    client.complete();
    await speaking;

    expect(player.played, 0);
    expect(system.spoken, isEmpty);
  });
}

class _FakeSecretStorage implements ReaderAloudSecretStorage {
  final Map<String, String> values = {};

  @override
  Future<void> delete(String key) async => values.remove(key);

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;
}

class _FakeSettingsStore implements ReaderAloudCloudSettingsStore {
  ReaderAloudEngineType type = ReaderAloudEngineType.system;
  ReaderAloudCloudSettings settings = const ReaderAloudCloudSettings();
  String? apiKey = 'test-key';

  @override
  Future<void> clearApiKey() async => apiKey = null;

  @override
  Future<String?> readApiKey() async => apiKey;

  @override
  Future<ReaderAloudEngineType> loadEngineType() async => type;

  @override
  Future<ReaderAloudCloudSettings> loadSettings() async => settings;

  @override
  Future<void> saveEngineType(ReaderAloudEngineType type) async {
    this.type = type;
  }

  @override
  Future<void> saveSettings(ReaderAloudCloudSettings settings) async {
    this.settings = settings;
  }

  @override
  Future<void> writeApiKey(String apiKey) async => this.apiKey = apiKey;
}

class _FakeCloudClient implements ReaderAloudCloudClient {
  _FakeCloudClient({this.fail = false});

  final bool fail;
  int calls = 0;
  final List<double> speeds = [];

  @override
  Future<Uint8List> synthesize({
    required ReaderAloudCloudSettings settings,
    required String apiKey,
    required String text,
    required double speed,
  }) async {
    calls++;
    speeds.add(speed);
    if (fail) {
      throw const ReaderAloudCloudException('failed', '云端失败');
    }
    return Uint8List.fromList([1, 2, 3]);
  }
}

class _PendingCloudClient implements ReaderAloudCloudClient {
  final Completer<void> started = Completer<void>();
  final Completer<Uint8List> _result = Completer<Uint8List>();

  void complete() => _result.complete(Uint8List.fromList([1, 2, 3]));

  @override
  Future<Uint8List> synthesize({
    required ReaderAloudCloudSettings settings,
    required String apiKey,
    required String text,
    required double speed,
  }) {
    started.complete();
    return _result.future;
  }
}

class _FakeBytesPlayer extends ChangeNotifier
    implements ReaderAloudBytesPlayer {
  int played = 0;

  @override
  Duration get duration => const Duration(seconds: 1);

  @override
  bool get isPaused => false;

  @override
  bool get isPlaying => false;

  @override
  Duration get position => duration;

  @override
  Future<void> pause() async {}

  @override
  Future<void> play(
    Uint8List bytes, {
    required String mimeType,
    required double volume,
  }) async {
    played++;
  }

  @override
  Future<void> setVolume(double volume) async {}

  @override
  Future<void> stop() async {}
}

class _FakeSystemEngine extends ChangeNotifier
    implements ReaderAloudAdjustableEngine {
  final List<String> spoken = [];
  double speechRateValue = 0.5;

  @override
  int get currentPosition => 0;

  @override
  bool get isPaused => false;

  @override
  bool get isPlaying => false;

  @override
  double get speechRate => speechRateValue;

  @override
  double get speechVolume => 1;

  @override
  Future<void> pause() async {}

  @override
  Future<void> speak(String text) async => spoken.add(text);

  @override
  Future<void> stop() async {}
}
