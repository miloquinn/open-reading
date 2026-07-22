// 文件说明：书籍 DAO，负责书籍元数据、进度和分页缓存字段的数据库读写。
// 技术要点：服务层、Flutter。

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:xxread/models/book.dart';
import 'package:xxread/services/core/database_service.dart';
import 'package:xxread/services/books/book_image_map_service.dart';
import 'package:xxread/services/books/book_import_models.dart';
import 'package:xxread/services/books/web_book_file_store.dart';

class BookDao implements BookImportStore {
  final _dbService = DatabaseService();

  Future<int> insertBook(Book book) async {
    try {
      final db = await _dbService.database;
      return await db.insert('books', book.toMap());
    } catch (e) {
      throw Exception('添加书籍失败: $e');
    }
  }

  Future<List<Book>> getAllBooks() async {
    try {
      final db = await _dbService.database;
      final List<Map<String, dynamic>> maps = await db.query(
        'books',
        columns: [
          'id',
          'title',
          'author',
          'filePath',
          'format',
          'currentPage',
          'totalPages',
          'importDate',
          'file_modified_time',
          'content_hash',
          'cover_image_path',
          'text_encoding',
          'last_canonical_locator',
          'last_rendered_locator',
          'layout_signature',
          'storage_type',
          'source_id',
          'source_book_id',
          'source_json',
          'source_book_json',
          'source_kind',
          'source_locator',
          'source_modified_time',
        ],
        orderBy: 'importDate DESC',
      );
      return List.generate(maps.length, (i) => Book.fromMap(maps[i]));
    } catch (e) {
      throw Exception('获取书籍列表失败: $e');
    }
  }

  Future<void> updateBookProgress(int bookId, int currentPage) async {
    try {
      final db = await _dbService.database;
      final result = await db.update(
        'books',
        {'currentPage': currentPage},
        where: 'id = ?',
        whereArgs: [bookId],
      );
      if (result == 0) {
        throw Exception('书籍不存在');
      }
    } catch (e) {
      throw Exception('更新阅读进度失败: $e');
    }
  }

  Future<int> getBooksCount() async {
    try {
      final db = await _dbService.database;
      final result = await db.rawQuery('SELECT COUNT(*) as count FROM books');
      return (result.first['count'] as int?) ?? 0;
    } catch (e) {
      throw Exception('获取书籍数量失败: $e');
    }
  }

  Future<Book?> getBookById(int bookId) async {
    try {
      final db = await _dbService.database;
      final List<Map<String, dynamic>> maps = await db.query(
        'books',
        where: 'id = ?',
        whereArgs: [bookId],
      );
      if (maps.isNotEmpty) {
        return Book.fromMap(maps.first);
      }
      return null;
    } catch (e) {
      throw Exception('获取书籍详情失败: $e');
    }
  }

  Future<Book?> getBookBySource({
    required String sourceId,
    required String sourceBookId,
  }) async {
    final db = await _dbService.database;
    final maps = await db.query(
      'books',
      where: 'source_id = ? AND source_book_id = ?',
      whereArgs: [sourceId, sourceBookId],
      limit: 1,
    );
    return maps.isEmpty ? null : Book.fromMap(maps.first);
  }

  Future<void> updateBookTotalPages(int bookId, int totalPages) async {
    final db = await _dbService.database;
    await db.update(
      'books',
      {'totalPages': totalPages},
      where: 'id = ?',
      whereArgs: [bookId],
    );
  }

  Future<void> updateBook(Book book) async {
    try {
      final db = await _dbService.database;
      final result = await db.update(
        'books',
        book.toMap(),
        where: 'id = ?',
        whereArgs: [book.id],
      );
      if (result == 0) {
        throw Exception('书籍不存在');
      }
    } catch (e) {
      throw Exception('更新书籍信息失败: $e');
    }
  }

  Future<void> deleteBook(int bookId) async {
    try {
      final db = await _dbService.database;
      final book = await getBookById(bookId);

      // 🗑️ 删除相关缓存
      await _deleteBookCaches(bookId);

      // 删除数据库记录。显式删除子表行：外键 CASCADE 依赖
      // PRAGMA foreign_keys 开启，这里手动删除保证历史数据也被清理。
      final result = await db.transaction((txn) async {
        await txn.delete('bookmarks', where: 'bookId = ?', whereArgs: [bookId]);
        await txn.delete(
          'book_notes',
          where: 'book_id = ?',
          whereArgs: [bookId],
        );
        return txn.delete('books', where: 'id = ?', whereArgs: [bookId]);
      });
      if (result == 0) {
        throw Exception('书籍不存在或已被删除');
      }
      if (kIsWeb &&
          book != null &&
          WebBookFileStore.isWebBookPath(book.filePath)) {
        await WebBookFileStore().delete(book.filePath);
      }

      debugPrint('✅ 书籍已删除: $bookId（包括所有相关缓存）');
    } catch (e) {
      throw Exception('删除书籍失败: $e');
    }
  }

  /// 删除书籍相关的缓存
  ///
  /// 包括：
  /// - 图片映射文件
  /// - 旧分页缓存文件（按 contentHash 目录清理）
  Future<void> _deleteBookCaches(int bookId) async {
    debugPrint('🗑️ 开始清除书籍缓存: $bookId');

    try {
      // 1. 删除图片映射
      final imageMapService = BookImageMapService();
      await imageMapService.deleteImageMap(bookId);
      debugPrint('  ✅ 图片映射已删除');
    } catch (e) {
      debugPrint('  ⚠️ 删除图片映射失败: $e');
    }

    try {
      // 2. 清理已停用的旧分页缓存目录。
      final book = await getBookById(bookId);
      if (book != null && book.contentHash != null) {
        final cacheDir = await _paginationCacheDir();
        final bookCacheDir = Directory('${cacheDir.path}/${book.contentHash}');
        if (await bookCacheDir.exists()) {
          await bookCacheDir.delete(recursive: true);
          debugPrint('  ✅ 旧分页缓存目录已清理');
        }
      }
    } catch (e) {
      debugPrint('  ⚠️ 清理旧分页缓存目录失败: $e');
    }

    debugPrint('🗑️ 缓存清除完成');
  }

