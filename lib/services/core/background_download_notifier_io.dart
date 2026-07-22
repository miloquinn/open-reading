import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

enum BackgroundDownloadKind { book, update }

class BackgroundDownloadTask {
  const BackgroundDownloadTask({
    required this.id,
    required this.kind,
    required this.title,
    this.bookId,
  });

  final String id;
  final BackgroundDownloadKind kind;
  final String title;
  final int? bookId;
}

class BackgroundDownloadTap {
  const BackgroundDownloadTap({
    required this.kind,
    this.bookId,
    this.apkPath,
    this.expectedBuildNumber,
  });

  final BackgroundDownloadKind kind;
  final int? bookId;
  final String? apkPath;
  final String? expectedBuildNumber;
}

class BackgroundDownloadNotifier {
  BackgroundDownloadNotifier._();

  static const MethodChannel _channel =
      MethodChannel('com.niki.xxread/background_downloads');
  static final StreamController<BackgroundDownloadTap> _taps =
      StreamController<BackgroundDownloadTap>.broadcast();
  static final Map<String, DateTime> _lastProgressAt = {};
  static bool _initialized = false;

  static Stream<BackgroundDownloadTap> get taps => _taps.stream;

  static Future<void> initialize() async {
    if (_initialized || !Platform.isAndroid) return;
    _initialized = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method != 'notificationTap') return;
      final values = _stringMap(call.arguments);
      _taps.add(
        BackgroundDownloadTap(
          kind: values['kind'] == 'update'
              ? BackgroundDownloadKind.update
              : BackgroundDownloadKind.book,
          bookId: int.tryParse(values['bookId'] ?? ''),
          apkPath: values['apkPath'],
          expectedBuildNumber: values['expectedBuildNumber'],
        ),
      );
    });
    final initial = await _channel.invokeMapMethod<String, dynamic>(
      'consumeNotificationTap',
    );
    if (initial != null) {
      final values = _stringMap(initial);
      _taps.add(
        BackgroundDownloadTap(
          kind: values['kind'] == 'update'
              ? BackgroundDownloadKind.update
              : BackgroundDownloadKind.book,
          bookId: int.tryParse(values['bookId'] ?? ''),
          apkPath: values['apkPath'],
          expectedBuildNumber: values['expectedBuildNumber'],
        ),
      );
    }
  }

  static Future<void> begin(BackgroundDownloadTask task) async {
    if (!Platform.isAndroid) return;
    await initialize();
    await _channel.invokeMethod<void>('requestNotificationPermission');
    await _channel.invokeMethod<void>('begin', _taskArguments(task));
  }

  static Future<void> progress(
    BackgroundDownloadTask task, {
    required int completed,
    required int total,
  }) async {
    if (!Platform.isAndroid) return;
    final now = DateTime.now();
    final last = _lastProgressAt[task.id];
    if (total > 0 &&
        completed < total &&
        last != null &&
        now.difference(last) < const Duration(milliseconds: 350)) {
      return;
    }
    _lastProgressAt[task.id] = now;
    await _channel.invokeMethod<void>('progress', {
      ..._taskArguments(task),
      'completed': completed,
      'total': total,
    });
  }

  static Future<void> completeBook(BackgroundDownloadTask task) async {
    if (!Platform.isAndroid) return;
    _lastProgressAt.remove(task.id);
    await _channel.invokeMethod<void>('complete', _taskArguments(task));
  }

  static Future<void> completeUpdate(
    BackgroundDownloadTask task, {
    required String apkPath,
    required String expectedBuildNumber,
  }) async {
    if (!Platform.isAndroid) return;
    _lastProgressAt.remove(task.id);
    await _channel.invokeMethod<void>('complete', {
      ..._taskArguments(task),
      'apkPath': apkPath,
      'expectedBuildNumber': expectedBuildNumber,
    });
  }

  static Future<void> fail(BackgroundDownloadTask task) async {
    if (!Platform.isAndroid) return;
    _lastProgressAt.remove(task.id);
    await _channel.invokeMethod<void>('fail', _taskArguments(task));
  }

  static Future<void> cancel(BackgroundDownloadTask task) async {
    if (!Platform.isAndroid) return;
    _lastProgressAt.remove(task.id);
    await _channel.invokeMethod<void>('cancel', _taskArguments(task));
  }

  static Map<String, Object?> _taskArguments(BackgroundDownloadTask task) => {
        'id': task.id,
        'kind': task.kind.name,
        'title': task.title,
        if (task.bookId != null) 'bookId': task.bookId,
      };

  static Map<String, String> _stringMap(Object? value) {
    if (value is! Map) return const {};
    return value.map((key, value) => MapEntry('$key', '${value ?? ''}'));
  }
}
