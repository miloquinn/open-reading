// 文件说明：阅读定位 Schema 迁移——为 books、bookmarks、book_notes 表添加 CanonicalLocator 双轨定位字段。
// 技术要点：SQLite ALTER TABLE ADD COLUMN、幂等迁移（先检查列是否存在再添加）、forward-only 策略。

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// 阅读定位 Schema 迁移。
///
/// 为现有数据库表添加 CanonicalLocator 相关字段：
/// - books 表：last_canonical_locator、content_hash（已有）、layout_signature
/// - bookmarks 表：canonical_locator
/// - book_notes 表：canonical_locator
///
/// 设计原则：
/// - 幂等：每条 ALTER TABLE ADD COLUMN 前先检查列是否已存在
/// - 安全：只添加列，不删除列、不改类型、不丢数据
/// - forward-only：不提供 downgrade 执行路径（注释说明但不回退）
/// - 与 DatabaseService._onUpgrade 对齐，应在版本升级回调中调用
class ReadingSchemaMigration {
  ReadingSchemaMigration._();

  /// 当前迁移版本号，用于标识本批次迁移。
  /// DatabaseService._dbVersion 应在此批次完成后递增到包含此版本号。
  static const int migrationVersion = 14;

  /// 执行迁移。幂等：每条 ALTER TABLE 都先检查列是否已存在。
  ///
  /// 调用方式：
  /// ```dart
  /// // 在 DatabaseService._onUpgrade 中：
  /// if (oldVersion < 14) {
  ///   await ReadingSchemaMigration.migrate(db);
  /// }
  /// ```
  static Future<void> migrate(Database db) async {
    // ---- books 表 ----
    await _addColumnIfNotExists(
      db: db,
      table: 'books',
      column: 'last_canonical_locator',
      definition: 'TEXT', // CanonicalLocator JSON 序列化
    );

    // content_hash 已在 v5 迁移中添加，此处不重复

    await _addColumnIfNotExists(
      db: db,
      table: 'books',
      column: 'layout_signature',
      definition: 'TEXT', // 排版参数指纹（字号/行高/边距/视口/翻页模式等）
    );

    await _addColumnIfNotExists(
      db: db,
      table: 'books',
      column: 'last_rendered_locator',
      definition: 'TEXT', // RenderedLocator JSON 序列化（当前设备/排版位置）
    );

    // ---- bookmarks 表 ----
    await _addColumnIfNotExists(
      db: db,
      table: 'bookmarks',
      column: 'canonical_locator',
      definition: 'TEXT', // CanonicalLocator JSON 序列化
    );

    // ---- book_notes 表 ----
    await _addColumnIfNotExists(
      db: db,
      table: 'book_notes',
      column: 'canonical_locator',
      definition: 'TEXT', // CanonicalLocator JSON 序列化
    );

    // ---- 索引 ----
    // 为 canonical_locator 列创建索引，用于按 canonical 定位快速查找
    await _createIndexIfNotExists(
      db: db,
      indexName: 'idx_books_last_canonical_locator',
      table: 'books',
      column: 'last_canonical_locator',
    );

    await _createIndexIfNotExists(
      db: db,
      indexName: 'idx_bookmarks_canonical_locator',
      table: 'bookmarks',
      column: 'canonical_locator',
    );

    await _createIndexIfNotExists(
      db: db,
      indexName: 'idx_book_notes_canonical_locator',
      table: 'book_notes',
      column: 'canonical_locator',
    );
  }

  // ---- 内部实现 ----

  /// 检查列是否已存在，不存在时才执行 ALTER TABLE ADD COLUMN。
  ///
  /// SQLite 不支持 IF NOT EXISTS 用于 ADD COLUMN，
  /// 因此必须先查询 PRAGMA table_info 再决定是否执行。
  static Future<void> _addColumnIfNotExists({
    required Database db,
    required String table,
    required String column,
    required String definition,
  }) async {
    final tableInfo = await db.rawQuery('PRAGMA table_info($table)');
    final existingColumns = tableInfo
        .map((row) => row['name'] as String)
        .toSet();

    if (existingColumns.contains(column)) {
      // 列已存在，跳过（幂等保证）
      return;
    }

    await db.execute('ALTER TABLE $table ADD COLUMN $column $definition');
  }

  /// 检查索引是否已存在，不存在时才执行 CREATE INDEX。
  static Future<void> _createIndexIfNotExists({
    required Database db,
    required String indexName,
    required String table,
    required String column,
  }) async {
    // SQLite 支持 CREATE INDEX IF NOT EXISTS
    await db.execute(
      'CREATE INDEX IF NOT EXISTS $indexName ON $table ($column)',
    );
  }

  // ---- Downgrade 说明（不执行） ----
  //
  // 本迁移为 forward-only，不提供 downgrade 路径。
  // 原因：
  // 1. SQLite 不支持 ALTER TABLE DROP COLUMN（3.35.0 之前）
  // 2. 新增的列均为 nullable TEXT，旧数据不受影响
  // 3. 降级意味着丢失 CanonicalLocator 定位数据，这违反双轨定位策略
  //
  // 如果确实需要降级（如紧急回退到旧版本）：
  // - 方案 A：在旧版本代码中对新列做 null 兜底（已保证所有新字段 nullable）
  // - 方案 B：重新建表并迁移数据（代价大，不建议）
  // - 方案 C：保留新列但忽略其语义（旧版本仅读写 page_index 等旧字段）
  //
  // 推荐方案 A：旧版本代码自然兼容 nullable 新列。
}
