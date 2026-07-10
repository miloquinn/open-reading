// 文件说明：iOS 云同步服务，负责文件目录快照和平台特定同步入口。
// 技术要点：服务层、Path、Path Provider、JSON、文件系统、Flutter。

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import 'package:xxread/services/books/book_dao.dart';
import 'package:xxread/services/books/book_note_dao.dart';
import 'package:xxread/services/books/bookmark_dao.dart';
import 'package:xxread/services/reading/reading_stats_dao.dart';

enum IosCloudStorageType {
  iCloudDrive,
  iosFilesLocal,
  unsupported,
}

class IosCloudSyncResult {
  final IosCloudStorageType storageType;
  final String? rootPath;
  final int booksCount;
  final int copiedBookFilesCount;
  final int copiedCoverFilesCount;
  final int missingBookFilesCount;

  const IosCloudSyncResult({
    required this.storageType,
    required this.rootPath,
    required this.booksCount,
    required this.copiedBookFilesCount,
    required this.copiedCoverFilesCount,
    required this.missingBookFilesCount,
  });

  bool get success => rootPath != null && rootPath!.isNotEmpty;

  String get storageLabel {
    switch (storageType) {
      case IosCloudStorageType.iCloudDrive:
        return 'iCloud Drive';
      case IosCloudStorageType.iosFilesLocal:
        return 'iOS 文件';
      case IosCloudStorageType.unsupported:
        return '不支持';
    }
  }
}

class IosCloudSyncService {
  static const MethodChannel _channel = MethodChannel('com.niki.xxread/icloud');

  final BookDao _bookDao = BookDao();
  final BookmarkDao _bookmarkDao = BookmarkDao();
  final BookNoteDao _noteDao = BookNoteDao();
  final ReadingStatsDao _statsDao = ReadingStatsDao();

  bool _isSyncing = false;
  bool get isSyncing => _isSyncing;

