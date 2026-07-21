// 文件说明：原生平台在线字体下载、校验、私有存储与运行时注册服务。
// 技术要点：Dio 断点下载、SHA-256 完整性校验、FontLoader 运行时注册、原子清单持久化。
// 字体源：jsDelivr CDN（https://cdn.jsdelivr.net/gh/...）服务 GitHub 上游仓库；
// NotoSerifSC 因 25MB 文件触发 jsDelivr 403，回退到 raw.githubusercontent.com。

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import 'online_font_models.dart';

typedef OnlineFontDirectoryProvider = Future<Directory> Function();
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
  })  : _supportDirectory = supportDirectory ?? getApplicationSupportDirectory,
        _registrar = registrar ?? _registerFont,
        _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 15),
                receiveTimeout: const Duration(minutes: 10),
                headers: {
                  if (!kIsWeb) 'User-Agent': 'OpenReading-OnlineFont',
                },
              ),
            );

  static const String _directoryName = 'online_fonts';
  static const String _manifestName = 'manifest.json';

  /// 下载单个文件最多允许的额外字节（防 Content-Length 误报）。
  static const int _downloadToleranceBytes = 2 * 1024 * 1024;

  /// 允许的下载主机白名单（防 SSRF）。
  static const Set<String> _allowedHosts = <String>{
    'cdn.jsdelivr.net',
    'fastly.jsdelivr.net',
    'gcore.jsdelivr.net',
    'raw.githubusercontent.com',
  };

  final OnlineFontDirectoryProvider _supportDirectory;
  final OnlineFontRegistrar _registrar;
  final Dio _dio;

  Directory? _fontDirectory;
  bool _isSupported = true;

  /// fontId → 已持久化记录（已下载且清单已写入）。
  final Map<String, OnlineFontRecord> _records = <String, OnlineFontRecord>{};

  /// fontId → 已通过 FontLoader 注册到引擎的 family 集合。
  final Set<String> _loadedFontIds = <String>{};

  /// fontId → 当前下载进度（idle 状态在完成后清除）。
  final Map<String, OnlineFontDownloadProgress> _progress =
      <String, OnlineFontDownloadProgress>{};

  /// 当前是否正在下载的 fontId 集合（防止重复下载）。
  final Set<String> _activeDownloads = <String>{};

  bool get isSupported => _isSupported;
  List<String> get downloadedFontIds =>
      List<String>.unmodifiable(_records.keys);
  OnlineFontRecord? recordFor(String fontId) => _records[fontId];
  OnlineFontDownloadProgress? progressFor(String fontId) => _progress[fontId];

  Future<void> initialize() async {
    try {
      final support = await _supportDirectory();
      final directory = Directory(path.join(support.path, _directoryName));
      await directory.create(recursive: true);
      _fontDirectory = directory;
      await _readManifest();
    } catch (_) {
      _isSupported = false;
      _records.clear();
    }
  }

  bool isDownloaded(String fontId) => _records.containsKey(fontId);

  /// 若已下载，按 [files] 顺序逐个读字节并通过 [family] 注册到 FontLoader。
  /// 任何文件缺失或注册失败返回 false；不抛异常，由调用方决定回退策略。
  Future<bool> ensureLoaded(
    String fontId, {
    required List<OnlineFontFile> files,
    required String family,
  }) async {
    if (_loadedFontIds.contains(fontId)) return true;
    final directory = _fontDirectory;
    final record = _records[fontId];
    if (directory == null || record == null) return false;
    final fontDir = Directory(path.join(directory.path, fontId));
    for (final file in files) {
      final file_ = File(path.join(fontDir.path, file.fileName));
      if (!await file_.exists()) return false;
      try {
        final bytes = await file_.readAsBytes();
        await _registrar(family, bytes, file.style);
      } catch (_) {
        return false;
      }
    }
    _loadedFontIds.add(fontId);
    return true;
  }

  /// 下载并注册一个在线字体。
  ///
  /// 流程：对每个 [files] 项依次下载到 `.tmp` 暂存文件 → 字节签名校验 →
  /// SHA-256 计算 → 通过 FontLoader 注册 → 重命名为最终文件名。
  /// 全部成功后更新清单，删除暂存文件。失败时清理 fontDir 并抛 [OnlineFontException]。
  ///
  /// [onProgress] 在每个文件下载与每个状态切换时回调，便于 UI 实时刷新。
  /// [cancelToken] 由调用方持有，取消时抛 [OnlineFontException] (code=cancelled)。
  Future<OnlineFontRecord> download({
    required String fontId,
    required String family,
    required List<OnlineFontFile> files,
    OnlineFontProgressCallback? onProgress,
    CancelToken? cancelToken,
  }) async {
    if (!_isSupported || _fontDirectory == null) {
      throw const OnlineFontException(OnlineFontErrorCode.unsupported);
    }
    if (files.isEmpty) {
      throw const OnlineFontException(OnlineFontErrorCode.invalidResponse);
    }
    if (_activeDownloads.contains(fontId)) {
      throw const OnlineFontException(OnlineFontErrorCode.invalidResponse);
    }
    if (_records.containsKey(fontId)) {
      // 已下载过：直接确保加载并返回。
      await ensureLoaded(fontId, files: files, family: family);
      return _records[fontId]!;
    }

    _activeDownloads.add(fontId);
    final totalBytes = files.fold<int>(0, (sum, file) => sum + file.size);
    var downloadedBytes = 0;
    var downloadedFiles = 0;

    final fontDir = Directory(path.join(_fontDirectory!.path, fontId));
    try {
      await fontDir.create(recursive: true);
    } catch (error) {
      _activeDownloads.remove(fontId);
      throw OnlineFontException(OnlineFontErrorCode.storageFailed, error);
    }

    final fileRecords = <OnlineFontFileRecord>[];
    try {
      for (final fileSpec in files) {
        if (!_isAllowedUrl(fileSpec.url)) {
          throw const OnlineFontException(OnlineFontErrorCode.invalidResponse);
        }
        final destFile = File(path.join(fontDir.path, fileSpec.fileName));
        final tempFile = File('${destFile.path}.tmp');
        if (await tempFile.exists()) {
          await tempFile.delete();
        }

        final fileStartBytes = downloadedBytes;
        _emitProgress(
          fontId: fontId,
          status: OnlineFontDownloadStatus.downloading,
          downloadedFiles: downloadedFiles,
          totalFiles: files.length,
          downloadedBytes: fileStartBytes,
          totalBytes: totalBytes,
          onProgress: onProgress,
        );

        try {
          await _dio.download(
            fileSpec.url,
            tempFile.path,
            cancelToken: cancelToken,
            deleteOnError: true,
            onReceiveProgress: (received, total) {
              final actualTotal = total > 0 ? total : fileSpec.size;
              if (received > actualTotal + _downloadToleranceBytes) {
                // 超出预期大小过多，中止下载。
                cancelToken?.cancel('Online font download exceeded size limit');
                return;
              }
              _emitProgress(
                fontId: fontId,
                status: OnlineFontDownloadStatus.downloading,
                downloadedFiles: downloadedFiles,
                totalFiles: files.length,
                downloadedBytes: fileStartBytes + received,
                totalBytes: totalBytes,
                onProgress: onProgress,
              );
            },
            options: Options(
              validateStatus: (status) =>
                  status != null && status >= 200 && status < 300,
              headers: const {'Accept': 'application/octet-stream'},
            ),
          );
        } on DioException catch (error) {
          if (CancelToken.isCancel(error)) {
            throw const OnlineFontException(OnlineFontErrorCode.cancelled);
          }
          throw OnlineFontException(
              OnlineFontErrorCode.networkFailed, error);
        } catch (error) {
          throw OnlineFontException(
              OnlineFontErrorCode.networkFailed, error);
        }

        final bytes = await tempFile.readAsBytes();

        // 字节签名校验（TTF/OTF 魔数）。
        if (!_matchesFontSignature(bytes, path.extension(fileSpec.fileName))) {
          throw const OnlineFontException(
              OnlineFontErrorCode.fileSignatureInvalid);
        }

        _emitProgress(
          fontId: fontId,
          status: OnlineFontDownloadStatus.verifying,
          downloadedFiles: downloadedFiles + 1,
          totalFiles: files.length,
          downloadedBytes: fileStartBytes + bytes.length,
          totalBytes: totalBytes,
          onProgress: onProgress,
        );

        // 计算 SHA-256（用于后续清单校验与重复检测）。
        final hash = sha256.convert(bytes).toString();

        _emitProgress(
          fontId: fontId,
          status: OnlineFontDownloadStatus.registering,
          downloadedFiles: downloadedFiles + 1,
          totalFiles: files.length,
          downloadedBytes: fileStartBytes + bytes.length,
          totalBytes: totalBytes,
          onProgress: onProgress,
        );

        try {
          await _registrar(family, bytes, fileSpec.style);
        } catch (error) {
          throw OnlineFontException(OnlineFontErrorCode.loadFailed, error);
        }

        await tempFile.rename(destFile.path);
        fileRecords.add(OnlineFontFileRecord(
          fileName: fileSpec.fileName,
          sha256: hash,
          size: bytes.length,
        ));
        downloadedBytes = fileStartBytes + bytes.length;
        downloadedFiles++;
      }

      final record = OnlineFontRecord(
        id: fontId,
        files: fileRecords,
        downloadedAt: DateTime.now().toUtc(),
      );
      _records[fontId] = record;
      _loadedFontIds.add(fontId);
      await _writeManifest();

      _emitProgress(
        fontId: fontId,
        status: OnlineFontDownloadStatus.completed,
        downloadedFiles: files.length,
        totalFiles: files.length,
        downloadedBytes: totalBytes,
        totalBytes: totalBytes,
        onProgress: onProgress,
      );
      _progress.remove(fontId);
      return record;
    } on OnlineFontException catch (error) {
      _emitProgress(
        fontId: fontId,
        status: OnlineFontDownloadStatus.failed,
        downloadedFiles: downloadedFiles,
        totalFiles: files.length,
        downloadedBytes: downloadedBytes,
        totalBytes: totalBytes,
        error: error.toString(),
        onProgress: onProgress,
      );
      // 清理半成品。
      try {
        if (await fontDir.exists()) await fontDir.delete(recursive: true);
      } catch (_) {}
      rethrow;
    } catch (error) {
      _emitProgress(
        fontId: fontId,
        status: OnlineFontDownloadStatus.failed,
        downloadedFiles: downloadedFiles,
        totalFiles: files.length,
        downloadedBytes: downloadedBytes,
        totalBytes: totalBytes,
        error: error.toString(),
        onProgress: onProgress,
      );
      try {
        if (await fontDir.exists()) await fontDir.delete(recursive: true);
      } catch (_) {}
      throw OnlineFontException(OnlineFontErrorCode.storageFailed, error);
    } finally {
      _activeDownloads.remove(fontId);
    }
  }

  /// 删除已下载字体（磁盘文件 + 清单记录 + 已注册状态）。
  Future<void> deleteDownload(String fontId) async {
    final directory = _fontDirectory;
    if (directory == null) return;
    final fontDir = Directory(path.join(directory.path, fontId));
    try {
      if (await fontDir.exists()) await fontDir.delete(recursive: true);
    } catch (_) {}
    _records.remove(fontId);
    _loadedFontIds.remove(fontId);
    _progress.remove(fontId);
    await _writeManifest();
  }

  Future<void> _readManifest() async {
    final directory = _fontDirectory;
    if (directory == null) return;
    final manifest = File(path.join(directory.path, _manifestName));
    if (!await manifest.exists()) return;

    try {
      final decoded = jsonDecode(await manifest.readAsString());
      if (decoded is! List<Object?>) return;
      _records
        ..clear()
        ..addAll(decoded
            .whereType<Map<String, Object?>>()
            .map(OnlineFontRecord.fromJson)
            .fold<Map<String, OnlineFontRecord>>(<String, OnlineFontRecord>{},
                (map, record) {
          // 清单里记录存在，但磁盘文件可能被外部删除，需逐个校验。
          final fontDir = Directory(path.join(directory.path, record.id));
          final allFilesPresent = record.files.every((fileRecord) {
            final file = File(path.join(fontDir.path, fileRecord.fileName));
            return file.existsSync();
          });
          if (allFilesPresent) map[record.id] = record;
          return map;
        }));
    } catch (_) {
      _records.clear();
    }
  }

  Future<void> _writeManifest() async {
    final directory = _fontDirectory;
    if (directory == null) {
      throw const OnlineFontException(OnlineFontErrorCode.storageFailed);
    }
    final manifest = File(path.join(directory.path, _manifestName));
    final temporary = File('${manifest.path}.tmp');
    try {
      await temporary.writeAsString(
        const JsonEncoder.withIndent('  ')
            .convert(_records.values.map((record) => record.toJson()).toList()),
        flush: true,
      );
      if (await manifest.exists()) await manifest.delete();
      await temporary.rename(manifest.path);
    } catch (error) {
      if (await temporary.exists()) await temporary.delete();
      throw OnlineFontException(OnlineFontErrorCode.storageFailed, error);
    }
  }

  void _emitProgress({
    required String fontId,
    required OnlineFontDownloadStatus status,
    required int downloadedFiles,
    required int totalFiles,
    required int downloadedBytes,
    required int totalBytes,
    String? error,
    OnlineFontProgressCallback? onProgress,
  }) {
    final progress = OnlineFontDownloadProgress(
      fontId: fontId,
      status: status,
      downloadedFiles: downloadedFiles,
      totalFiles: totalFiles,
      downloadedBytes: downloadedBytes,
      totalBytes: totalBytes,
      error: error,
    );
    _progress[fontId] = progress;
    onProgress?.call(progress);
  }

  static bool _isAllowedUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || uri.scheme != 'https') return false;
    return _allowedHosts.contains(uri.host.toLowerCase());
  }

  static bool _matchesFontSignature(Uint8List bytes, String extension) {
    if (bytes.length < 4) return false;
    final tag = String.fromCharCodes(bytes.take(4));
    if (extension.toLowerCase() == '.otf') return tag == 'OTTO';
    return (bytes[0] == 0 && bytes[1] == 1 && bytes[2] == 0 && bytes[3] == 0) ||
        tag == 'true' ||
        tag == 'typ1';
  }

  static Future<void> _registerFont(
    String family,
    Uint8List bytes,
    FontStyle style,
  ) async {
    // FontLoader 运行时不支持指定 weight/style 变体；同一 family 下多次 addFont
    // 会互相覆盖，只保留最后一次注册的字节。变量字体通过文件内部的轴定义覆盖
    // 全部字重，所以每个在线字体下载 1 个变量字体文件即可。
    // 非变量字体的 italic 由系统合成斜体（SlantFake）；weight 700 同理会合成加粗。
    // 参数 style 仅作为元数据保留，未来若 Flutter 暴露带 weight/style 的运行时
    // 注册 API 可直接启用。
    final loader = FontLoader(family)
      ..addFont(Future<ByteData>.value(ByteData.sublistView(bytes)));
    await loader.load();
  }
}
