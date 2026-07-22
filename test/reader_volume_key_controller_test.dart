import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xxread/core/reader/reader_volume_key_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.niki.xxread/reader_keys');
  final calls = <MethodCall>[];
  late Object owner;

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    SharedPreferences.setMockInitialValues({});
    calls.clear();
    owner = Object();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return null;
        });
  });

  tearDown(() async {
    await ReaderVolumeKeyController.deactivate(owner);
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('routes Android volume keys when paging is enabled', () async {
    var nextCount = 0;
    var previousCount = 0;

    final enabled = await ReaderVolumeKeyController.activate(
      owner: owner,
      pageTurningAvailable: true,
      onNextPage: () => nextCount++,
      onPreviousPage: () => previousCount++,
    );

    expect(enabled, isTrue);
    expect(calls.single.method, 'setVolumePagingEnabled');
    expect(calls.single.arguments, {'enabled': true});

    await _sendPlatformCall(
      channel,
      const MethodCall('onVolumeKey', {'direction': 'next'}),
    );
    await _sendPlatformCall(
      channel,
      const MethodCall('onVolumeKey', {'direction': 'previous'}),
    );

    expect(nextCount, 1);
    expect(previousCount, 1);
  });

  test('does not intercept volume keys in vertical scroll mode', () async {
    final enabled = await ReaderVolumeKeyController.activate(
      owner: owner,
      pageTurningAvailable: false,
      onNextPage: () {},
      onPreviousPage: () {},
    );

    expect(enabled, isFalse);
    expect(calls.single.arguments, {'enabled': false});
  });

  test('respects the saved volume-key setting', () async {
    SharedPreferences.setMockInitialValues({
      ReaderVolumeKeyController.preferenceKey: false,
    });

    final enabled = await ReaderVolumeKeyController.activate(
      owner: owner,
      pageTurningAvailable: true,
      onNextPage: () {},
      onPreviousPage: () {},
    );

    expect(enabled, isFalse);
    expect(calls.single.arguments, {'enabled': false});
  });
}

Future<void> _sendPlatformCall(MethodChannel channel, MethodCall call) async {
  await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .handlePlatformMessage(
        channel.name,
        channel.codec.encodeMethodCall(call),
        (_) {},
      );
}
