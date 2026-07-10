// 文件说明：WebDAV 清单模型，定义同步清单的数据结构。
// 技术要点：服务层。

import 'webdav_sync_path_helper.dart';

/// WebDAV 同步清单（manifest）。
///
/// 作用：
/// - 描述当前这次上传包含了哪些数据。
/// - 记录每个数据域的路径与条目数。
/// - 提前预留未来数据域（例如批注增强格式）。
class WebDavSyncManifestModel {
  final int schemaVersion;
  final String appName;
  final String deviceId;
  final DateTime generatedAt;
  final int booksCount;
  final int bookmarksCount;
  final int notesCount;
  final int highlightsCount;
  final int annotationsCount;
  final int progressCount;
  final int statsCount;
  final int selectedBookFilesCount;

  const WebDavSyncManifestModel({
    required this.schemaVersion,
    required this.appName,
    required this.deviceId,
    required this.generatedAt,
    required this.booksCount,
    required this.bookmarksCount,
    required this.notesCount,
    required this.highlightsCount,
    required this.annotationsCount,
    required this.progressCount,
    required this.statsCount,
    required this.selectedBookFilesCount,
  });

  Map<String, dynamic> toJson() {
    return {
      'schema_version': schemaVersion,
      'app_name': appName,
      'device_id': deviceId,
      'generated_at': generatedAt.toIso8601String(),
      'datasets': {
        'books': _dataset(WebDavSyncPathHelper.booksFile, booksCount),
        'bookmarks':
            _dataset(WebDavSyncPathHelper.bookmarksFile, bookmarksCount),
        'notes': _dataset(WebDavSyncPathHelper.notesFile, notesCount),
        'highlights':
            _dataset(WebDavSyncPathHelper.highlightsFile, highlightsCount),
        'annotations': _dataset(
          WebDavSyncPathHelper.annotationsFile,
          annotationsCount,
        ),
        'progress': _dataset(WebDavSyncPathHelper.progressFile, progressCount),
        'stats': _dataset(WebDavSyncPathHelper.statsFile, statsCount),
      },
      'selected_book_files_count': selectedBookFilesCount,
      'future_reserved': {
        'notes_v2': {
          'path': WebDavSyncPathHelper.notesDir,
          'status': 'reserved'
        },
        'highlights_v2': {
          'path': WebDavSyncPathHelper.highlightsDir,
          'status': 'reserved',
        },
        'annotations_v2': {
          'path': WebDavSyncPathHelper.annotationsDir,
          'status': 'reserved',
        },
      },
    };
  }

  Map<String, dynamic> _dataset(String path, int count) {
    return {
      'path': path,
      'count': count,
    };
  }
}
