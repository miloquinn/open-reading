// 文件说明：定义书籍导出的稳定领域结果与平台后端边界。
// 技术要点：结构化状态、平台无关请求、错误不直接泄露到 UI。

enum BookExportStatus {
  success,
  cancelled,
  unsupported,
  notDownloaded,
  sourceMissing,
  failure,
}

class BookExportRequest {
  const BookExportRequest({
    required this.sourcePath,
    required this.suggestedName,
    required this.mimeType,
  });

  final String sourcePath;
  final String suggestedName;
  final String mimeType;
}

class BookExportBackendResult {
  const BookExportBackendResult.success({
    required this.displayName,
    this.location,
    this.uri,
  })  : status = BookExportStatus.success,
        error = null;

  const BookExportBackendResult.cancelled()
      : status = BookExportStatus.cancelled,
        displayName = null,
        location = null,
        uri = null,
        error = null;

  const BookExportBackendResult.unsupported()
      : status = BookExportStatus.unsupported,
        displayName = null,
        location = null,
        uri = null,
        error = null;

  const BookExportBackendResult.failure([this.error])
      : status = BookExportStatus.failure,
        displayName = null,
        location = null,
        uri = null;

  final BookExportStatus status;
  final String? displayName;
  final String? location;
  final String? uri;
  final Object? error;
}

class BookExportResult {
  const BookExportResult._({
    required this.status,
    this.displayName,
    this.location,
    this.uri,
    this.error,
  });

  const BookExportResult.success({
    required String displayName,
    String? location,
    String? uri,
  }) : this._(
          status: BookExportStatus.success,
          displayName: displayName,
          location: location,
          uri: uri,
        );

  const BookExportResult.cancelled()
      : this._(status: BookExportStatus.cancelled);

  const BookExportResult.unsupported()
      : this._(status: BookExportStatus.unsupported);

  const BookExportResult.notDownloaded()
      : this._(status: BookExportStatus.notDownloaded);

  const BookExportResult.sourceMissing()
      : this._(status: BookExportStatus.sourceMissing);

  const BookExportResult.failure([Object? error])
      : this._(status: BookExportStatus.failure, error: error);

  final BookExportStatus status;
  final String? displayName;
  final String? location;
  final String? uri;
  final Object? error;

  bool get isSuccess => status == BookExportStatus.success;
}

abstract interface class BookExportBackend {
  Future<BookExportBackendResult> export(BookExportRequest request);
}
