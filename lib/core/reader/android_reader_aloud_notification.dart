import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'reader_aloud_controller.dart';

class AndroidReaderAloudNotification implements ReaderAloudNotificationSink {
  AndroidReaderAloudNotification._();

  static final AndroidReaderAloudNotification instance =
      AndroidReaderAloudNotification._();
  static const MethodChannel _channel = MethodChannel(
    'com.niki.xxread/reader_aloud',
  );

  final StreamController<ReaderAloudControl> _controls =
      StreamController<ReaderAloudControl>.broadcast();
  bool _initialized = false;
  bool _permissionRequested = false;

  bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  Stream<ReaderAloudControl> get controls => _controls.stream;

  Future<void> initialize() async {
    if (_initialized || !_isAndroid) return;
    _initialized = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method != 'control') return;
      final action = call.arguments?.toString();
      final control = switch (action) {
        'previous' => ReaderAloudControl.previous,
        'playPause' => ReaderAloudControl.playPause,
        'next' => ReaderAloudControl.next,
        'stop' => ReaderAloudControl.stop,
        _ => null,
      };
      if (control != null) _controls.add(control);
    });
  }

  @override
  Future<void> show(ReaderAloudNotificationData data) async {
    if (!_isAndroid) return;
    await initialize();
    if (!_permissionRequested) {
      _permissionRequested = true;
      await _channel.invokeMethod<void>('requestNotificationPermission');
    }
    await _channel.invokeMethod<void>('show', <String, Object?>{
      'bookTitle': data.bookTitle,
      'chapterTitle': data.chapterTitle,
      'state': data.state.name,
      'chapterIndex': data.chapterIndex,
      'chapterCount': data.chapterCount,
      'progress': data.progress,
    });
  }

  @override
  Future<void> stop() async {
    if (!_isAndroid || !_initialized) return;
    await _channel.invokeMethod<void>('stop');
  }
}
