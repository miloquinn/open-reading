// 文件说明：封装原生冷启动与热启动书籍请求通道。
// 技术要点：MethodChannel、宽容 payload 解析、请求完成确认。

import 'dart:async';

import 'package:flutter/services.dart';
import 'package:xxread/services/books/incoming_book_models.dart';

abstract interface class IncomingBookRequestSource {
  Stream<IncomingBookRequest> get requests;

  Future<List<IncomingBookRequest>> getInitialRequests();

  Future<void> completeRequest(String requestId, {required bool deleteFiles});

  Future<void> dispose();
}

class IncomingBookPlatformBridge implements IncomingBookRequestSource {
  IncomingBookPlatformBridge({MethodChannel? channel})
    : _channel =
          channel ?? const MethodChannel('com.niki.xxread/incoming_books') {
    _generation = ++_latestGeneration;
    _channel.setMethodCallHandler(_handleNativeCall);
  }

  static int _latestGeneration = 0;
  final MethodChannel _channel;
  late final int _generation;
  final StreamController<IncomingBookRequest> _requests =
      StreamController<IncomingBookRequest>.broadcast();

  @override
  Stream<IncomingBookRequest> get requests => _requests.stream;

  @override
  Future<List<IncomingBookRequest>> getInitialRequests() async {
    try {
      final raw = await _channel.invokeMethod<Object?>(
        'getInitialIncomingBooks',
      );
      return _parseRequests(raw);
    } on MissingPluginException {
      return const [];
    }
  }

  @override
  Future<void> completeRequest(
    String requestId, {
    required bool deleteFiles,
  }) async {
    if (requestId.isEmpty) return;
    try {
      await _channel.invokeMethod<void>('completeIncomingRequest', {
        'requestId': requestId,
        'deleteFiles': deleteFiles,
      });
    } on MissingPluginException {
      // Windows/Linux/Web may deliver initial paths without native staging.
    }
  }

  Future<void> _handleNativeCall(MethodCall call) async {
    if (call.method != 'incomingBooks') return;
    for (final request in _parseRequests(call.arguments)) {
      _requests.add(request);
    }
  }

  List<IncomingBookRequest> _parseRequests(Object? value) {
    final rows = value is List ? value : <Object?>[value];
    return rows
        .whereType<Map>()
        .map(
          (row) => IncomingBookRequest.fromMap(
            row.map((key, value) => MapEntry('$key', value)),
          ),
        )
        .where((request) => request.requestId.isNotEmpty)
        .toList(growable: false);
  }

  @override
  Future<void> dispose() async {
    if (_generation == _latestGeneration) {
      _channel.setMethodCallHandler(null);
    }
    await _requests.close();
  }
}
