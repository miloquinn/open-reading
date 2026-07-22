// 文件说明：封装 Android SAF 与 iOS iCloud Documents 的原生存储通道。
// 技术要点：MethodChannel、类型归一化、平台实现可独立替换。

import 'package:flutter/services.dart';

class PlatformStorageBridge {
  PlatformStorageBridge({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('com.niki.xxread/storage');

  final MethodChannel _channel;

  Future<Map<String, Object?>?> pickAndroidDirectory() {
    return _channel.invokeMapMethod<String, Object?>('pickDirectory');
  }

  Future<List<Map<String, Object?>>> listAndroidDocuments(
    String treeUri,
  ) async {
    final rows =
        await _channel.invokeListMethod<Map<Object?, Object?>>(
          'listDocuments',
          {'treeUri': treeUri},
        ) ??
        const [];
    return _normalizeRows(rows);
  }

  Future<List<Map<String, Object?>>> listPersistedAndroidDirectories() async {
    final rows =
        await _channel.invokeListMethod<Map<Object?, Object?>>(
          'listPersistedDirectories',
        ) ??
        const [];
    return _normalizeRows(rows);
  }

  Future<bool> releaseAndroidDirectory(String treeUri) async {
    return await _channel.invokeMethod<bool>('releaseDirectory', {
          'treeUri': treeUri,
        }) ??
        false;
  }

  Future<String> materializeAndroidDocument({
    required String documentUri,
    required String destinationPath,
  }) async {
    final path = await _channel.invokeMethod<String>('materializeDocument', {
      'documentUri': documentUri,
      'destinationPath': destinationPath,
    });
    if (path == null || path.isEmpty) {
      throw StateError('Android 文件物化没有返回本地路径');
    }
    return path;
  }

  Future<Map<String, Object?>> getICloudStatus() async {
    return await _channel.invokeMapMethod<String, Object?>('getICloudStatus') ??
        const {'available': false};
  }

  Future<List<Map<String, Object?>>> listICloudDocuments() async {
    final rows =
        await _channel.invokeListMethod<Map<Object?, Object?>>(
          'listICloudDocuments',
        ) ??
        const [];
    return _normalizeRows(rows);
  }

  Future<String> materializeICloudDocument({
    required String locator,
    required String destinationPath,
  }) async {
    final path = await _channel.invokeMethod<String>(
      'materializeICloudDocument',
      {'locator': locator, 'destinationPath': destinationPath},
    );
    if (path == null || path.isEmpty) {
      throw StateError('iCloud 文件物化没有返回本地路径');
    }
    return path;
  }

  Future<Map<String, Object?>> exportBookToDownloads({
    required String sourcePath,
    required String displayName,
    required String mimeType,
  }) async {
    return await _channel
            .invokeMapMethod<String, Object?>('exportBookToDownloads', {
              'sourcePath': sourcePath,
              'displayName': displayName,
              'mimeType': mimeType,
              'relativePath': 'Download/开元阅读',
            }) ??
        const {'status': 'failure', 'errorCode': 'empty_result'};
  }

  Future<Map<String, Object?>> exportDocument({
    required String sourcePath,
    required String displayName,
    required String mimeType,
  }) async {
    return await _channel.invokeMapMethod<String, Object?>('exportDocument', {
          'sourcePath': sourcePath,
          'displayName': displayName,
          'mimeType': mimeType,
        }) ??
        const {'status': 'failure', 'errorCode': 'empty_result'};
  }

  List<Map<String, Object?>> _normalizeRows(List<Map<Object?, Object?>> rows) {
    return rows
        .map((row) => row.map((key, value) => MapEntry('$key', value)))
        .toList(growable: false);
  }
}