  /// 获取旧分页缓存根目录路径。
  Future<Directory> _paginationCacheDir() async {
    // 使用 path_provider 获取文档目录，与旧 PaginationCacheService 同级
    final db = await _dbService.database;
    final dbPath = db.path;
    final parentDir = Directory(dbPath).parent;
    final cacheDir = Directory('${parentDir.path}/pagination_cache');
    return cacheDir;
  }

  // 更新书籍文件路径 - 用于处理iOS沙盒路径变更
  Future<void> updateBookFilePath(int bookId, String newFilePath) async {
    try {
      final db = await _dbService.database;
      final result = await db.update(
        'books',
        {'filePath': newFilePath},
        where: 'id = ?',
        whereArgs: [bookId],
      );
      if (result == 0) {
        throw Exception('书籍不存在');
      }
    } catch (e) {
      throw Exception('更新书籍文件路径失败: $e');
    }
  }

  // 更新书籍封面图片路径
  Future<void> updateBookCoverPath(int bookId, String? coverImagePath) async {
    try {
      final db = await _dbService.database;
      final result = await db.update(
        'books',
        {'cover_image_path': coverImagePath},
        where: 'id = ?',
        whereArgs: [bookId],
      );
      if (result == 0) {
        throw Exception('书籍不存在');
      }
    } catch (e) {
      throw Exception('更新书籍封面失败: $e');
    }
  }

  /// 通过内容哈希值查找书籍
  ///
  /// 用于检查是否已导入相同内容的书籍
  /// 参数 [contentHash] 书籍文件的MD5哈希值
  /// 返回找到的书籍，如果不存在则返回null
  @override
  Future<Book?> getBookByHash(String contentHash) async {
    try {
      final db = await _dbService.database;
      final List<Map<String, dynamic>> maps = await db.query(
        'books',
        where: 'content_hash = ?',
        whereArgs: [contentHash],
      );
      if (maps.isNotEmpty) {
        return Book.fromMap(maps.first);
      }
      return null;
    } catch (e) {
      throw Exception('通过哈希值查找书籍失败: $e');
    }
  }

  @override
  Future<Book?> getBookBySourceLocator({
    required String sourceKind,
    required String sourceLocator,
  }) async {
    final db = await _dbService.database;
    final maps = await db.query(
      'books',
      where: 'source_kind = ? AND source_locator = ?',
      whereArgs: [sourceKind, sourceLocator],
      limit: 1,
    );
    return maps.isEmpty ? null : Book.fromMap(maps.first);
  }

  @override
  Future<Book?> getBookByFilePath(String filePath) async {
    final db = await _dbService.database;
    final maps = await db.query(
      'books',
      where: 'filePath = ?',
      whereArgs: [filePath],
      limit: 1,
    );
    return maps.isEmpty ? null : Book.fromMap(maps.first);
  }

  @override
  Future<BookInsertDecision> insertIfAbsentByHash(Book book) async {
    final contentHash = book.contentHash;
    if (contentHash == null || contentHash.isEmpty) {
      throw ArgumentError.value(
        contentHash,
        'book.contentHash',
        '原子导入前必须先计算内容哈希',
      );
    }

    final db = await _dbService.database;
    return db.transaction((txn) async {
      final maps = await txn.query(
        'books',
        where: 'content_hash = ?',
        whereArgs: [contentHash],
        limit: 1,
      );
      if (maps.isNotEmpty) {
        return BookInsertDecision.existing(Book.fromMap(maps.first));
      }

      final id = await txn.insert('books', book.toMap());
      return BookInsertDecision.inserted(book.copyWith(id: id));
    });
  }

  @override
  Future<Book> updateBookStorageLocation({
    required Book book,
    required String filePath,
    required String sourceKind,
    required String sourceLocator,
    required int? sourceModifiedTime,
  }) async {
    final updated = book.copyWith(
      filePath: filePath,
      sourceKind: sourceKind,
      sourceLocator: sourceLocator,
      sourceModifiedTime: sourceModifiedTime,
    );
    await updateBook(updated);
    return updated;
  }

  // We can add other DAOs (e.g., BookmarkDao) in separate files
  // for better organization.

  /// 更新书籍的 CanonicalLocator 双轨定位进度。
  ///
  /// 同时写入 canonical、rendered 和 layoutSignature，
  /// 并更新 currentPage 以兼容旧链路。
  Future<void> updateBookCanonicalLocator(
    int bookId,
    String canonicalJson,
    String? renderedJson,
    String? layoutSignature,
    int currentPage,
  ) async {
    try {
      final db = await _dbService.database;
      final updates = <String, dynamic>{
        'last_canonical_locator': canonicalJson,
        'currentPage': currentPage,
      };
      if (renderedJson != null) {
        updates['last_rendered_locator'] = renderedJson;
      }
      if (layoutSignature != null) {
        updates['layout_signature'] = layoutSignature;
      }
      final result = await db.update(
        'books',
        updates,
        where: 'id = ?',
        whereArgs: [bookId],
      );
      if (result == 0) {
        throw Exception('书籍不存在');
      }
    } catch (e) {
      throw Exception('更新 CanonicalLocator 进度失败: $e');
    }
  }
}
