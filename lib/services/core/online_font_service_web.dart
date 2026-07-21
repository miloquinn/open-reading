// 文件说明：Web 平台在线字体下载占位实现；首版不在 Web 上做持久化下载。
//
// Web 上字体加载由浏览器负责（CSS @font-face），App 内做 TTF/OTF 下载、SHA-256 校验、
// FontLoader 注册这套链路反而会破坏 Web 的字体子集化策略。原生平台（Android/iOS/
// macOS/Windows/Linux）走 io 实现；Web 端调用方应感知 unsupported 并优雅降级到系统字体。

import 'dart:typed_data';
import 'dart:ui';

import 'package:dio/dio.dart';

import 'online_font_models.dart';

typedef OnlineFontDirectoryProvider = Future<dynamic> Function();
typedef OnlineFontRegistrar = Future<void> Function(
  String family,
  Uint8List bytes,
  FontStyle style,
);
typedef OnlineFontProgressCallback = void Function(
    OnlineFontDownloadProgress progress);

class OnlineFontService {
  OnlineFontService({
    OnlineFontDirectoryProvider? supportDirectory,
    OnlineFontRegistrar? registrar,
    Dio? dio,
  });

  bool get isSupported => false;
  List<String> get downloadedFontIds => const <String>[];
  OnlineFontRecord? recordFor(String fontId) => null;
  OnlineFontDownloadProgress? progressFor(String fontId) => null;

  Future<void> initialize() async {}

  bool isDownloaded(String fontId) => false;

  Future<bool> ensureLoaded(
    String fontId, {
    required List<OnlineFontFile> files,
    required String family,
  }) async =>
      false;

  Future<OnlineFontRecord> download({
    required String fontId,
    required String family,
    required List<OnlineFontFile> files,
    OnlineFontProgressCallback? onProgress,
    CancelToken? cancelToken,
  }) async {
    throw const OnlineFontException(OnlineFontErrorCode.unsupported);
  }

  Future<void> deleteDownload(String fontId) async {}
}
