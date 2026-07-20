import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xxread/core/reader/reader_system_ui.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.niki.xxread/fullscreen');
  const iosChannel = MethodChannel('com.niki.xxread/reader_ui');
  final calls = <MethodCall>[];
  final iosCalls = <MethodCall>[];

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    SharedPreferences.setMockInitialValues({});
    calls.clear();
    iosCalls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return null;
    });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(iosChannel, (call) async {
      iosCalls.add(call);
      return null;
    });
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(iosChannel, null);
  });

  test('shows only the Android reader status bar when enabled', () async {
    SharedPreferences.setMockInitialValues({
      ReaderSystemUiController.preferenceKey: ReaderTopBarStyle.system.name,
    });

    final style = await ReaderSystemUiController.applySavedPreference();

    expect(style, ReaderTopBarStyle.system);
    expect(calls, hasLength(1));
    expect(calls.single.method, 'showReaderStatusBar');
  });

  test('keeps the Android reader immersive when disabled', () async {
    final style = await ReaderSystemUiController.applySavedPreference();

    expect(style, ReaderTopBarStyle.reader);
    expect(calls, hasLength(1));
    expect(calls.single.method, 'hideSystemUI');
  });

  test('migrates the legacy boolean preference', () async {
    SharedPreferences.setMockInitialValues({
      ReaderSystemUiController.legacyPreferenceKey: true,
    });

    final style = await ReaderSystemUiController.loadPreference();
    final prefs = await SharedPreferences.getInstance();

    expect(style, ReaderTopBarStyle.system);
    expect(
      prefs.getString(ReaderSystemUiController.preferenceKey),
      ReaderTopBarStyle.system.name,
    );
  });

  test('restores all Android system bars after leaving the reader', () async {
    await ReaderSystemUiController.restore();

    expect(calls, hasLength(1));
    expect(calls.single.method, 'showSystemUI');
  });

  test('hides the iOS status bar for the reader information bar', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

    await ReaderSystemUiController.apply(style: ReaderTopBarStyle.reader);

    expect(iosCalls, hasLength(1));
    expect(iosCalls.single.method, 'setReaderImmersive');
    expect(iosCalls.single.arguments, {'enabled': true});
  });

  test('hides the iOS status bar for fully immersive reading', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

    await ReaderSystemUiController.apply(style: ReaderTopBarStyle.hidden);

    expect(iosCalls, hasLength(1));
    expect(iosCalls.single.method, 'setReaderImmersive');
    expect(iosCalls.single.arguments, {'enabled': true});
  });

  test('shows the iOS status bar only for the system style', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

    await ReaderSystemUiController.apply(style: ReaderTopBarStyle.system);

    expect(iosCalls, hasLength(1));
    expect(iosCalls.single.method, 'setReaderImmersive');
    expect(iosCalls.single.arguments, {'enabled': false});
  });

  test('restores the iOS status bar after leaving the reader', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

    await ReaderSystemUiController.restore();

    expect(iosCalls, hasLength(1));
    expect(iosCalls.single.method, 'setReaderImmersive');
    expect(iosCalls.single.arguments, {'enabled': false});
  });
}
