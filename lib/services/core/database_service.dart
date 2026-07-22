// 文件说明：数据库底座服务，负责 SQLite 初始化、建表和版本升级。
// 技术要点：服务层、Path、Path Provider、SQLite FFI、文件系统、Flutter。

import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:xxread/data/migration/reading_schema_migration.dart';
import 'package:xxread/data/migration/book_import_schema_migration.dart';
import 'package:xxread/data/migration/webdav_sync_schema_migration.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  static Database? _database;
  static const String _dbName = 'xxread_v2.db';
  static const int _dbVersion = 19;
  static Future<Database>? _openingDatabase;

  Future<Database> get database async {
    // 如果数据库已经打开且有效，直接返回
    if (_database != null) {
      try {
        // 验证连接是否有效（iOS后台恢复时可能已失效）
        await _database!.rawQuery('SELECT 1');
        return _database!;
      } catch (e) {
        debugPrint('⚠️ 数据库连接已失效，重新打开: $e');
        _database = null;
      }
    }

    // 如果正在初始化，等待完成
    final openingDatabase = _openingDatabase;
    if (openingDatabase != null) {
      return openingDatabase;
    }

    // 开始初始化
    _openingDatabase = _initDatabase();
    try {
      _database = await _openingDatabase;
      return _database!;
    } finally {
      _openingDatabase = null;
    }
  }

  Future<Database> _initDatabase() async {
    if (!kIsWeb &&
        (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    String dbPath;
    if (!kIsWeb &&
        (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      // 桌面平台使用 path_provider
      final appDocDir = await getApplicationDocumentsDirectory();
      dbPath = appDocDir.path;
    } else {
      // 移动平台使用 sqflite 的默认路径
      dbPath = await getDatabasesPath();
    }

    final path = join(dbPath, _dbName);

    return await openDatabase(
      path,
      version: _dbVersion,
      onConfigure: _onConfigure,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onConfigure(Database db) async {
    // sqflite 默认关闭外键约束，必须在每个连接上显式开启，
    // 否则建表语句里的 ON DELETE CASCADE 不会生效。
    await db.execute('PRAGMA foreign_keys = ON');
  }

  Future<void> _onCreate(Database db, int version) async {
    await _createTables(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE reading_stats(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          date TEXT NOT NULL,
          durationInSeconds INTEGER NOT NULL
        )
      ''');
    }
    if (oldVersion < 3) {
      await db.execute(
        'ALTER TABLE books ADD COLUMN totalPages INTEGER DEFAULT 1',
      );
    }
    if (oldVersion < 4) {
      // Check if notes table exists before creating
      final notesTableExists = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='notes'",
      );
      if (notesTableExists.isEmpty) {
        await db.execute('''
          CREATE TABLE notes(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            bookId INTEGER NOT NULL,
            pageNumber INTEGER NOT NULL,
            selectedText TEXT NOT NULL,
            noteText TEXT NOT NULL,
            createDate INTEGER NOT NULL,
            updateDate INTEGER,
            FOREIGN KEY (bookId) REFERENCES books (id) ON DELETE CASCADE
          )
        ''');
      }

      // Check if highlights table exists before creating
      final highlightsTableExists = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='highlights'",
      );
      if (highlightsTableExists.isEmpty) {
        await db.execute('''
          CREATE TABLE highlights(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            bookId INTEGER NOT NULL,
            pageNumber INTEGER NOT NULL,
            selectedText TEXT NOT NULL,
            startOffset INTEGER NOT NULL,
            endOffset INTEGER NOT NULL,
            colorValue INTEGER NOT NULL,
            createDate INTEGER NOT NULL,
            FOREIGN KEY (bookId) REFERENCES books (id) ON DELETE CASCADE
          )
        ''');
      }
    }
    if (oldVersion < 5) {
      // Add content caching fields to books table
      final tableInfo = await db.rawQuery('PRAGMA table_info(books)');
      final columnNames = tableInfo.map((c) => c['name'] as String).toSet();

      if (!columnNames.contains('cached_content')) {
        await db.execute('ALTER TABLE books ADD COLUMN cached_content TEXT');
      }
      if (!columnNames.contains('cached_pages')) {
        await db.execute('ALTER TABLE books ADD COLUMN cached_pages TEXT');
      }
      if (!columnNames.contains('file_modified_time')) {
        await db.execute(
          'ALTER TABLE books ADD COLUMN file_modified_time INTEGER',
        );
      }
      if (!columnNames.contains('content_hash')) {
        await db.execute('ALTER TABLE books ADD COLUMN content_hash TEXT');
      }
      if (!columnNames.contains('table_of_contents')) {
        await db.execute('ALTER TABLE books ADD COLUMN table_of_contents TEXT');
      }
    }
    if (oldVersion < 6) {
      // Add cover image path field to books table if it doesn't exist
      final tableInfo = await db.rawQuery('PRAGMA table_info(books)');
      final hasCoverImagePath =
          tableInfo.any((column) => column['name'] == 'cover_image_path');
      if (!hasCoverImagePath) {
        await db.execute('ALTER TABLE books ADD COLUMN cover_image_path TEXT');
      }
    }
    if (oldVersion < 7) {
      // Create unified book_notes table if it doesn't exist
      final bookNotesTableExists = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='book_notes'",
      );
      if (bookNotesTableExists.isEmpty) {
        await db.execute('''
          CREATE TABLE book_notes(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            book_id INTEGER NOT NULL,
            content TEXT NOT NULL,
            cfi TEXT NOT NULL,
            chapter TEXT NOT NULL,
            type TEXT NOT NULL,
            color TEXT NOT NULL,
            reader_note TEXT,
            page_number INTEGER,
            start_offset INTEGER,
            end_offset INTEGER,
            create_time TEXT,
            update_time TEXT NOT NULL,
            FOREIGN KEY (book_id) REFERENCES books (id) ON DELETE CASCADE
          )
        ''');
      }

      // Migrate data from highlights table
      final highlightsData = await db.query('highlights');
      for (final highlight in highlightsData) {
        await db.insert('book_notes', {
          'book_id': highlight['bookId'],
          'content': highlight['selectedText'],
          'cfi':
              'offset-${highlight['startOffset']}-${highlight['endOffset']}', // Generate CFI
          'chapter': 'Unknown Chapter',
          'type': 'highlight',
          'color': _intToHexColor(highlight['colorValue'] as int),
          'reader_note': null,
          'page_number': highlight['pageNumber'],
          'start_offset': highlight['startOffset'],
          'end_offset': highlight['endOffset'],
          'create_time': DateTime.fromMillisecondsSinceEpoch(
            highlight['createDate'] as int,
          ).toIso8601String(),
          'update_time': DateTime.fromMillisecondsSinceEpoch(
            highlight['createDate'] as int,
          ).toIso8601String(),
        });
      }

      // Migrate data from notes table
      final notesData = await db.query('notes');
      for (final note in notesData) {
        await db.insert('book_notes', {
          'book_id': note['bookId'],
          'content': note['selectedText'],
          'cfi':
              'page-${note['pageNumber']}', // Generate CFI for page-based notes
          'chapter': 'Unknown Chapter',
          'type': 'note',
          'color': '66CCFF', // Default color
          'reader_note': note['noteText'],
          'page_number': note['pageNumber'],
          'start_offset': null,
          'end_offset': null,
          'create_time': DateTime.fromMillisecondsSinceEpoch(
            note['createDate'] as int,
          ).toIso8601String(),
          'update_time': note['updateDate'] != null
              ? DateTime.fromMillisecondsSinceEpoch(
                  note['updateDate'] as int,
                ).toIso8601String()
              : DateTime.fromMillisecondsSinceEpoch(
                  note['createDate'] as int,
                ).toIso8601String(),
        });
      }

      // Drop old tables after migration
      await db.execute('DROP TABLE IF EXISTS highlights');
      await db.execute('DROP TABLE IF EXISTS notes');
    }

    // Version 9: Add indexes to books and reading_stats tables for performance
    if (oldVersion < 9) {
      await _createBooksTableIndexes(db);
      await _createReadingStatsIndexes(db);
      await _createBookNotesIndexes(db);
    }
    if (oldVersion < 10) {
      final tableInfo = await db.rawQuery('PRAGMA table_info(books)');
      final columnNames = tableInfo.map((c) => c['name'] as String).toSet();
      if (!columnNames.contains('text_encoding')) {
        await db.execute('ALTER TABLE books ADD COLUMN text_encoding TEXT');
      }
    }
    if (oldVersion < 11) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS reading_sessions(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          date TEXT NOT NULL,
          bookId INTEGER,
          startTimeMs INTEGER NOT NULL,
          endTimeMs INTEGER NOT NULL,
          durationInSeconds INTEGER NOT NULL,
          pagesRead INTEGER NOT NULL DEFAULT 0
        )
      ''');
      await _createReadingSessionsIndexes(db);
    }
    if (oldVersion < 12) {
      final bookmarkInfo = await db.rawQuery('PRAGMA table_info(bookmarks)');
      final bookmarkColumns =
          bookmarkInfo.map((c) => c['name'] as String).toSet();
      if (!bookmarkColumns.contains('cfi')) {
        await db.execute('ALTER TABLE bookmarks ADD COLUMN cfi TEXT');
      }
      await _createBookmarksIndexes(db);
    }
    if (oldVersion < 13) {
      await db.execute('DROP TABLE IF EXISTS book_sources');
    }
    if (oldVersion < 14) {
      // 添加 CanonicalLocator 双轨定位字段
      await ReadingSchemaMigration.migrate(db);
    }
    if (oldVersion < 15) {
      final tableInfo = await db.rawQuery('PRAGMA table_info(books)');
      final columns =
          tableInfo.map((column) => column['name'] as String).toSet();
      if (!columns.contains('storage_type')) {
        await db.execute(
          "ALTER TABLE books ADD COLUMN storage_type TEXT NOT NULL DEFAULT 'local'",
        );
      }
      if (!columns.contains('source_id')) {
        await db.execute('ALTER TABLE books ADD COLUMN source_id TEXT');
      }
      if (!columns.contains('source_book_id')) {
        await db.execute('ALTER TABLE books ADD COLUMN source_book_id TEXT');
      }
      if (!columns.contains('source_json')) {
        await db.execute('ALTER TABLE books ADD COLUMN source_json TEXT');
      }
      if (!columns.contains('source_book_json')) {
        await db.execute('ALTER TABLE books ADD COLUMN source_book_json TEXT');
      }
      await _createBooksTableIndexes(db);
    }
    if (oldVersion < 16) {
      final bookmarkInfo = await db.rawQuery('PRAGMA table_info(bookmarks)');
      final columns =
          bookmarkInfo.map((column) => column['name'] as String).toSet();
      final additions = <String, String>{
        'anchor_key': 'TEXT',
        'chapter_index': 'INTEGER',
        'chapter_title': 'TEXT',
        'excerpt': 'TEXT',
      };
      for (final entry in additions.entries) {
        if (!columns.contains(entry.key)) {
          await db.execute(
            'ALTER TABLE bookmarks ADD COLUMN ${entry.key} ${entry.value}',
          );
        }
      }
      await _createBookmarksIndexes(db);
    }
    if (oldVersion < 17) {
      await BookImportSchemaMigration.migrate(db);
    }
    if (oldVersion < 19) {
      await WebDavSyncSchemaMigration.migrate(db);
    }
  }

  Future<void> _createTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS books(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        author TEXT,
        filePath TEXT NOT NULL,
        format TEXT NOT NULL,
        currentPage INTEGER DEFAULT 0,
        totalPages INTEGER DEFAULT 1,
        importDate INTEGER NOT NULL,
        cached_content TEXT,
        cached_pages TEXT,
        file_modified_time INTEGER,
        content_hash TEXT,
        table_of_contents TEXT,
        cover_image_path TEXT,
        text_encoding TEXT,
        last_canonical_locator TEXT,
        last_rendered_locator TEXT,
        layout_signature TEXT,
        storage_type TEXT NOT NULL DEFAULT 'local',
        source_id TEXT,
        source_book_id TEXT,
        source_json TEXT,
        source_book_json TEXT,
        source_kind TEXT,
        source_locator TEXT,
        source_modified_time INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS bookmarks(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        bookId INTEGER NOT NULL,
        pageNumber INTEGER NOT NULL,
        note TEXT,
        createDate INTEGER NOT NULL,
        cfi TEXT,
        canonical_locator TEXT,
        anchor_key TEXT,
        chapter_index INTEGER,
        chapter_title TEXT,
        excerpt TEXT,
        FOREIGN KEY (bookId) REFERENCES books (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS reading_stats(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL,
        durationInSeconds INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS reading_sessions(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL,
        bookId INTEGER,
        startTimeMs INTEGER NOT NULL,
        endTimeMs INTEGER NOT NULL,
        durationInSeconds INTEGER NOT NULL,
        pagesRead INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS book_notes(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        book_id INTEGER NOT NULL,
        content TEXT NOT NULL,
        cfi TEXT NOT NULL,
        chapter TEXT NOT NULL,
        type TEXT NOT NULL,
        color TEXT NOT NULL,
        reader_note TEXT,
        page_number INTEGER,
        start_offset INTEGER,
        end_offset INTEGER,
        canonical_locator TEXT,
        create_time TEXT,
        update_time TEXT NOT NULL,
        FOREIGN KEY (book_id) REFERENCES books (id) ON DELETE CASCADE
      )
    ''');
    // Create indexes for performance
    await _createBooksTableIndexes(db);
    await _createBookmarksIndexes(db);
    await _createReadingStatsIndexes(db);
    await _createReadingSessionsIndexes(db);
    await _createBookNotesIndexes(db);
    await WebDavSyncSchemaMigration.migrate(db);
  }

  /// 创建books表索引
  Future<void> _createBooksTableIndexes(Database db) async {
    // 为content_hash创建索引，用于快速检测重复书籍
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_books_content_hash ON books (content_hash)',
    );
    // 为importDate创建索引，用于按导入时间排序
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_books_import_date ON books (importDate DESC)',
    );
    // 为title和author创建索引，用于搜索功能
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_books_title ON books (title)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_books_author ON books (author)',
    );
    final tableInfo = await db.rawQuery('PRAGMA table_info(books)');
    final columns = tableInfo.map((column) => column['name'] as String).toSet();
    if (columns.contains('source_id') && columns.contains('source_book_id')) {
      await db.execute(
        'CREATE UNIQUE INDEX IF NOT EXISTS idx_books_source_identity '
        'ON books (source_id, source_book_id) '
        'WHERE source_id IS NOT NULL AND source_book_id IS NOT NULL',
      );
    }
    if (columns.contains('source_kind') && columns.contains('source_locator')) {
      await db.execute(
        'CREATE UNIQUE INDEX IF NOT EXISTS idx_books_source_locator '
        'ON books (source_kind, source_locator) '
        'WHERE source_kind IS NOT NULL AND source_locator IS NOT NULL',
      );
    }
  }

  /// 创建reading_stats表索引
  Future<void> _createReadingStatsIndexes(Database db) async {
    // 为date创建索引，用于快速查询日期范围
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_reading_stats_date ON reading_stats (date DESC)',
    );
  }

  /// 创建bookmarks表索引
  Future<void> _createBookmarksIndexes(Database db) async {
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_bookmarks_book_page ON bookmarks (bookId, pageNumber)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_bookmarks_book_create ON bookmarks (bookId, createDate DESC)',
    );
    final tableInfo = await db.rawQuery('PRAGMA table_info(bookmarks)');
    final columns = tableInfo.map((column) => column['name'] as String).toSet();
    if (columns.contains('anchor_key')) {
      await db.execute(
        'CREATE UNIQUE INDEX IF NOT EXISTS idx_bookmarks_book_anchor '
        'ON bookmarks (bookId, anchor_key) WHERE anchor_key IS NOT NULL',
      );
    }
  }

  /// 创建reading_sessions表索引
  Future<void> _createReadingSessionsIndexes(Database db) async {
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_reading_sessions_date ON reading_sessions (date DESC)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_reading_sessions_book_id ON reading_sessions (bookId)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_reading_sessions_start_time ON reading_sessions (startTimeMs DESC)',
    );
  }

  /// 创建book_notes表索引
  Future<void> _createBookNotesIndexes(Database db) async {
    // 为book_id创建索引，用于快速查询某本书的所有笔记
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_book_notes_book_id ON book_notes (book_id)',
    );
    // 为type创建索引，用于快速筛选笔记类型
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_book_notes_type ON book_notes (type)',
    );
  }

  /// 将整数颜色值转换为十六进制字符串(不含#前缀)
  String _intToHexColor(int colorValue) {
    return colorValue
        .toRadixString(16)
        .padLeft(8, '0')
        .substring(2)
        .toUpperCase();
  }
}
