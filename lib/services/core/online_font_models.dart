// 文件说明：在线字体的数据模型、下载进度与异常定义。
// 技术要点：稳定 ID、JSON 持久化、SHA-256 完整性校验、FontLoader 注册元数据。

import 'dart:ui';

/// 单个在线字体文件元数据（URL、本地保存名、预期大小、可选字重/字形）。
class OnlineFontFile {
  const OnlineFontFile({
    required this.url,
    required this.fileName,
    required this.size,
    this.weight,
    this.style = FontStyle.normal,
  });

  /// 下载 URL（jsDelivr CDN 或 raw.githubusercontent.com）。
  final String url;

  /// 本地保存文件名（含扩展名，存于 online_fonts/<font_id>/ 下）。
  final String fileName;

  /// 预期字节数，用于进度展示与下载超额保护。
  final int size;

  /// 该文件对应的 Flutter 字重；null 表示变量字体或默认字重。
  final int? weight;

  /// 该文件对应的字形（normal/italic）。
  final FontStyle style;
}

/// 已下载字体的单个文件持久化记录。
class OnlineFontFileRecord {
  const OnlineFontFileRecord({
    required this.fileName,
    required this.sha256,
    required this.size,
  });

  final String fileName;
  final String sha256;
  final int size;

  Map<String, Object?> toJson() => <String, Object?>{
        'fileName': fileName,
        'sha256': sha256,
        'size': size,
      };

  factory OnlineFontFileRecord.fromJson(Map<String, Object?> json) {
    return OnlineFontFileRecord(
      fileName: json['fileName']! as String,
      sha256: json['sha256']! as String,
      size: json['size']! as int,
    );
  }
}

/// 已下载字体的持久化记录。
class OnlineFontRecord {
  const OnlineFontRecord({
    required this.id,
    required this.files,
    required this.downloadedAt,
  });

  final String id;
  final List<OnlineFontFileRecord> files;
  final DateTime downloadedAt;

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'files': files.map((file) => file.toJson()).toList(),
        'downloadedAt': downloadedAt.toIso8601String(),
      };

  factory OnlineFontRecord.fromJson(Map<String, Object?> json) {
    final rawFiles = json['files'];
    return OnlineFontRecord(
      id: json['id']! as String,
      files: rawFiles is List<Object?>
          ? rawFiles
              .whereType<Map<String, Object?>>()
              .map(OnlineFontFileRecord.fromJson)
              .toList(growable: false)
          : const <OnlineFontFileRecord>[],
      downloadedAt: DateTime.parse(json['downloadedAt']! as String),
    );
  }
}

/// 下载流程状态机：空闲→下载中→校验中→注册中→完成/失败。
enum OnlineFontDownloadStatus {
  idle,
  downloading,
  verifying,
  registering,
  completed,
  failed,
}

/// 下载进度快照（推送给 UI）。
class OnlineFontDownloadProgress {
  const OnlineFontDownloadProgress({
    required this.fontId,
    required this.status,
    this.downloadedFiles = 0,
    this.totalFiles = 0,
    this.downloadedBytes = 0,
    this.totalBytes = 0,
    this.error,
  });

  final String fontId;
  final OnlineFontDownloadStatus status;
  final int downloadedFiles;
  final int totalFiles;
  final int downloadedBytes;
  final int totalBytes;
  final String? error;

  /// 0.0–1.0 的进度比例；totalBytes 为 0 时返回 0。
  double get fraction =>
      totalBytes > 0 ? (downloadedBytes / totalBytes).clamp(0.0, 1.0) : 0.0;

  OnlineFontDownloadProgress copyWith({
    OnlineFontDownloadStatus? status,
    int? downloadedFiles,
    int? totalFiles,
    int? downloadedBytes,
    int? totalBytes,
    String? error,
  }) {
    return OnlineFontDownloadProgress(
      fontId: fontId,
      status: status ?? this.status,
      downloadedFiles: downloadedFiles ?? this.downloadedFiles,
      totalFiles: totalFiles ?? this.totalFiles,
      downloadedBytes: downloadedBytes ?? this.downloadedBytes,
      totalBytes: totalBytes ?? this.totalBytes,
      error: error ?? this.error,
    );
  }
}

enum OnlineFontErrorCode {
  unsupported,
  networkFailed,
  invalidResponse,
  fileSignatureInvalid,
  storageFailed,
  loadFailed,
  cancelled,
  sizeMismatch,
}

class OnlineFontException implements Exception {
  const OnlineFontException(this.code, [this.cause]);

  final OnlineFontErrorCode code;
  final Object? cause;

  @override
  String toString() => 'OnlineFontException($code, $cause)';
}
