// 文件说明：书籍存储修复服务，用于处理文件迁移和失效路径修复。
// 技术要点：服务层、Path、Path Provider、文件系统、Flutter。

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:xxread/models/book.dart';
import 'package:xxread/services/books/book_dao.dart';

/// 书籍存储路径修复服务
///
/// 场景：
/// - 版本升级/重装后，数据库里还保留旧的绝对路径
/// - 书籍文件和封面实际还在，但因为沙盒路径前缀变化导致无法打开
///
/// 策略（尽量保守）：
/// 1) 文件/封面路径可用 -> 不改
/// 2) 不可用 -> 在当前 documents/books 与 documents/covers 按文件名尝试恢复
/// 3) 找到后只更新数据库路径，不改业务数据
class BookStorageRepairService {
  final BookDao _bookDao = BookDao();

  Future<int> repairAllBooksIfNeeded() async {
    final books = await _bookDao.getAllBooks();
    int repairedCount = 0;

    for (final book in books) {
      final repaired = await repairSingleBookIfNeeded(book);
      if (repaired.filePath != book.filePath ||
          repaired.coverImagePath != book.coverImagePath) {
        repairedCount++;
      }
    }

    if (repairedCount > 0) {
      debugPrint('🔧 已修复 $repairedCount 本书的存储路径');
    } else {
      debugPrint('✅ 书籍存储路径检查完成，无需修复');
    }

    return repairedCount;
  }

  /// 清理不再使用的临时文件与失效图片映射文件（保守策略）
  ///
  /// 仅删除：
  /// - `books/`、`covers/` 目录下明确的临时文件后缀
  /// - `book_images/` 中没有对应书籍ID的 `image_map_*.json`
  Future<int> cleanupUnusedStorageArtifacts() async {
    final docsDir = await getApplicationDocumentsDirectory();
    final booksDir = Directory(p.join(docsDir.path, 'books'));
    final coversDir = Directory(p.join(docsDir.path, 'covers'));
    final imagesDir = Directory(p.join(docsDir.path, 'book_images'));

    final books = await _bookDao.getAllBooks();
    final existingBookIds = books.map((e) => e.id).whereType<int>().toSet();

    int removed = 0;
    removed += await _cleanupTempFiles(booksDir);
    removed += await _cleanupTempFiles(coversDir);
    removed += await _cleanupOrphanImageMaps(imagesDir, existingBookIds);

    if (removed > 0) {
      debugPrint('🧹 清理无用存储文件完成: removed=$removed');
    } else {
      debugPrint('✅ 存储清理完成，无需删除文件');
    }
    return removed;
  }

  Future<Book> repairSingleBookIfNeeded(Book book) async {
    // 没有数据库ID时无法回写，只做读取校验
    if (book.id == null) {
      return book;
    }

    final docsDir = await getApplicationDocumentsDirectory();
    final booksDir = Directory(p.join(docsDir.path, 'books'));
    final coversDir = Directory(p.join(docsDir.path, 'covers'));

    String filePath = book.filePath;
    String? coverPath = book.coverImagePath;
    bool changed = false;

    // 1) 修复正文文件路径
    final repairedFilePath = await _repairFilePath(
      currentPath: filePath,
      targetDir: booksDir,
    );
    if (repairedFilePath != null && repairedFilePath != filePath) {
      filePath = repairedFilePath;
      await _bookDao.updateBookFilePath(book.id!, filePath);
      changed = true;
      debugPrint('🔧 修复书籍文件路径: ${book.title} -> $filePath');
    }

    // 2) 修复封面路径
    final repairedCoverPath = await _repairFilePath(
      currentPath: coverPath,
      targetDir: coversDir,
    );
    if (repairedCoverPath != coverPath) {
      coverPath = repairedCoverPath;
      await _bookDao.updateBookCoverPath(book.id!, coverPath);
      changed = true;
      if (coverPath != null) {
        debugPrint('🖼️ 修复封面路径: ${book.title} -> $coverPath');
      } else {
        debugPrint('🖼️ 清理失效封面路径: ${book.title}');
      }
    }

    if (!changed) {
      return book;
    }

    return book.copyWith(filePath: filePath, coverImagePath: coverPath);
  }

