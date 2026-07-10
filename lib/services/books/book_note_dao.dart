// 文件说明：笔记与高亮 DAO，负责书摘、批注和高亮数据的本地读写。
// 技术要点：服务层。

import 'package:xxread/models/book_note.dart';
import 'package:xxread/services/core/database_service.dart';

/// 统一的书籍注释数据访问对象
///
/// 提供完整的 CRUD 操作，支持：
/// - 插入和更新注释（智能合并相同CFI位置的注释）
/// - 按书籍、CFI、章节查询注释
/// - 搜索和筛选功能
/// - 统计信息获取
class BookNoteDao {
  final _dbService = DatabaseService();

  /// 插入或更新注释
  ///
  /// 如果注释已有ID，则更新现有记录
  /// 如果相同CFI位置已有注释，则合并内容
  /// 否则创建新记录
  ///
  /// [bookNote] 要插入的注释对象
  /// Returns: 注释的ID
  Future<int> insertBookNote(BookNote bookNote) async {
    if (bookNote.id != null) {
      await updateBookNoteById(bookNote);
      return bookNote.id!;
    }

    // 检查相同CFI位置是否已有注释
    List<BookNote> existingNotes = await selectBookNoteByCfiAndBookId(
      bookNote.cfi,
      bookNote.bookId,
    );

    if (existingNotes.isNotEmpty) {
      // 合并现有注释
      final existing = existingNotes.last;
      final merged = _mergeBookNotes(existing, bookNote);
      await updateBookNoteById(merged);
      return existing.id!;
    }

    final db = await _dbService.database;
    return await db.insert('book_notes', bookNote.toMap());
  }

