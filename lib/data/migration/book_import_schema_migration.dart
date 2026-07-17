// 文件说明：为书籍表增加跨平台导入来源身份字段。
// 技术要点：幂等 SQLite 迁移、部分唯一索引、兼容历史数据库。

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class BookImportSchemaMigration {
  const BookImportSchemaMigration._();

  static Future<void> migrate(DatabaseExecutor db) async {
    final info = await db.rawQuery('PRAGMA table_info(books)');
    final columns = info.map((row) => row['name'] as String).toSet();

    if (!columns.contains('source_kind')) {
      await db.execute('ALTER TABLE books ADD COLUMN source_kind TEXT');
    }
    if (!columns.contains('source_locator')) {
      await db.execute('ALTER TABLE books ADD COLUMN source_locator TEXT');
    }
    if (!columns.contains('source_modified_time')) {
      await db.execute(
        'ALTER TABLE books ADD COLUMN source_modified_time INTEGER',
      );
    }

    await db.execute(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_books_source_locator '
      'ON books(source_kind, source_locator) '
      'WHERE source_kind IS NOT NULL AND source_locator IS NOT NULL',
    );
  }
}
