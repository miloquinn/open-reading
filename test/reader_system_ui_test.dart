import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xxread/core/reader/reader_system_ui.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.niki.xxread/fullscreen');
  final calls = <MethodCall>[];

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    SharedPreferences.setMockInitialValues({});
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return null;
    });
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('shows only the Android reader status bar when enabled', () async {
    SharedPreferences.setMockInitialValues({
      ReaderSystemUiController.preferenceKey: true,
    });

    final enabled = await ReaderSystemUiController.applySavedPreference();

    expect(enabled, isTrue);
    expect(calls, hasLength(1));
    expect(calls.single.method, 'showReaderStatusBar');
  });

  test('keeps the Android reader immersive when disabled', () async {
    final enabled = await ReaderSystemUiController.applySavedPreference();

    expect(enabled, isFalse);
    expect(calls, hasLength(1));
    expect(calls.single.method, 'hideSystemUI');
  });

  test('restores all Android system bars after leaving the reader', () async {
    await ReaderSystemUiController.restore();

    expect(calls, hasLength(1));
    expect(calls.single.method, 'showSystemUI');
  });
}