  /// 根据CFI和书籍ID查询注释
  Future<List<BookNote>> selectBookNoteByCfiAndBookId(
    String cfi,
    int bookId,
  ) async {
    final db = await _dbService.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'book_notes',
      where: 'cfi = ? AND book_id = ?',
      whereArgs: [cfi, bookId],
    );
    return List.generate(maps.length, (i) => BookNote.fromMap(maps[i]));
  }

  /// 根据书籍ID获取所有注释
  Future<List<BookNote>> selectBookNotesByBookId(int bookId) async {
    final db = await _dbService.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'book_notes',
      where: 'book_id = ?',
      whereArgs: [bookId],
      orderBy: 'page_number ASC, create_time DESC',
    );
    return List.generate(maps.length, (i) => BookNote.fromMap(maps[i]));
  }

  /// 根据书籍ID和类型获取注释
  Future<List<BookNote>> selectBookNotesByType(
    int bookId,
    String type,
  ) async {
    final db = await _dbService.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'book_notes',
      where: 'book_id = ? AND type = ?',
      whereArgs: [bookId, type],
      orderBy: 'page_number ASC, create_time DESC',
    );
    return List.generate(maps.length, (i) => BookNote.fromMap(maps[i]));
  }

  /// 根据书籍ID和页码获取注释
  Future<List<BookNote>> selectBookNotesByPage(
    int bookId,
    int pageNumber,
  ) async {
    final db = await _dbService.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'book_notes',
      where: 'book_id = ? AND page_number = ?',
      whereArgs: [bookId, pageNumber],
      orderBy: 'start_offset ASC',
    );
    return List.generate(maps.length, (i) => BookNote.fromMap(maps[i]));
  }

  /// 根据章节获取注释
  Future<List<BookNote>> selectBookNotesByChapter(
    int bookId,
    String chapter,
  ) async {
    final db = await _dbService.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'book_notes',
      where: 'book_id = ? AND chapter = ?',
      whereArgs: [bookId, chapter],
      orderBy: 'page_number ASC, create_time DESC',
    );
    return List.generate(maps.length, (i) => BookNote.fromMap(maps[i]));
  }

  /// 更新注释
  Future<void> updateBookNoteById(BookNote bookNote) async {
    final db = await _dbService.database;
    await db.update(
      'book_notes',
      bookNote.copyWith(updateTime: DateTime.now()).toMap(),
      where: 'id = ?',
      whereArgs: [bookNote.id],
    );
  }

  /// 根据ID查询注释
  Future<BookNote> selectBookNoteById(int id) async {
    final db = await _dbService.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'book_notes',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) {
      throw Exception('BookNote with id $id not found');
    }
    return BookNote.fromMap(maps[0]);
  }

  /// 删除注释
  Future<void> deleteBookNoteById(int id) async {
    final db = await _dbService.database;
    await db.delete(
      'book_notes',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// 删除书籍的所有注释
  Future<void> deleteBookNotesByBookId(int bookId) async {
    final db = await _dbService.database;
    await db.delete(
      'book_notes',
      where: 'book_id = ?',
      whereArgs: [bookId],
    );
  }

  /// 搜索注释内容
  Future<List<BookNote>> searchBookNotes(
    int bookId,
    String query,
  ) async {
    final db = await _dbService.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'book_notes',
      where: 'book_id = ? AND (content LIKE ? OR reader_note LIKE ?)',
      whereArgs: [bookId, '%$query%', '%$query%'],
      orderBy: 'page_number ASC, create_time DESC',
    );
    return List.generate(maps.length, (i) => BookNote.fromMap(maps[i]));
  }

  /// 获取所有书籍的注释统计
  Future<List<Map<String, int>>> selectAllBookIdAndNotes() async {
    final db = await _dbService.database;
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT book_id, COUNT(id) AS number_of_notes 
      FROM book_notes 
      GROUP BY book_id 
      ORDER BY number_of_notes DESC
    ''');
    return List.generate(
        maps.length,
        (i) => <String, int>{
              'bookId': maps[i]['book_id'] ?? 0,
              'numberOfNotes': maps[i]['number_of_notes'] ?? 0,
            }).where((element) => element['bookId'] != 0).toList();
  }

  /// 获取注释和书籍总数统计
  Future<Map<String, int>> selectNumberOfNotesAndBooks() async {
    final db = await _dbService.database;
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT COUNT(id) AS number_of_notes, 
             COUNT(DISTINCT book_id) AS number_of_books 
      FROM book_notes
    ''');
    return {
      'numberOfNotes': maps[0]['number_of_notes'] ?? 0,
      'numberOfBooks': maps[0]['number_of_books'] ?? 0,
    };
  }

  /// 获取按类型分组的统计
  Future<Map<String, int>> selectNoteStatsByType(int bookId) async {
    final db = await _dbService.database;
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT type, COUNT(id) AS count 
      FROM book_notes 
      WHERE book_id = ? 
      GROUP BY type
    ''', [bookId]);

    final stats = <String, int>{};
    for (final map in maps) {
      stats[map['type']] = map['count'];
    }
    return stats;
  }

  /// 获取最近的注释
  Future<List<BookNote>> selectRecentBookNotes(
    int bookId, {
    int limit = 10,
  }) async {
    final db = await _dbService.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'book_notes',
      where: 'book_id = ?',
      whereArgs: [bookId],
      orderBy: 'update_time DESC',
      limit: limit,
    );
    return List.generate(maps.length, (i) => BookNote.fromMap(maps[i]));
  }

  /// 获取带笔记的注释
  Future<List<BookNote>> selectBookNotesWithReaderNotes(int bookId) async {
    final db = await _dbService.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'book_notes',
      where: 'book_id = ? AND reader_note IS NOT NULL AND reader_note != ""',
      whereArgs: [bookId],
      orderBy: 'update_time DESC',
    );
    return List.generate(maps.length, (i) => BookNote.fromMap(maps[i]));
  }

  /// 合并两个注释
  BookNote _mergeBookNotes(BookNote existing, BookNote newNote) {
    // 如果新注释有笔记内容，则合并笔记
    String? mergedNote = existing.readerNote;
    if (newNote.readerNote != null && newNote.readerNote!.isNotEmpty) {
      if (mergedNote != null && mergedNote.isNotEmpty) {
        mergedNote = '$mergedNote\n\n${newNote.readerNote}';
      } else {
        mergedNote = newNote.readerNote;
      }
    }

    return existing.copyWith(
      type: newNote.type, // 使用新的类型
      color: newNote.color, // 使用新的颜色
      readerNote: mergedNote,
      updateTime: DateTime.now(),
    );
  }

  /// 批量导入注释
  Future<void> batchInsertBookNotes(List<BookNote> notes) async {
    final db = await _dbService.database;
    final batch = db.batch();

    for (final note in notes) {
      batch.insert('book_notes', note.toMap());
    }

    await batch.commit(noResult: true);
  }

  /// 获取指定时间范围内的注释
  Future<List<BookNote>> selectBookNotesByDateRange(
    int bookId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    final db = await _dbService.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'book_notes',
      where: 'book_id = ? AND create_time >= ? AND create_time <= ?',
      whereArgs: [
        bookId,
        startDate.toIso8601String(),
        endDate.toIso8601String(),
      ],
      orderBy: 'create_time ASC',
    );
    return List.generate(maps.length, (i) => BookNote.fromMap(maps[i]));
  }

  /// 获取所有注释（用于同步）
  Future<List<BookNote>> getAllNotes() async {
    final db = await _dbService.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'book_notes',
      orderBy: 'update_time DESC',
    );
    return List.generate(maps.length, (i) => BookNote.fromMap(maps[i]));
  }
}
