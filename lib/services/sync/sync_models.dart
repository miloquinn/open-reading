import 'dart:convert';

enum WebDavSyncStatus {
  unconfigured,
  idle,
  testing,
  syncing,
  success,
  partialFailure,
  failed,
}

enum WebDavSyncPhase {
  none,
  connecting,
  scanningLocal,
  readingRemote,
  applyingRemote,
  uploadingLocal,
  finishing,
}

enum WebDavSyncErrorCode {
  invalidConfiguration,
  insecureConnection,
  authentication,
  permissionDenied,
  notFound,
  conflict,
  serverIncompatible,
  storageFull,
  rateLimited,
  timeout,
  tls,
  network,
  corruptRemoteData,
  clockSkew,
  secureStorage,
  unknown,
}

enum WebDavNewBookUploadPolicy {
  askEveryTime('ask'),
  automatic('automatic'),
  manual('manual');

  const WebDavNewBookUploadPolicy(this.storageValue);

  final String storageValue;

  static WebDavNewBookUploadPolicy fromStorage(String? value) {
    for (final policy in values) {
      if (policy.storageValue == value) return policy;
    }
    return askEveryTime;
  }
}

class WebDavSyncFailure implements Exception {
  const WebDavSyncFailure(this.code, this.message, {this.statusCode});

  final WebDavSyncErrorCode code;
  final String message;
  final int? statusCode;

  @override
  String toString() => 'WebDavSyncFailure($code, $message)';
}

class WebDavSyncConfigDraft {
  const WebDavSyncConfigDraft({
    required this.serverUrl,
    required this.username,
    required this.password,
    this.rootPath = 'OpenReading',
    this.allowInsecurePrivateHttp = false,
  });

  final String serverUrl;
  final String username;
  final String password;
  final String rootPath;
  final bool allowInsecurePrivateHttp;

  WebDavSyncConfiguration withoutPassword({bool autoSync = true}) =>
      WebDavSyncConfiguration(
        serverUrl: serverUrl,
        username: username,
        rootPath: rootPath,
        allowInsecurePrivateHttp: allowInsecurePrivateHttp,
        autoSync: autoSync,
      );
}

class WebDavSyncConfiguration {
  const WebDavSyncConfiguration({
    required this.serverUrl,
    required this.username,
    this.rootPath = 'OpenReading',
    this.allowInsecurePrivateHttp = false,
    this.autoSync = true,
  });

  final String serverUrl;
  final String username;
  final String rootPath;
  final bool allowInsecurePrivateHttp;
  final bool autoSync;

  Map<String, Object?> toJson() => {
    'server_url': serverUrl,
    'username': username,
    'root_path': rootPath,
    'allow_insecure_private_http': allowInsecurePrivateHttp,
    'auto_sync': autoSync,
  };

  factory WebDavSyncConfiguration.fromJson(Map<String, dynamic> json) =>
      WebDavSyncConfiguration(
        serverUrl: json['server_url'] as String,
        username: json['username'] as String,
        rootPath: json['root_path'] as String? ?? 'OpenReading',
        allowInsecurePrivateHttp:
            json['allow_insecure_private_http'] as bool? ?? false,
        autoSync: json['auto_sync'] as bool? ?? true,
      );

  WebDavSyncConfiguration copyWith({
    String? serverUrl,
    String? username,
    String? rootPath,
    bool? allowInsecurePrivateHttp,
    bool? autoSync,
  }) => WebDavSyncConfiguration(
    serverUrl: serverUrl ?? this.serverUrl,
    username: username ?? this.username,
    rootPath: rootPath ?? this.rootPath,
    allowInsecurePrivateHttp:
        allowInsecurePrivateHttp ?? this.allowInsecurePrivateHttp,
    autoSync: autoSync ?? this.autoSync,
  );
}

class WebDavSyncScope {
  const WebDavSyncScope({
    this.books = true,
    this.progress = true,
    this.bookmarks = true,
    this.notes = false,
    this.readingSessions = true,
    this.bookFiles = false,
  });

  final bool books;
  final bool progress;
  final bool bookmarks;
  final bool notes;
  final bool readingSessions;
  final bool bookFiles;

  Map<String, Object?> toJson() => {
    'books': books,
    'progress': progress,
    'bookmarks': bookmarks,
    'notes': notes,
    'reading_sessions': readingSessions,
    'book_files': bookFiles,
  };

  factory WebDavSyncScope.fromJson(Map<String, dynamic> json) =>
      WebDavSyncScope(
        books: json['books'] as bool? ?? true,
        progress: json['progress'] as bool? ?? true,
        bookmarks: json['bookmarks'] as bool? ?? true,
        notes: json['notes'] as bool? ?? false,
        readingSessions: json['reading_sessions'] as bool? ?? true,
        bookFiles: json['book_files'] as bool? ?? false,
      );

  WebDavSyncScope copyWith({
    bool? books,
    bool? progress,
    bool? bookmarks,
    bool? notes,
    bool? readingSessions,
    bool? bookFiles,
  }) => WebDavSyncScope(
    books: books ?? this.books,
    progress: progress ?? this.progress,
    bookmarks: bookmarks ?? this.bookmarks,
    notes: notes ?? this.notes,
    readingSessions: readingSessions ?? this.readingSessions,
    bookFiles: bookFiles ?? this.bookFiles,
  );
}

class ConnectionTestResult {
  const ConnectionTestResult({
    required this.success,
    this.supportsEtag = false,
    this.supportsMove = false,
    this.serverDate,
    this.errorCode,
    this.message,
  });

  final bool success;
  final bool supportsEtag;
  final bool supportsMove;
  final DateTime? serverDate;
  final WebDavSyncErrorCode? errorCode;
  final String? message;
}

class WebDavSyncRunResult {
  const WebDavSyncRunResult({
    required this.uploaded,
    required this.downloaded,
    required this.skipped,
    required this.conflictsResolved,
    required this.completedAt,
  });

  final int uploaded;
  final int downloaded;
  final int skipped;
  final int conflictsResolved;
  final DateTime completedAt;
}

class SyncFileCapabilities {
  const SyncFileCapabilities({
    this.metadataSyncSupported = true,
    this.uploadSupported = true,
    this.downloadSupported = true,
    this.reason = '',
  });

  final bool metadataSyncSupported;
  final bool uploadSupported;
  final bool downloadSupported;
  final String reason;
}

class RemoteBookDescriptor {
  const RemoteBookDescriptor({
    required this.bookUid,
    required this.title,
    required this.author,
    required this.format,
    this.fileAvailable = false,
    this.sizeBytes,
    this.blobSha256,
    this.remotePath,
    this.fileName,
    this.sourceId,
    this.sourceBookId,
    this.coverAvailable = false,
    this.coverSizeBytes,
    this.coverBlobSha256,
    this.coverRemotePath,
    this.coverFileName,
  });

  final String bookUid;
  final String title;
  final String author;
  final String format;
  final bool fileAvailable;
  final int? sizeBytes;
  final String? blobSha256;
  final String? remotePath;
  final String? fileName;
  final String? sourceId;
  final String? sourceBookId;
  final bool coverAvailable;
  final int? coverSizeBytes;
  final String? coverBlobSha256;
  final String? coverRemotePath;
  final String? coverFileName;
}

class BookFileTransferProgress {
  const BookFileTransferProgress({
    required this.transferredBytes,
    required this.totalBytes,
  });

  final int transferredBytes;
  final int totalBytes;

  double get fraction =>
      totalBytes <= 0 ? 0 : (transferredBytes / totalBytes).clamp(0, 1);
}

String encodeSyncJson(Object? value) => jsonEncode(value);
