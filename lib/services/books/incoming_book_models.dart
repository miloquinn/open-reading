// 文件说明：定义系统“打开方式/分享”传入书籍的跨平台模型。
// 技术要点：不信任 URI/文件名、稳定请求 ID、结构化失败码。

enum IncomingBookAction { open, share }

class IncomingBookItem {
  const IncomingBookItem({
    required this.id,
    required this.displayName,
    required this.localPath,
    this.mimeType,
    this.sizeBytes,
    this.modifiedTime,
  });

  final String id;
  final String displayName;
  final String localPath;
  final String? mimeType;
  final int? sizeBytes;
  final int? modifiedTime;

  factory IncomingBookItem.fromMap(Map<String, Object?> map) {
    return IncomingBookItem(
      id: map['id']?.toString() ?? '',
      displayName: map['displayName']?.toString() ?? '',
      localPath: map['localPath']?.toString() ?? '',
      mimeType: map['mimeType']?.toString(),
      sizeBytes: _asInt(map['sizeBytes']),
      modifiedTime: _asInt(map['modifiedTime']),
    );
  }
}

class IncomingBookRequest {
  const IncomingBookRequest({
    required this.requestId,
    required this.action,
    required this.items,
    this.errorCode,
    this.failureCount = 0,
  });

  final String requestId;
  final IncomingBookAction action;
  final List<IncomingBookItem> items;
  final String? errorCode;
  final int failureCount;

  factory IncomingBookRequest.fromMap(Map<String, Object?> map) {
    final action = map['action']?.toString() == 'share'
        ? IncomingBookAction.share
        : IncomingBookAction.open;
    final rawItems = map['items'];
    final rawFailures = map['failures'];
    return IncomingBookRequest(
      requestId: map['requestId']?.toString() ?? '',
      action: action,
      errorCode: map['errorCode']?.toString(),
      failureCount: rawFailures is List ? rawFailures.length : 0,
      items: rawItems is List
          ? rawItems
              .whereType<Map>()
              .map(
                (row) => IncomingBookItem.fromMap(
                  row.map((key, value) => MapEntry('$key', value)),
                ),
              )
              .toList(growable: false)
          : const [],
    );
  }
}

class IncomingBookFailure implements Exception {
  const IncomingBookFailure(this.code, {this.cause});

  final String code;
  final Object? cause;

  @override
  String toString() => 'IncomingBookFailure($code)';
}

int? _asInt(Object? value) {
  if (value is int) return value;
  return int.tryParse(value?.toString() ?? '');
}