  Future<String?> _repairFilePath({
    required String? currentPath,
    required Directory targetDir,
  }) async {
    if (currentPath == null || currentPath.isEmpty) {
      return null;
    }

    // 当前路径可用，直接返回
    final currentFile = File(currentPath);
    if (await currentFile.exists()) {
      return currentPath;
    }

    // 目录不存在，无法恢复
    if (!await targetDir.exists()) {
      return null;
    }

    // 先按文件名精确匹配（最稳妥）
    final fileName = p.basename(currentPath);
    final exactPath = p.join(targetDir.path, fileName);
    if (await File(exactPath).exists()) {
      return exactPath;
    }

    // 再按去扩展名模糊匹配，兼容重命名后缀 _1/_2 的情况
    final oldStem = p.basenameWithoutExtension(fileName);
    final oldExt = p.extension(fileName).toLowerCase();
    try {
      final candidates = targetDir.listSync().whereType<File>();
      for (final file in candidates) {
        final stem = p.basenameWithoutExtension(file.path);
        final ext = p.extension(file.path).toLowerCase();
        if (ext == oldExt &&
            (stem == oldStem || stem.startsWith('${oldStem}_'))) {
          return file.path;
        }
      }
    } catch (e) {
      debugPrint('⚠️ 扫描目录失败: ${targetDir.path}, $e');
    }

    // 找不到时返回 null，调用方可清理无效路径
    return null;
  }

  Future<int> _cleanupTempFiles(Directory dir) async {
    if (!await dir.exists()) {
      return 0;
    }
    int removed = 0;
    try {
      final entries = dir.listSync(followLinks: false);
      for (final entry in entries) {
        if (entry is! File) {
          continue;
        }
        final fileName = p.basename(entry.path).toLowerCase();
        if (!_isDisposableTempFile(fileName)) {
          continue;
        }
        try {
          await entry.delete();
          removed++;
        } catch (e) {
          debugPrint('⚠️ 删除临时文件失败: ${entry.path}, $e');
        }
      }
    } catch (e) {
      debugPrint('⚠️ 扫描临时文件失败: ${dir.path}, $e');
    }
    return removed;
  }

  bool _isDisposableTempFile(String fileName) {
    return fileName.endsWith('.tmp') ||
        fileName.endsWith('.temp') ||
        fileName.endsWith('.download') ||
        fileName.endsWith('.partial') ||
        fileName.endsWith('.crdownload') ||
        fileName.startsWith('tmp_') ||
        fileName.startsWith('.~') ||
        fileName == '.ds_store';
  }

  Future<int> _cleanupOrphanImageMaps(
    Directory imagesDir,
    Set<int> existingBookIds,
  ) async {
    if (!await imagesDir.exists()) {
      return 0;
    }
    int removed = 0;
    final pattern = RegExp(r'^image_map_(\d+)\.json$', caseSensitive: false);
    try {
      final entries = imagesDir.listSync(followLinks: false);
      for (final entry in entries) {
        if (entry is! File) {
          continue;
        }
        final match = pattern.firstMatch(p.basename(entry.path));
        if (match == null) {
          continue;
        }
        final bookId = int.tryParse(match.group(1) ?? '');
        if (bookId == null || existingBookIds.contains(bookId)) {
          continue;
        }
        try {
          await entry.delete();
          removed++;
        } catch (e) {
          debugPrint('⚠️ 删除失效图片映射失败: ${entry.path}, $e');
        }
      }
    } catch (e) {
      debugPrint('⚠️ 扫描图片映射失败: ${imagesDir.path}, $e');
    }
    return removed;
  }
}