  Future<IosCloudSyncResult> syncLibrarySnapshot({
    bool includeBookFiles = true,
    bool preferICloudDrive = true,
  }) async {
    if (!Platform.isIOS) {
      return const IosCloudSyncResult(
        storageType: IosCloudStorageType.unsupported,
        rootPath: null,
        booksCount: 0,
        copiedBookFilesCount: 0,
        copiedCoverFilesCount: 0,
        missingBookFilesCount: 0,
      );
    }

    if (_isSyncing) {
      debugPrint('☁️ iOS 云盘同步正在进行，跳过重复请求');
      return const IosCloudSyncResult(
        storageType: IosCloudStorageType.iosFilesLocal,
        rootPath: null,
        booksCount: 0,
        copiedBookFilesCount: 0,
        copiedCoverFilesCount: 0,
        missingBookFilesCount: 0,
      );
    }

    _isSyncing = true;
    try {
      final rootInfo = await _resolveRootDirectory(
        preferICloudDrive: preferICloudDrive,
      );
      final rootDir = rootInfo.$1;
      final storageType = rootInfo.$2;

      await _prepareDirectoryTree(rootDir.path);

      final books = await _bookDao.getAllBooks();
      final bookmarks = await _bookmarkDao.getAllBookmarks();
      final notes = await _noteDao.getAllNotes();
      final stats = await _statsDao.getAllStats();
      final nowIso = DateTime.now().toIso8601String();

      int copiedBookFilesCount = 0;
      int copiedCoverFilesCount = 0;
      int missingBookFilesCount = 0;

      final bookRecords = <Map<String, dynamic>>[];

      for (final book in books) {
        final map = book.toMap();
        map.remove('cached_content');
        map.remove('cached_pages');
        map.remove('table_of_contents');

        String? exportedBookFile;
        String? exportedCoverFile;

        if (includeBookFiles) {
          final sourceBookFile = File(book.filePath);
          if (await sourceBookFile.exists()) {
            final ext = path.extension(sourceBookFile.path).isNotEmpty
                ? path.extension(sourceBookFile.path)
                : '.${book.format.toLowerCase()}';
            final fileName =
                '${book.id ?? 0}_${_sanitizeFileName(book.title)}$ext';
            final targetPath = path.join(rootDir.path, 'books/files', fileName);
            final copied = await _copyFileIfChanged(
              source: sourceBookFile,
              targetPath: targetPath,
            );
            if (copied) {
              copiedBookFilesCount++;
            }
            exportedBookFile = 'books/files/$fileName';
          } else {
            missingBookFilesCount++;
          }

          if (book.coverImagePath != null && book.coverImagePath!.isNotEmpty) {
            final sourceCoverFile = File(book.coverImagePath!);
            if (await sourceCoverFile.exists()) {
              final coverName =
                  '${book.id ?? 0}_${path.basename(sourceCoverFile.path)}';
              final coverTargetPath =
                  path.join(rootDir.path, 'books/covers', coverName);
              final copied = await _copyFileIfChanged(
                source: sourceCoverFile,
                targetPath: coverTargetPath,
              );
              if (copied) {
                copiedCoverFilesCount++;
              }
              exportedCoverFile = 'books/covers/$coverName';
            }
          }
        }

        map['exported_book_file'] = exportedBookFile;
        map['exported_cover_file'] = exportedCoverFile;
        bookRecords.add(map);
      }

      final highlights = notes
          .where((n) => n.type == 'highlight' || n.type == 'underline')
          .map((n) => n.toMap())
          .toList();
      final annotations = notes
          .where((n) => n.type == 'note' || (n.readerNote?.isNotEmpty ?? false))
          .map((n) => n.toMap())
          .toList();

      await Future.wait([
        _writeJsonFile(
          path.join(rootDir.path, 'books/books.json'),
          {
            'version': 1,
            'timestamp': nowIso,
            'books': bookRecords,
          },
        ),
        _writeJsonFile(
          path.join(rootDir.path, 'bookmarks/bookmarks.json'),
          {
            'version': 1,
            'timestamp': nowIso,
            'bookmarks': bookmarks.map((e) => e.toMap()).toList(),
          },
        ),
        _writeJsonFile(
          path.join(rootDir.path, 'notes/notes.json'),
          {
            'version': 1,
            'timestamp': nowIso,
            'notes': notes.map((e) => e.toMap()).toList(),
          },
        ),
        _writeJsonFile(
          path.join(rootDir.path, 'highlights/highlights.json'),
          {
            'version': 1,
            'timestamp': nowIso,
            'highlights': highlights,
          },
        ),
        _writeJsonFile(
          path.join(rootDir.path, 'annotations/annotations.json'),
          {
            'version': 1,
            'timestamp': nowIso,
            'annotations': annotations,
          },
        ),
        _writeJsonFile(
          path.join(rootDir.path, 'progress/progress.json'),
          {
            'version': 1,
            'timestamp': nowIso,
            'progress': books
                .map(
                  (book) => {
                    'bookId': book.id,
                    'filePath': book.filePath,
                    'currentPage': book.currentPage,
                    'totalPages': book.totalPages,
                  },
                )
                .toList(),
          },
        ),
        _writeJsonFile(
          path.join(rootDir.path, 'stats/reading_stats.json'),
          {
            'version': 1,
            'timestamp': nowIso,
            'stats': stats,
          },
        ),
        _writeJsonFile(
          path.join(rootDir.path, 'meta/snapshot_manifest.json'),
          {
            'version': 1,
            'timestamp': nowIso,
            'storage_type': storageType.name,
            'book_count': books.length,
            'bookmark_count': bookmarks.length,
            'note_count': notes.length,
            'highlight_count': highlights.length,
            'annotation_count': annotations.length,
            'stats_count': stats.length,
            'copied_book_files_count': copiedBookFilesCount,
            'copied_cover_files_count': copiedCoverFilesCount,
            'missing_book_files_count': missingBookFilesCount,
          },
        ),
      ]);

      await _writeReadme(rootDir.path, storageType);

      debugPrint(
        '☁️ iOS 云盘快照完成: ${storageType.name}, books=${books.length}, copied=$copiedBookFilesCount',
      );

      return IosCloudSyncResult(
        storageType: storageType,
        rootPath: rootDir.path,
        booksCount: books.length,
        copiedBookFilesCount: copiedBookFilesCount,
        copiedCoverFilesCount: copiedCoverFilesCount,
        missingBookFilesCount: missingBookFilesCount,
      );
    } catch (e) {
      debugPrint('❌ iOS 云盘同步失败: $e');
      rethrow;
    } finally {
      _isSyncing = false;
    }
  }

