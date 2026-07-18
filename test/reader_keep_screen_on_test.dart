import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xxread/core/reader/reader_keep_screen_on.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.niki.xxread/fullscreen');
  final calls = <bool>[];

  setUp(() async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    SharedPreferences.setMockInitialValues(<String, Object>{});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'setKeepScreenOn') {
        calls
            .add((call.arguments as Map<Object?, Object?>)['enabled']! as bool);
      }
      return null;
    });
    calls.clear();
    await ReaderKeepScreenOnController.resetForTesting();
  });

  tearDown(() async {
    await ReaderKeepScreenOnController.resetForTesting();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    debugDefaultTargetPlatformOverride = null;
  });

  test('applies the saved preference while a reader is active', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      ReaderKeepScreenOnController.preferenceKey: true,
    });
    final reader = Object();

    await ReaderKeepScreenOnController.activate(reader);
    await ReaderKeepScreenOnController.deactivate(reader);

    expect(calls, <bool>[true, false]);
  });

  test('preference changes update an active reader immediately', () async {
    final reader = Object();
    await ReaderKeepScreenOnController.activate(reader);

    await ReaderKeepScreenOnController.setPreference(true);
    await ReaderKeepScreenOnController.setPreference(false);

    expect(calls, <bool>[true, false]);
    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getBool(ReaderKeepScreenOnController.preferenceKey),
      isFalse,
    );
  });

  test('releases the flag only after the last reader exits', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      ReaderKeepScreenOnController.preferenceKey: true,
    });
    final firstReader = Object();
    final secondReader = Object();

    await ReaderKeepScreenOnController.activate(firstReader);
    await ReaderKeepScreenOnController.activate(secondReader);
    await ReaderKeepScreenOnController.deactivate(firstReader);
    await ReaderKeepScreenOnController.deactivate(secondReader);

    expect(calls, <bool>[true, false]);
  });
}
