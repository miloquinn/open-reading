// 文件说明：用户导入字体的数据模型与导入结果。
// 技术要点：稳定 ID、JSON 持久化、运行时字体 family 隔离。

enum CustomFontImportStatus { imported, duplicate, cancelled }

class CustomFontRecord {
  const CustomFontRecord({
    required this.id,
    required this.displayName,
    required this.runtimeFamily,
    required this.fileName,
    required this.relativePath,
    required this.format,
    required this.sha256,
    required this.fileSize,
    required this.importedAt,
    this.available = true,
  });

  final String id;
  final String displayName;
  final String runtimeFamily;
  final String fileName;
  final String relativePath;
  final String format;
  final String sha256;
  final int fileSize;
  final DateTime importedAt;
  final bool available;

  CustomFontRecord copyWith({
    String? displayName,
    bool? available,
  }) {
    return CustomFontRecord(
      id: id,
      displayName: displayName ?? this.displayName,
      runtimeFamily: runtimeFamily,
      fileName: fileName,
      relativePath: relativePath,
      format: format,
      sha256: sha256,
      fileSize: fileSize,
      importedAt: importedAt,
      available: available ?? this.available,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'displayName': displayName,
        'runtimeFamily': runtimeFamily,
        'fileName': fileName,
        'relativePath': relativePath,
        'format': format,
        'sha256': sha256,
        'fileSize': fileSize,
        'importedAt': importedAt.toIso8601String(),
      };

  factory CustomFontRecord.fromJson(Map<String, Object?> json) {
    return CustomFontRecord(
      id: json['id']! as String,
      displayName: json['displayName']! as String,
      runtimeFamily: json['runtimeFamily']! as String,
      fileName: json['fileName']! as String,
      relativePath: json['relativePath']! as String,
      format: json['format']! as String,
      sha256: json['sha256']! as String,
      fileSize: json['fileSize']! as int,
      importedAt: DateTime.parse(json['importedAt']! as String),
    );
  }
}

class CustomFontImportResult {
  const CustomFontImportResult({required this.status, this.font});

  const CustomFontImportResult.cancelled()
      : status = CustomFontImportStatus.cancelled,
        font = null;

  final CustomFontImportStatus status;
  final CustomFontRecord? font;
}

enum CustomFontErrorCode {
  unsupported,
  unsupportedFormat,
  invalidFont,
  fileTooLarge,
  readFailed,
  loadFailed,
  storageFailed,
}

class CustomFontException implements Exception {
  const CustomFontException(this.code, [this.cause]);

  final CustomFontErrorCode code;
  final Object? cause;

  @override
  String toString() => 'CustomFontException($code, $cause)';
}