  Future<(Directory, IosCloudStorageType)> _resolveRootDirectory({
    required bool preferICloudDrive,
  }) async {
    if (preferICloudDrive) {
      final iCloudDocumentsPath = await _getICloudDocumentsPath();
      if (iCloudDocumentsPath != null && iCloudDocumentsPath.isNotEmpty) {
        final rootDir = Directory(iCloudDocumentsPath);
        return (rootDir, IosCloudStorageType.iCloudDrive);
      }
    }

    final documentsDir = await getApplicationDocumentsDirectory();
    final rootDir = Directory(documentsDir.path);
    return (rootDir, IosCloudStorageType.iosFilesLocal);
  }

  Future<String?> _getICloudDocumentsPath() async {
    try {
      return await _channel.invokeMethod<String>('getICloudDocumentsPath');
    } catch (e) {
      debugPrint('⚠️ 获取 iCloud Documents 路径失败，将回退到本地文件目录: $e');
      return null;
    }
  }

  Future<void> _prepareDirectoryTree(String rootPath) async {
    final dirs = [
      rootPath,
      path.join(rootPath, 'meta'),
      path.join(rootPath, 'books'),
      path.join(rootPath, 'books/files'),
      path.join(rootPath, 'books/covers'),
      path.join(rootPath, 'bookmarks'),
      path.join(rootPath, 'notes'),
      path.join(rootPath, 'highlights'),
      path.join(rootPath, 'annotations'),
      path.join(rootPath, 'progress'),
      path.join(rootPath, 'stats'),
    ];

    for (final dirPath in dirs) {
      final dir = Directory(dirPath);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
    }
  }

  Future<void> _writeJsonFile(
    String filePath,
    Map<String, dynamic> data,
  ) async {
    final file = File(filePath);
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(data),
      flush: true,
    );
  }

  Future<bool> _copyFileIfChanged({
    required File source,
    required String targetPath,
  }) async {
    final target = File(targetPath);
    if (!await target.exists()) {
      await source.copy(targetPath);
      return true;
    }

    final sourceStat = await source.stat();
    final targetStat = await target.stat();
    final sizeChanged = sourceStat.size != targetStat.size;
    final mtimeChanged = sourceStat.modified != targetStat.modified;

    if (sizeChanged || mtimeChanged) {
      await source.copy(targetPath);
      return true;
    }

    return false;
  }

  Future<void> _writeReadme(
    String rootPath,
    IosCloudStorageType storageType,
  ) async {
    final file = File(path.join(rootPath, 'README.txt'));
    final content = [
      'xxread iOS 同步目录',
      '',
      '生成时间: ${DateTime.now().toIso8601String()}',
      '存储位置: ${storageType.name}',
      '',
      '目录说明：',
      '- books/files: 书籍原文件副本',
      '- books/covers: 封面副本',
      '- books/books.json: 书籍元数据',
      '- progress/progress.json: 阅读进度',
      '- notes/notes.json: 笔记集合',
      '- highlights/highlights.json: 高亮集合',
      '- annotations/annotations.json: 批注集合',
      '- bookmarks/bookmarks.json: 书签集合',
      '- stats/reading_stats.json: 阅读统计',
      '- meta/snapshot_manifest.json: 本次同步清单',
    ].join('\n');

    await file.writeAsString(content, flush: true);
  }

  String _sanitizeFileName(String input) {
    final cleaned = input
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (cleaned.isEmpty) {
      return 'untitled';
    }
    final end = cleaned.length > 36 ? 36 : cleaned.length;
    return cleaned.substring(0, end);
  }
}
