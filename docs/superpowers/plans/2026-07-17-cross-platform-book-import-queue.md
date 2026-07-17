# 跨平台图书导入队列实现计划

> **执行说明：** 本计划可直接按任务顺序实施，不默认触发额外规划或头脑风暴 skill。步骤使用复选框（`- [ ]`）语法跟踪验证细项。

**当前实现状态（2026-07-17）：** 任务 1–7 已完成；Dart 静态分析、全部 Flutter 测试、Android Kotlin 编译、plist/pbxproj/Swift 语法检查已通过。任务 8 仍需在装有完整 Xcode 的环境执行签名构建，并在 Android/iOS 真机验证目录授权、Files 与 iCloud Drive 可见性。

**目标：** 构建一个分阶段、顺序执行的多书导入队列，具备清晰的单书结果、持久化的 Android 目录授权、iOS 本地 Files 与应用自有 iCloud Documents 来源，以及自适应的移动端/平板 UI。

**架构：** 将文件发现与单文件导入、队列展示拆分。Android SAF 和 iCloud 作为持久化发现来源，其文档会被物化并复制到应用管理的本地库中；`On My iPhone/Open Reading/books` 已经是应用管理的库，因此直接原地注册。一个类型化队列一次只运行一个导入，把重复项视为正常的跳过结果，保留失败项以便重试，并通过现有事件总线报告库变更。

**技术栈：** Flutter/Dart、`file_picker`、`path_provider`、`sqflite_common_ffi`、Android Kotlin `DocumentsContract`/`ContentResolver`、iOS Swift `FileManager`/`NSFileCoordinator`、Flutter MethodChannel、ARB 本地化、Flutter widget/unit tests、XCTest。

## 全局约束

- 不要新增第三方依赖。使用现有 Flutter 包和原生平台 API。
- 每次只导入一本书。EPUB/PDF 解析、哈希、封面提取和 SQLite 写入绝不能并发运行。
- 保留现有的单文件 100 MB 限制和支持的扩展名：`txt`、`epub`、`pdf`、`mobi`、`azw`、`azw3`、`fb2`、`rtf`、`doc`、`docx`、`cbz`、`cbr`。
- Android 目录访问必须使用 SAF 持久化树权限。移除 `READ_EXTERNAL_STORAGE`、`WRITE_EXTERNAL_STORAGE` 和 `MANAGE_EXTERNAL_STORAGE`；不要用更宽泛的存储权限替代。
- Android SAF 和 iCloud 是来源位置。导入时会把所选来源复制到应用管理的本地 `Documents/books` 目录，因此现有 `dart:io File` 读取逻辑保持不变。
- `On My iPhone/Open Reading/books` 是应用管理的本地库。放入其中的文件会原地注册，用户删除本地书籍时也会删除这些文件。
- iCloud 容器标识必须严格保持为 `iCloud.com.niki.xxread`；保留 bundle ID `com.niki.xxread`、team `2HD5836RZ2` 和自动签名。
- iCloud 只同步源文件。SQLite、阅读进度、书签和笔记都保留在设备本地。
- 队列属于页面生命周期状态。不要在应用重启后持久化未完成的队列执行。
- 移除一个已暂存条目不会删除其源文件。后续文件夹扫描可能再次发现它。
- 删除已导入的 Android/iCloud 副本时，只删除本地管理副本。后续手动重新扫描时仍可能再次提供该来源。
- 不要手工编辑生成的本地化 Dart 文件；运行 `flutter gen-l10n`。
- 保留所有无关的脏工作区改动，只暂存当前任务拥有的文件。

---

## 文件结构

### 创建

- `lib/services/books/book_import_models.dart` — 类型化来源、阶段、结果、失败项和导入器接口。
- `lib/data/migration/book_import_schema_migration.dart` — 幂等的 v17 来源标识列和索引。
- `lib/services/books/book_import_source_service.dart` — 多文件选择、支持格式过滤、受管理根目录发现和来源物化。
- `lib/services/storage/platform_storage_bridge.dart` — Android 与 iOS 共享的类型化 MethodChannel 包装器。
- `lib/services/storage/android_book_folder_registry.dart` — 持久化的 Android 树注册与权限对齐。
- `lib/pages/import_book/import_book_controller.dart` — 暂存队列状态、顺序执行、移除、重试和汇总。
- `lib/pages/import_book/import_book_widgets.dart` — 来源卡片、队列条目、进度、汇总和粘性操作栏。
- `android/app/src/main/kotlin/com/niki/xxread/SafDirectoryBridge.kt` — Android 树选择器、持久化权限、递归列表和物化。
- `ios/Runner/Runner.entitlements` — iCloud Documents 权限声明。
- `ios/Runner/StorageBridge.swift` — iCloud 状态、列表、占位下载和协调式物化。
- `test/book_import_models_test.dart`
- `test/book_import_schema_migration_test.dart`
- `test/book_import_service_test.dart`
- `test/book_import_source_service_test.dart`
- `test/import_book_controller_test.dart`
- `test/import_book_page_test.dart`

### 修改

- `lib/models/book.dart` — 添加可空的来源标识元数据和存储常量。
- `lib/services/core/database_service.dart` — 将模式版本提升到 17，并调用导入迁移。
- `lib/services/books/book_dao.dart` — 原子化插入判定和来源标识查询。
- `lib/services/books/book_import_service.dart` — 移除选择器所有权，导入一个类型化来源并回滚归属产物。
- `lib/services/books/book_services.dart` — 导出新的 book-import 类型和服务。
- `lib/pages/import_book_page.dart` — 页面外壳和自适应布局组合。
- `lib/pages/library_page.dart` — 集中导入导航，并继续使用路由结果/event bus 刷新。
- `lib/pages/home_shell_layout_part.dart` — 一致地 await 导入路由。
- `lib/l10n/app_en.arb`
- `lib/l10n/app_zh.arb`
- `lib/l10n/app_zh_TW.arb`
- `lib/l10n/app_ja.arb`
- `android/app/src/main/AndroidManifest.xml`
- `android/app/src/main/kotlin/com/niki/xxread/MainActivity.kt`
- `ios/Runner/AppDelegate.swift`
- `ios/Runner/Info.plist`
- `ios/Runner.xcodeproj/project.pbxproj`
- `ios/RunnerTests/RunnerTests.swift`

---

### 任务 1：定义来源标识、结果以及 v17 模式

**文件：**
- 创建：`lib/services/books/book_import_models.dart`
- 创建：`lib/data/migration/book_import_schema_migration.dart`
- 修改：`lib/models/book.dart`
- 修改：`lib/services/core/database_service.dart`
- 修改：`lib/services/books/book_dao.dart`
- 测试：`test/book_import_models_test.dart`
- 测试：`test/book_import_schema_migration_test.dart`

**接口：**
- 产出：`BookImportSource`、`BookImportPhase`、`BookImportOutcome`、`BookImportResult`、`BookImportFailure`、`BookFileImporter`。
- 产出：可空的 `Book.sourceKind`、`Book.sourceLocator`、`Book.sourceModifiedTime`。
- 产出：`BookImportStore`、`BookDao.insertIfAbsentByHash()`、`BookDao.getBookBySourceLocator()`、`BookDao.getBookByFilePath()`、`BookDao.updateBookStorageLocation()`。

- [ ] **步骤 1：编写会失败的序列化与迁移测试**

```dart
test('book source identity survives map round trip', () {
  final book = Book(
    title: 'Example',
    filePath: '/managed/example.epub',
    format: 'EPUB',
    sourceKind: 'android_tree',
    sourceLocator: 'content://tree/root/document/book-1',
    sourceModifiedTime: 1721184000000,
  );

  final restored = Book.fromMap(book.toMap());

  expect(restored.sourceKind, 'android_tree');
  expect(restored.sourceLocator, 'content://tree/root/document/book-1');
  expect(restored.sourceModifiedTime, 1721184000000);
});
```

```dart
test('v17 migration adds source columns and unique locator index', () async {
  final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
  addTearDown(db.close);
  await db.execute('CREATE TABLE books(id INTEGER PRIMARY KEY, content_hash TEXT)');

  await BookImportSchemaMigration.migrate(db);

  final columns = await db.rawQuery('PRAGMA table_info(books)');
  expect(columns.map((row) => row['name']), containsAll(<String>[
    'source_kind',
    'source_locator',
    'source_modified_time',
  ]));
  final indexes = await db.rawQuery('PRAGMA index_list(books)');
  expect(
    indexes.map((row) => row['name']),
    contains('idx_books_source_locator'),
  );
});
```

- [ ] **步骤 2：运行测试并确认缺失字段/迁移会失败**

运行：

```bash
flutter test test/book_import_models_test.dart test/book_import_schema_migration_test.dart
```

预期：FAIL，因为来源字段和 `BookImportSchemaMigration` 还不存在。

- [ ] **步骤 3：添加类型化导入契约**

```dart
enum BookImportSourceKind {
  filePicker('file_picker'),
  androidTree('android_tree'),
  iosSharedDocuments('ios_shared_documents'),
  iosICloud('ios_icloud');

  const BookImportSourceKind(this.storageValue);
  final String storageValue;
}

enum BookImportOwnership { externalCopy, managedInPlace }

enum BookImportPhase { queued, checking, copying, analyzing, saving }

enum BookImportOutcome { imported, duplicateSkipped, existingRepaired }

class BookImportSource {
  const BookImportSource({
    required this.id,
    required this.kind,
    required this.ownership,
    required this.displayName,
    required this.extension,
    required this.locator,
    this.localPath,
    this.sizeBytes,
    this.modifiedTime,
  });

  final String id;
  final BookImportSourceKind kind;
  final BookImportOwnership ownership;
  final String displayName;
  final String extension;
  final String locator;
  final String? localPath;
  final int? sizeBytes;
  final int? modifiedTime;

  BookImportSource copyWithLocalPath(String path) => BookImportSource(
        id: id,
        kind: kind,
        ownership: ownership,
        displayName: displayName,
        extension: extension,
        locator: locator,
        localPath: path,
        sizeBytes: sizeBytes,
        modifiedTime: modifiedTime,
      );
}

class BookImportFailure implements Exception {
  const BookImportFailure({
    required this.code,
    required this.message,
    this.cause,
  });

  final String code;
  final String message;
  final Object? cause;
}

class BookImportResult {
  const BookImportResult({
    required this.source,
    required this.outcome,
    required this.book,
  });

  final BookImportSource source;
  final BookImportOutcome outcome;
  final Book book;
}

typedef BookImportProgress = void Function(
  BookImportPhase phase,
  double progress,
  String message,
);

abstract interface class BookFileImporter {
  Future<BookImportResult> importFile(
    BookImportSource source, {
    BookImportProgress? onProgress,
  });
}

class BookInsertDecision {
  const BookInsertDecision.inserted(this.book) : inserted = true;
  const BookInsertDecision.existing(this.book) : inserted = false;

  final bool inserted;
  final Book book;
}

abstract interface class BookImportStore {
  Future<Book?> getBookByHash(String contentHash);
  Future<Book?> getBookBySourceLocator({
    required String sourceKind,
    required String sourceLocator,
  });
  Future<Book?> getBookByFilePath(String filePath);
  Future<BookInsertDecision> insertIfAbsentByHash(Book book);
  Future<Book> updateBookStorageLocation({
    required Book book,
    required String filePath,
    required String sourceKind,
    required String sourceLocator,
    required int? sourceModifiedTime,
  });
}
```

- [ ] **步骤 4：添加来源元数据和幂等的 v17 迁移**

向 `Book`、`toMap`、`fromMap` 和 `copyWith` 添加可空字段：

```dart
final String? sourceKind;
final String? sourceLocator;
final int? sourceModifiedTime;
```

实现迁移：

```dart
class BookImportSchemaMigration {
  BookImportSchemaMigration._();
  static const int migrationVersion = 17;

  static Future<void> migrate(Database db) async {
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
```

将 `DatabaseService._dbVersion` 提升到 `17`，在 `oldVersion < 17` 时调用迁移，并把这三列加入初始的 `CREATE TABLE books` 语句。

- [ ] **步骤 5：添加原子化 DAO 判定**

```dart
Future<Book?> getBookBySourceLocator({
  required String sourceKind,
  required String sourceLocator,
}) async {
  final db = await _dbService.database;
  final rows = await db.query(
    'books',
    where: 'source_kind = ? AND source_locator = ?',
    whereArgs: [sourceKind, sourceLocator],
    limit: 1,
  );
  return rows.isEmpty ? null : Book.fromMap(rows.first);
}

Future<Book?> getBookByFilePath(String filePath) async {
  final db = await _dbService.database;
  final rows = await db.query(
    'books',
    where: 'filePath = ?',
    whereArgs: [filePath],
    limit: 1,
  );
  return rows.isEmpty ? null : Book.fromMap(rows.first);
}

Future<BookInsertDecision> insertIfAbsentByHash(Book book) async {
  final db = await _dbService.database;
  return db.transaction((txn) async {
    final rows = await txn.query(
      'books',
      where: 'content_hash = ?',
      whereArgs: [book.contentHash],
      limit: 1,
    );
    if (rows.isNotEmpty) {
      return BookInsertDecision.existing(Book.fromMap(rows.first));
    }
    final id = await txn.insert('books', book.toMap());
    return BookInsertDecision.inserted(book.copyWith(id: id));
  });
}

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
```

不要在 v17 中把 `content_hash` 设为全局唯一；历史重复项可能存在，不能自动删除。

- [ ] **步骤 6：运行定向测试**

运行：

```bash
flutter test test/book_import_models_test.dart test/book_import_schema_migration_test.dart
```

预期：PASS。

- [ ] **步骤 7：提交模式契约**

```bash
git add lib/services/books/book_import_models.dart lib/data/migration/book_import_schema_migration.dart lib/models/book.dart lib/services/core/database_service.dart lib/services/books/book_dao.dart test/book_import_models_test.dart test/book_import_schema_migration_test.dart
git commit -m "Make import source identity durable before adding queues" \
  -m "Directory and iCloud sources need stable identities independent of temporary local paths. Add nullable source metadata and an idempotent v17 migration while retaining hash checks for content-level duplicates." \
  -m "Constraint: Historical content hashes are not assumed unique" \
  -m "Confidence: high" \
  -m "Scope-risk: moderate" \
  -m "Tested: Book map round trip and in-memory v17 migration tests"
```

---

### 任务 2：将单文件导入器重构为可重试的类型化服务

**文件：**
- 修改：`lib/services/books/book_import_service.dart`
- 修改：`lib/services/books/book_services.dart`
- 测试：`test/book_import_service_test.dart`

**接口：**
- 消费：`BookImportSource`、`BookImportResult`、`BookImportFailure`、`BookDao.insertIfAbsentByHash()`。
- 产出：`BookImportService implements BookFileImporter`。
- 产出：感知来源的外部复制与原地管理行为。

- [ ] **步骤 1：编写会失败的导入器测试**

```dart
test('duplicate is returned as skipped instead of thrown', () async {
  final sourceFile = await fixtureFile('same.txt', 'same content');
  final existing = Book(
    id: 7,
    title: 'Existing',
    filePath: sourceFile.path,
    format: 'TXT',
    contentHash: md5.convert(utf8.encode('same content')).toString(),
  );
  final importer = testImporter(existingBooks: [existing]);

  final result = await importer.importFile(externalSource(sourceFile));

  expect(result.outcome, BookImportOutcome.duplicateSkipped);
  expect(result.book.id, 7);
});

test('managed source is never copied onto itself', () async {
  final managed = await fixtureFile('managed.txt', 'managed content');
  final importer = testImporter(managedBooksDirectory: managed.parent);

  final result = await importer.importFile(managedSource(managed));

  expect(result.outcome, BookImportOutcome.imported);
  expect(result.book.filePath, managed.path);
  expect(await managed.exists(), isTrue);
});

test('failed external import removes only owned partial files', () async {
  final sourceFile = await fixtureFile('broken.txt', 'broken');
  final importer = testImporter(failBeforeInsert: true);

  await expectLater(
    importer.importFile(externalSource(sourceFile)),
    throwsA(isA<BookImportFailure>()),
  );

  expect(await sourceFile.exists(), isTrue);
  expect(await importer.partialFiles(), isEmpty);
});
```

- [ ] **步骤 2：运行测试并确认基于路径的导入器尚未存在**

运行：

```bash
flutter test test/book_import_service_test.dart
```

预期：FAIL，因为 `importFile()` 和类型化结果还不存在。

- [ ] **步骤 3：让哈希与重复项查找在失败时收敛**

在保留生产默认值的同时，让 `BookImportService` 接受可测试边界：

```dart
typedef ImportMetadataExtractor = Future<EnhancedBookMetadata> Function(
  String filePath,
  String fileName,
  String extension,
  void Function(double progress, String message)? onProgress,
);

class BookImportService implements BookFileImporter {
  BookImportService({
    BookImportStore? store,
    Future<Directory> Function()? documentsDirectory,
    ImportMetadataExtractor? metadataExtractor,
    Future<void> Function(Book book)? scheduleAnalysis,
  })  : _store = store ?? BookDao(),
        _documentsDirectory =
            documentsDirectory ?? getApplicationDocumentsDirectory,
        _metadataExtractorOverride = metadataExtractor,
        _scheduleAnalysis = scheduleAnalysis ??
            ((book) async {
              GlobalAIReadingService().scheduleImportedBookAnalysis(book: book);
            });

  final BookImportStore _store;
  final Future<Directory> Function() _documentsDirectory;
  final ImportMetadataExtractor? _metadataExtractorOverride;
  final Future<void> Function(Book book) _scheduleAnalysis;
}
```

让 `BookDao` 实现 `BookImportStore`。测试会使用内存中的 `FakeBookImportStore`、临时 documents 目录、无封面的元数据以及空操作分析回调。

修改 `_calculateFileHash()` 和重复项查找逻辑，使 I/O 或数据库失败时抛出 `BookImportFailure`，而不是返回 `null`。没有经过验证哈希的来源绝不能进入数据库插入阶段。

```dart
Future<String> _calculateRequiredHash(String filePath) async {
  try {
    final file = File(filePath);
    if (!await file.exists()) {
      throw const BookImportFailure(
        code: 'source_missing',
        message: 'Source file is missing',
      );
    }
    final size = await file.length();
    if (size < 5 * 1024 * 1024) {
      return md5.convert(await file.readAsBytes()).toString();
    }
    final result = await compute(
      calculateFileHashInIsolate,
      HashCalculationParams(filePath: filePath),
    );
    return result.hash;
  } on BookImportFailure {
    rethrow;
  } catch (error) {
    throw BookImportFailure(
      code: 'hash_failed',
      message: 'Unable to verify file content',
      cause: error,
    );
  }
}
```

- [ ] **步骤 4：实现外部复制和原地管理的准备逻辑**

对外部复制使用 `.partial` 目标文件并通过原子重命名完成。受管理文件保持原始路径不变。

```dart
Future<_PreparedImportFile> _prepareFile(
  BookImportSource source,
  String sourceHash,
  BookImportProgress? onProgress,
) async {
  final sourcePath = source.localPath;
  if (sourcePath == null) {
    throw const BookImportFailure(
      code: 'source_not_materialized',
      message: 'Source file is not available locally',
    );
  }
  if (source.ownership == BookImportOwnership.managedInPlace) {
    return _PreparedImportFile(
      file: File(sourcePath),
      ownsFile: false,
      contentHash: sourceHash,
    );
  }

  final booksDir = await _managedBooksDirectory();
  final finalFile = await _allocateTarget(booksDir, source.displayName);
  final partial = File('${finalFile.path}.partial');
  await _copyFileWithProgress(
    File(sourcePath),
    partial,
    progressCallback: (value) => onProgress?.call(
      BookImportPhase.copying,
      value,
      'copying',
    ),
  );
  final copiedHash = await _calculateRequiredHash(partial.path);
  if (copiedHash != sourceHash) {
    await partial.delete();
    throw const BookImportFailure(
      code: 'copy_verification_failed',
      message: 'Copied file did not match its source',
    );
  }
  await partial.rename(finalFile.path);
  return _PreparedImportFile(
    file: finalFile,
    ownsFile: true,
    contentHash: copiedHash,
  );
}
```

`_allocateTarget()` 在占用名称达到 1000 个后必须抛出异常，而不是返回一个已存在的路径。

- [ ] **步骤 5：实现类型化导入编排与回滚**

```dart
@override
Future<BookImportResult> importFile(
  BookImportSource source, {
  BookImportProgress? onProgress,
}) async {
  _PreparedImportFile? prepared;
  String? createdCoverPath;
  var databaseCommitted = false;
  try {
    onProgress?.call(BookImportPhase.checking, 0, 'checking');
    final localPath = source.localPath;
    if (localPath == null) {
      throw const BookImportFailure(
        code: 'source_not_materialized',
        message: 'Source file is not available locally',
      );
    }
    final sourceFile = File(localPath);
    final size = await sourceFile.length();
    if (size > 100 * 1024 * 1024) {
      throw const BookImportFailure(
        code: 'file_too_large',
        message: 'The file exceeds the 100 MB limit',
      );
    }
    final sourceHash = await _calculateRequiredHash(localPath);
    final duplicate = await _store.getBookByHash(sourceHash);
    if (duplicate != null && await File(duplicate.filePath).exists()) {
      return BookImportResult(
        source: source,
        outcome: BookImportOutcome.duplicateSkipped,
        book: duplicate,
      );
    }

    if (duplicate != null) {
      prepared = await _prepareFile(source, sourceHash, onProgress);
      final repaired = await _store.updateBookStorageLocation(
        book: duplicate,
        filePath: prepared.file.path,
        sourceKind: source.kind.storageValue,
        sourceLocator: source.locator,
        sourceModifiedTime: source.modifiedTime,
      );
      databaseCommitted = true;
      LibraryEventBus().notifyLibraryChanged();
      return BookImportResult(
        source: source,
        outcome: BookImportOutcome.existingRepaired,
        book: repaired,
      );
    }

    prepared = await _prepareFile(source, sourceHash, onProgress);
    onProgress?.call(BookImportPhase.analyzing, 0, 'analyzing');
    final progressAdapter = (double progress, String _) => onProgress?.call(
          BookImportPhase.analyzing,
          progress,
          'analyzing',
        );
    final metadata = _metadataExtractorOverride != null
        ? await _metadataExtractorOverride!(
            prepared.file.path,
            source.displayName,
            source.extension,
            progressAdapter,
          )
        : await _extractEnhancedMetadataFromFile(
            prepared.file.path,
            source.displayName,
            source.extension,
            progressCallback: progressAdapter,
          );
    if (metadata.coverImage != null) {
      createdCoverPath = await _saveCoverImage(
        metadata.coverImage!,
        source.displayName,
      );
    }
    final candidate = Book(
      title: metadata.title,
      author: metadata.author,
      filePath: prepared.file.path,
      format: source.extension.toUpperCase(),
      totalPages: metadata.estimatedPages,
      coverImagePath: createdCoverPath,
      contentHash: prepared.contentHash,
      textEncoding: metadata.textEncoding,
      sourceKind: source.kind.storageValue,
      sourceLocator: source.locator,
      sourceModifiedTime: source.modifiedTime,
    );
    onProgress?.call(BookImportPhase.saving, 0, 'saving');
    final decision = await _store.insertIfAbsentByHash(candidate);
    if (!decision.inserted) {
      return BookImportResult(
        source: source,
        outcome: BookImportOutcome.duplicateSkipped,
        book: decision.book,
      );
    }
    databaseCommitted = true;
    LibraryEventBus().notifyLibraryChanged();
    unawaited(_scheduleAnalysis(decision.book));
    return BookImportResult(
      source: source,
      outcome: BookImportOutcome.imported,
      book: decision.book,
    );
  } on BookImportFailure {
    rethrow;
  } catch (error) {
    throw BookImportFailure(
      code: 'import_failed',
      message: 'Book import failed',
      cause: error,
    );
  } finally {
    if (!databaseCommitted && prepared?.ownsFile == true) {
      final file = prepared!.file;
      if (await file.exists()) await file.delete();
    }
    if (!databaseCommitted && createdCoverPath != null) {
      final cover = File(createdCoverPath);
      if (await cover.exists()) await cover.delete();
    }
  }
}
```

在宣布数据库操作完成之前，必须先完成 EPUB image-map 持久化；或者显式把 image-map 失败降级为提交后的非致命日志警告，这样已成功插入的书籍就不会被误报为失败。

- [ ] **步骤 6：运行导入器测试**

运行：

```bash
flutter test test/book_import_service_test.dart
```

预期：PASS，且临时管理目录中不应残留任何 `.partial` 产物。

- [ ] **步骤 7：提交导入器重构**

```bash
git add lib/services/books/book_import_service.dart lib/services/books/book_services.dart test/book_import_service_test.dart
git commit -m "Make one-file import safe enough to drive a queue" \
  -m "Separate selection from import, return typed duplicate outcomes, verify copies before rename, and clean only artifacts owned by the failed attempt." \
  -m "Constraint: Existing metadata extractors remain behaviorally unchanged" \
  -m "Rejected: Parallel import execution | EPUB and PDF parsing would amplify memory and consistency risk" \
  -m "Confidence: high" \
  -m "Scope-risk: moderate" \
  -m "Tested: Duplicate, managed-in-place, rollback, and retry-safe importer tests"
```

---

### 任务 3：构建来源发现与顺序队列控制器

**文件：**
- 创建：`lib/services/books/book_import_source_service.dart`
- 创建：`lib/services/storage/platform_storage_bridge.dart`
- 创建：`lib/pages/import_book/import_book_controller.dart`
- 测试：`test/book_import_source_service_test.dart`
- 测试：`test/import_book_controller_test.dart`

**接口：**
- 消费：`BookFileImporter.importFile()`。
- 产出：`BookImportSourceService.pickFiles()`、`scanIosSharedDocuments()`、`materialize()`。
- 产出：`ImportBookController.addSources()`、`start()`、`retryFailed()`、`removeQueued()`。

- [ ] **步骤 1：编写会失败的队列测试**

```dart
test('imports sequentially and continues after a failure', () async {
  final importer = RecordingImporter(<String, Object>{
    'a': importedResult('a'),
    'b': const BookImportFailure(code: 'broken', message: 'broken'),
    'c': importedResult('c'),
  });
  final controller = ImportBookController(
    importer: importer,
    sourcePreparer: PassthroughSourcePreparer(),
  );
  controller.addSources([source('a'), source('b'), source('c')]);

  await controller.start();

  expect(importer.maxConcurrent, 1);
  expect(importer.order, ['a', 'b', 'c']);
  expect(controller.succeededCount, 2);
  expect(controller.failedCount, 1);
});

BookImportSource source(String id) => BookImportSource(
      id: id,
      kind: BookImportSourceKind.filePicker,
      ownership: BookImportOwnership.externalCopy,
      displayName: '$id.txt',
      extension: 'txt',
      locator: '/tmp/$id.txt',
      localPath: '/tmp/$id.txt',
    );

BookImportResult importedResult(String id) => BookImportResult(
      source: source(id),
      outcome: BookImportOutcome.imported,
      book: Book(
        id: id.hashCode,
        title: id,
        filePath: '/managed/$id.txt',
        format: 'TXT',
      ),
    );

BookImportResult duplicateResult(String id) => BookImportResult(
      source: source(id),
      outcome: BookImportOutcome.duplicateSkipped,
      book: Book(
        id: id.hashCode,
        title: id,
        filePath: '/managed/$id.txt',
        format: 'TXT',
      ),
    );

test('duplicate is skipped and is not retried', () async {
  final importer = RecordingImporter(<String, Object>{
    'a': duplicateResult('a'),
  });
  final controller = ImportBookController(
    importer: importer,
    sourcePreparer: PassthroughSourcePreparer(),
  );
  controller.addSources([source('a')]);

  await controller.start();
  await controller.retryFailed();

  expect(controller.skippedCount, 1);
  expect(importer.order, ['a']);
});
```

- [ ] **步骤 2：编写会失败的来源选择测试**

```dart
test('file picker creates stable, case-insensitive supported sources', () async {
  final picker = FakePickerResult([
    platformFile('/tmp/A.EPUB', 100),
    platformFile('/tmp/readme.json', 20),
  ]);
  final service = BookImportSourceService(filePicker: picker);

  final sources = await service.pickFiles();

  expect(sources, hasLength(1));
  expect(sources.single.extension, 'epub');
  expect(sources.single.kind, BookImportSourceKind.filePicker);
});
```

- [ ] **步骤 3：运行测试并确认控制器/服务尚未存在**

运行：

```bash
flutter test test/book_import_source_service_test.dart test/import_book_controller_test.dart
```

预期：FAIL，因为来源服务和控制器都还不存在。

- [ ] **步骤 4：实现 MethodChannel 包装器**

```dart
class PlatformStorageBridge {
  PlatformStorageBridge({MethodChannel? channel})
      : _channel = channel ?? const MethodChannel('com.niki.xxread/storage');

  final MethodChannel _channel;

  Future<Map<String, Object?>?> pickAndroidDirectory() async {
    return _channel.invokeMapMethod<String, Object?>('pickDirectory');
  }

  Future<List<Map<String, Object?>>> listAndroidDocuments(
    String treeUri,
  ) async {
    final rows = await _channel.invokeListMethod<Map<Object?, Object?>>(
          'listDocuments',
          {'treeUri': treeUri},
        ) ??
        const [];
    return rows
        .map((row) => row.map((key, value) => MapEntry('$key', value)))
        .toList(growable: false);
  }

  Future<String> materializeAndroidDocument({
    required String documentUri,
    required String destinationPath,
  }) async {
    final path = await _channel.invokeMethod<String>(
      'materializeDocument',
      {'documentUri': documentUri, 'destinationPath': destinationPath},
    );
    if (path == null) throw StateError('Android materialization returned null');
    return path;
  }

  Future<Map<String, Object?>> getICloudStatus() async {
    return await _channel.invokeMapMethod<String, Object?>('getICloudStatus') ??
        const {'available': false};
  }

  Future<List<Map<String, Object?>>> listICloudDocuments() async {
    final rows = await _channel.invokeListMethod<Map<Object?, Object?>>(
          'listICloudDocuments',
        ) ??
        const [];
    return rows
        .map((row) => row.map((key, value) => MapEntry('$key', value)))
        .toList(growable: false);
  }

  Future<String> materializeICloudDocument({
    required String relativePath,
    required String destinationPath,
  }) async {
    final path = await _channel.invokeMethod<String>(
      'materializeICloudDocument',
      {'relativePath': relativePath, 'destinationPath': destinationPath},
    );
    if (path == null) throw StateError('iCloud materialization returned null');
    return path;
  }
}
```

- [ ] **步骤 5：实现多文件选择与物化**

`BookImportSourceService.pickFiles()` 必须调用：

```dart
final result = await FilePicker.platform.pickFiles(
  type: FileType.custom,
  allowedExtensions: supportedBookExtensions.toList(growable: false),
  allowMultiple: true,
  withData: false,
);
```

将每个可用路径映射为 `externalCopy` 来源。对于没有 `localPath` 的 Android 和 iCloud 来源，将其物化到 `getTemporaryDirectory()/book_import_staging/<source-id>/<display-name>`，返回 `copyWithLocalPath(path)`，并在每个队列项完成后删除该暂存目录。

```dart
class BookImportMaterialization {
  const BookImportMaterialization({
    required this.source,
    required this.cleanup,
  });

  final BookImportSource source;
  final Future<void> Function() cleanup;
}

abstract interface class BookImportSourcePreparer {
  Future<BookImportMaterialization> materialize(BookImportSource source);
}

class PassthroughSourcePreparer implements BookImportSourcePreparer {
  @override
  Future<BookImportMaterialization> materialize(
    BookImportSource source,
  ) async {
    return BookImportMaterialization(
      source: source,
      cleanup: () async {},
    );
  }
}
```

- [ ] **步骤 6：实现不可变队列项与顺序控制器**

```dart
enum ImportQueueStatus { queued, importing, succeeded, duplicate, failed }

class ImportQueueItem {
  const ImportQueueItem({
    required this.source,
    this.status = ImportQueueStatus.queued,
    this.phase = BookImportPhase.queued,
    this.progress = 0,
    this.attempts = 0,
    this.result,
    this.failure,
  });

  final BookImportSource source;
  final ImportQueueStatus status;
  final BookImportPhase phase;
  final double progress;
  final int attempts;
  final BookImportResult? result;
  final BookImportFailure? failure;

  ImportQueueItem copyWith({
    ImportQueueStatus? status,
    BookImportPhase? phase,
    double? progress,
    int? attempts,
    BookImportResult? result,
    BookImportFailure? failure,
    bool clearFailure = false,
  }) {
    return ImportQueueItem(
      source: source,
      status: status ?? this.status,
      phase: phase ?? this.phase,
      progress: progress ?? this.progress,
      attempts: attempts ?? this.attempts,
      result: result ?? this.result,
      failure: clearFailure ? null : failure ?? this.failure,
    );
  }
}

class ImportBookController extends ChangeNotifier {
  ImportBookController({
    required BookFileImporter importer,
    required BookImportSourcePreparer sourcePreparer,
  })  : _importer = importer,
        _sourcePreparer = sourcePreparer;

  final BookFileImporter _importer;
  final BookImportSourcePreparer _sourcePreparer;
  final List<ImportQueueItem> _items = [];
  bool _running = false;

  List<ImportQueueItem> get items => List.unmodifiable(_items);
  bool get isRunning => _running;
  int get succeededCount => _items.where((item) =>
      item.status == ImportQueueStatus.succeeded).length;
  int get skippedCount => _items.where((item) =>
      item.status == ImportQueueStatus.duplicate).length;
  int get failedCount => _items.where((item) =>
      item.status == ImportQueueStatus.failed).length;
  bool get hasLibraryChanges => succeededCount > 0;

  void addSources(Iterable<BookImportSource> sources) {
    final existing = _items.map((item) => item.source.id).toSet();
    for (final source in sources) {
      if (existing.add(source.id)) {
        _items.add(ImportQueueItem(source: source));
      }
    }
    notifyListeners();
  }

  void removeQueued(String id) {
    if (_running) return;
    _items.removeWhere((item) =>
        item.source.id == id && item.status == ImportQueueStatus.queued);
    notifyListeners();
  }

  Future<void> start() async {
    if (_running) return;
    _running = true;
    notifyListeners();
    try {
      for (var index = 0; index < _items.length; index++) {
        if (_items[index].status != ImportQueueStatus.queued) continue;
        await _runItem(index);
      }
    } finally {
      _running = false;
      notifyListeners();
    }
  }

  Future<void> retryFailed() async {
    for (var index = 0; index < _items.length; index++) {
      if (_items[index].status == ImportQueueStatus.failed) {
        _items[index] = ImportQueueItem(source: _items[index].source);
      }
    }
    await start();
  }

  Future<void> _runItem(int index) async {
    final queued = _items[index];
    _items[index] = queued.copyWith(
      status: ImportQueueStatus.importing,
      attempts: queued.attempts + 1,
      clearFailure: true,
    );
    notifyListeners();

    BookImportMaterialization? materialization;
    try {
      materialization = await _sourcePreparer.materialize(queued.source);
      final result = await _importer.importFile(
        materialization.source,
        onProgress: (phase, progress, _) {
          _items[index] = _items[index].copyWith(
            phase: phase,
            progress: progress,
          );
          notifyListeners();
        },
      );
      _items[index] = _items[index].copyWith(
        status: result.outcome == BookImportOutcome.duplicateSkipped
            ? ImportQueueStatus.duplicate
            : ImportQueueStatus.succeeded,
        progress: 1,
        result: result,
      );
    } on BookImportFailure catch (failure) {
      _items[index] = _items[index].copyWith(
        status: ImportQueueStatus.failed,
        failure: failure,
      );
    } finally {
      await materialization?.cleanup();
      notifyListeners();
    }
  }
}
```

实现 `_runItem()` 时，要更新 phase/progress、捕获 `BookImportFailure`、把重复结果映射为 `duplicate`、继续处理下一个条目，并始终清理临时物化内容。

- [ ] **步骤 7：运行队列/来源测试**

运行：

```bash
flutter test test/book_import_source_service_test.dart test/import_book_controller_test.dart
```

预期：PASS；`RecordingImporter.maxConcurrent` 保持为 `1`。

- [ ] **步骤 8：提交队列引擎**

```bash
git add lib/services/books/book_import_source_service.dart lib/services/storage/platform_storage_bridge.dart lib/pages/import_book/import_book_controller.dart test/book_import_source_service_test.dart test/import_book_controller_test.dart
git commit -m "Keep batch imports sequential and individually recoverable" \
  -m "Introduce typed source discovery and a page-lifetime queue that continues after failures, treats duplicates as skipped, and retries only failed items." \
  -m "Constraint: Queue execution is not persisted across process death" \
  -m "Confidence: high" \
  -m "Scope-risk: moderate" \
  -m "Tested: Sequential ordering, duplicate skip, failure continuation, removal, and retry tests"
```

---

### 任务 4：构建自适应导入队列 UI 和本地化

**文件：**
- 创建：`lib/pages/import_book/import_book_widgets.dart`
- 修改：`lib/pages/import_book_page.dart`
- 修改：`lib/l10n/app_en.arb`
- 修改：`lib/l10n/app_zh.arb`
- 修改：`lib/l10n/app_zh_TW.arb`
- 修改：`lib/l10n/app_ja.arb`
- 测试：`test/import_book_page_test.dart`

**接口：**
- 消费：`ImportBookController` 和 `BookImportSourceService`。
- 产出：仅当 `controller.hasLibraryChanges` 为 true 时返回路由结果 `true`。

- [ ] **步骤 1：为四种页面状态编写 widget 测试**

```dart
testWidgets('staged queue allows removal and starts N books', (tester) async {
  final controller = fakeControllerWithQueuedBooks(3);
  await pumpImportPage(tester, controller: controller, width: 390, height: 844);

  expect(find.byKey(const ValueKey('import-queue-list')), findsOneWidget);
  expect(find.text('导入 3 本'), findsOneWidget);

  await tester.tap(find.byKey(const ValueKey('remove-book-2')));
  await tester.pump();

  expect(find.text('导入 2 本'), findsOneWidget);
});

testWidgets('summary exposes retry only when failures exist', (tester) async {
  final controller = fakeCompletedController(success: 2, skipped: 1, failed: 1);
  await pumpImportPage(tester, controller: controller, width: 390, height: 844);

  expect(find.byKey(const ValueKey('import-summary')), findsOneWidget);
  expect(find.byKey(const ValueKey('retry-failed')), findsOneWidget);
  expect(find.byKey(const ValueKey('import-done')), findsOneWidget);
});
```

在 `390×844`、`820×1180` 和 `1280×800` 下添加布局测试；每个测试都必须以 `tester.takeException() == null` 结束。

- [ ] **步骤 2：运行 widget 测试并确认新页面状态尚未存在**

运行：

```bash
flutter test test/import_book_page_test.dart
```

预期：FAIL，因为队列 widget 和 key 都还不存在。

- [ ] **步骤 3：添加本地化文案**

在每个 ARB 中添加对应的 `import*` key。英文元数据仍然作为模板来源。所需含义如下：

- `importChooseFiles`: Choose files / 选择文件
- `importAddFolder`: Add book folder / 添加书籍目录
- `importFilesAndICloud`: Files & iCloud Drive / 文件与 iCloud Drive
- `importScanLocalFolder`: Scan Open Reading folder / 扫描 Open Reading 文件夹
- `importScanICloudFolder`: Sync from iCloud / 从 iCloud 同步
- `importQueueTitle(count)`: `{count} books ready`
- `importStart(count)`: `Import {count} books`
- `importStatusQueued`, `importStatusChecking`, `importStatusCopying`, `importStatusAnalyzing`, `importStatusSaving`, `importStatusSucceeded`, `importStatusDuplicate`, `importStatusFailed`
- `importSummaryCounts(succeeded, skipped, failed)`
- `importRetryFailed(count)`, `importContinueAdding`, `importDone`
- `importRemoveFromQueue`, `importFolderEmpty`, `importFolderPermissionLost`, `importICloudUnavailable`, `importCloudDownloading`
- `importLocalFolderOwnershipHint`：说明 `Open Reading/books` 中的文件就是本地书库内容，删除书籍时也会删除对应文件。
- `importExternalSourceCopyHint`：说明应用会导入本地副本，因此 Android/iCloud 来源文件保持不变。

运行：

```bash
flutter gen-l10n
```

- [ ] **步骤 4：构建页面组合**

使用 `PageStyleHelper.backgroundGradient`、`PageStyleHelper.palette`、`LayoutHelper`、现有的 `ColorScheme.surfaceContainer*`，以及 14/18/24 圆角。

页面状态：

1. 空状态：主说明卡片、平台来源卡片、支持格式与 100 MB 限制提示。
2. 已暂存：数量与总大小、可移除条目、固定在底部的“导入 N 本”操作。
3. 导入中：总体进度、当前条目进度、文字阶段说明，以及使用 `PopScope(canPop: false)` 锁定的导航。
4. 汇总状态：成功/跳过/失败计数、重试失败项、继续添加和完成操作。

响应式布局：

```dart
final twoPane = constraints.maxWidth >= 900;
final content = ConstrainedBox(
  constraints: const BoxConstraints(maxWidth: 1120),
  child: twoPane
      ? Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 340, child: sourceAndSummaryPane),
            const SizedBox(width: 20),
            Expanded(child: queuePane),
          ],
        )
      : Column(
          children: [sourceAndSummaryPane, const SizedBox(height: 16), queuePane],
        ),
);
```

每一行状态都必须包含图标和文本；颜色不能是唯一信号。所有删除/重试触控目标都必须至少为 44×44 逻辑像素。队列使用 `ListView.builder`。

- [ ] **步骤 5：运行本地化和 UI 测试**

运行：

```bash
flutter gen-l10n
flutter test test/import_book_page_test.dart
```

预期：在四种语言环境和三个视口尺寸下都 PASS。

- [ ] **步骤 6：提交 UI/UX 层**

```bash
git add lib/pages/import_book_page.dart lib/pages/import_book/import_book_widgets.dart lib/l10n/app_en.arb lib/l10n/app_zh.arb lib/l10n/app_zh_TW.arb lib/l10n/app_ja.arb lib/l10n/app_localizations*.dart test/import_book_page_test.dart
git commit -m "Let users review and recover multi-book imports" \
  -m "Replace the one-button import page with an adaptive staged queue, explicit per-book states, duplicate skip feedback, failure retry, and a final summary." \
  -m "Constraint: Status meaning must not depend on color alone" \
  -m "Confidence: high" \
  -m "Scope-risk: moderate" \
  -m "Tested: Localized empty, staged, importing, summary, interaction, and viewport widget tests"
```

---

### 任务 5：添加持久化的 Android SAF 目录来源

**文件：**
- 创建：`android/app/src/main/kotlin/com/niki/xxread/SafDirectoryBridge.kt`
- 创建：`lib/services/storage/android_book_folder_registry.dart`
- 修改：`android/app/src/main/kotlin/com/niki/xxread/MainActivity.kt`
- 修改：`android/app/src/main/AndroidManifest.xml`
- 修改：`lib/services/books/book_import_source_service.dart`
- 测试：`test/book_import_source_service_test.dart`

**接口：**
- 产出原生方法：`pickDirectory`、`getPersistedDirectories`、`releaseDirectory`、`listDocuments`、`materializeDocument`。
- 产出 Dart 方法：`addAndroidFolder()`、`scanAndroidFolder()`、`removeAndroidFolder()`。

- [ ] **步骤 1：添加会失败的 MethodChannel 映射测试**

测试 `pickDirectory` 是否保留 `treeUri` 和显示名称、递归列表是否只映射支持的文件，以及 `materializeDocument` 接收到的是文档 URI 而不是伪造的文件系统路径。

```dart
expect(invocations, contains(predicate<MethodCall>((call) {
  return call.method == 'materializeDocument' &&
      (call.arguments as Map)['documentUri'] ==
          'content://provider/tree/root/document/book-1';
})));
```

- [ ] **步骤 2：移除宽泛的存储权限**

删除这些 manifest 条目：

```xml
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.MANAGE_EXTERNAL_STORAGE" />
```

SAF 不需要替代权限。

- [ ] **步骤 3：实现 SAF 桥接**

`SafDirectoryBridge` 拥有请求码 `4107`、一个待处理的选择器结果和该 channel。`pickDirectory` 启动：

```kotlin
val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
    addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
    addFlags(Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION)
    addFlags(Intent.FLAG_GRANT_PREFIX_URI_PERMISSION)
}
activity.startActivityForResult(intent, REQUEST_OPEN_TREE)
```

在返回结果时，只保留结果 intent 实际授予的标志：

```kotlin
val takeFlags = data.flags and
    Intent.FLAG_GRANT_READ_URI_PERMISSION
activity.contentResolver.takePersistableUriPermission(uri, takeFlags)
```

使用 `contentResolver.persistedUriPermissions` 作为权限真相来源。通过 `DocumentsContract.buildChildDocumentsUriUsingTree` 递归列表，查询 `COLUMN_DOCUMENT_ID`、`COLUMN_DISPLAY_NAME`、`COLUMN_MIME_TYPE`、`COLUMN_SIZE` 和 `COLUMN_LAST_MODIFIED`。返回使用 `DocumentsContract.buildDocumentUriUsingTree` 构造的文档 URI。

使用缓冲流进行物化：

```kotlin
contentResolver.openInputStream(Uri.parse(documentUri)).use { input ->
    requireNotNull(input) { "Unable to open document" }
    FileOutputStream(File(destinationPath)).use { output ->
        input.copyTo(output, DEFAULT_BUFFER_SIZE)
    }
}
```

在 `catch` 中删除不完整的目标文件，再返回 `FlutterError`。

- [ ] **步骤 4：注册并转发 activity 结果**

在 `MainActivity.configureFlutterEngine()` 中，使用 channel 名称 `com.niki.xxread/storage` 实例化桥接器。在 `onActivityResult()` 中，先让桥接器处理请求 `4107`，再对无关请求调用 `super`。

- [ ] **步骤 5：持久化显示元数据并对齐权限状态**

`AndroidBookFolderRegistry` 只把面向用户的元数据存进 SharedPreferences。每次加载时，都要把它与原生 `getPersistedDirectories` 求交集；缺失的原生权限会变成 `permissionLost`，不会被扫描。

```dart
class AndroidBookFolder {
  const AndroidBookFolder({
    required this.treeUri,
    required this.displayName,
    required this.permissionAvailable,
  });

  final String treeUri;
  final String displayName;
  final bool permissionAvailable;
}
```

- [ ] **步骤 6：把 Android 文件夹发现接到暂存流程**

当用户添加或刷新文件夹时：

1. 递归列出目录内容。
2. 不区分大小写地过滤受支持扩展名。
3. 先按小写相对路径排序，再按 URI 排序。
4. 排除 `BookDao.getBookBySourceLocator()` 已返回的来源定位符。
5. 将剩余来源加入队列，并设置 `kind=androidTree`、`ownership=externalCopy`、`localPath=null`。

不要自动开始导入；保留暂存审核步骤。

- [ ] **步骤 7：验证 Android 构建和 Dart 测试**

运行：

```bash
flutter test test/book_import_source_service_test.dart test/import_book_controller_test.dart
cd android && ./gradlew :app:lintDebug :app:testDebugUnitTest
```

预期：PASS，并且不会再出现宽泛存储权限的 manifest 警告。

- [ ] **步骤 8：提交 Android 目录支持**

```bash
git add android/app/src/main/AndroidManifest.xml android/app/src/main/kotlin/com/niki/xxread/MainActivity.kt android/app/src/main/kotlin/com/niki/xxread/SafDirectoryBridge.kt lib/services/storage/android_book_folder_registry.dart lib/services/books/book_import_source_service.dart test/book_import_source_service_test.dart
git commit -m "Give Android folders durable access without broad storage permission" \
  -m "Use SAF tree grants as persistent discovery sources, enumerate documents through ContentResolver, and materialize selected books into the existing local import pipeline." \
  -m "Constraint: content URIs must never be treated as filesystem paths" \
  -m "Rejected: MANAGE_EXTERNAL_STORAGE | incompatible with least privilege and Play policy" \
  -m "Confidence: high" \
  -m "Scope-risk: moderate" \
  -m "Tested: MethodChannel mapping, recursive filtering, Flutter tests, Android lint and unit tasks"
```

---

### 任务 6：启用 iOS 本地 Files 和应用自有 iCloud Documents 来源

**文件：**
- 创建：`ios/Runner/Runner.entitlements`
- 创建：`ios/Runner/StorageBridge.swift`
- 修改：`ios/Runner/Info.plist`
- 修改：`ios/Runner/AppDelegate.swift`
- 修改：`ios/Runner.xcodeproj/project.pbxproj`
- 修改：`ios/RunnerTests/RunnerTests.swift`
- 修改：`lib/services/books/book_import_source_service.dart`
- 测试：`test/book_import_source_service_test.dart`

**接口：**
- 产出原生方法：`getICloudStatus`、`listICloudDocuments`、`materializeICloudDocument`。
- 产出 Dart 方法：`scanIosSharedDocuments()` 和 `scanICloudDocuments()`。

- [ ] **步骤 1：添加 iOS 来源映射测试**

测试这些语义：

- `Documents/books/file.epub` 变成 `managedInPlace`、`iosSharedDocuments`，并保留真实路径。
- iCloud `books/file.epub` 变成 `externalCopy`、`iosICloud`，在物化前 `localPath=null`。
- `getICloudStatus.available == false` 时显示不可用来源卡片，而不是抛出异常。

- [ ] **步骤 2：添加 entitlements 文件**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>com.apple.developer.icloud-container-identifiers</key>
  <array><string>iCloud.com.niki.xxread</string></array>
  <key>com.apple.developer.icloud-services</key>
  <array><string>CloudDocuments</string></array>
  <key>com.apple.developer.ubiquity-container-identifiers</key>
  <array><string>iCloud.com.niki.xxread</string></array>
  <key>com.apple.developer.ubiquity-kvstore-identifier</key>
  <string>$(TeamIdentifierPrefix)com.niki.xxread</string>
</dict>
</plist>
```

- [ ] **步骤 3：在 Xcode 元数据中注册该能力**

更新所有 Runner 构建配置：

```text
CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements;
```

添加 Runner 目标的 capability 元数据：

```text
SystemCapabilities = {
  com.apple.iCloud = {
    enabled = 1;
  };
};
```

将 `Runner.entitlements` 和 `StorageBridge.swift` 加入 Runner group 和 target sources，同时不要移除现有的 AppIcon 或 ReaderUIBridge 项目改动。

- [ ] **步骤 4：让 iCloud 文档作用域公开**

在保留现有 Files key 的同时，向 `Info.plist` 添加：

```xml
<key>NSUbiquitousContainers</key>
<dict>
  <key>iCloud.com.niki.xxread</key>
  <dict>
    <key>NSUbiquitousContainerIsDocumentScopePublic</key>
    <true/>
    <key>NSUbiquitousContainerName</key>
    <string>Open Reading</string>
    <key>NSUbiquitousContainerSupportedFolderLevels</key>
    <string>Any</string>
  </dict>
</dict>
```

- [ ] **步骤 5：实现 Swift 存储桥接**

使用 channel `com.niki.xxread/storage`。通过以下方式解析容器：

```swift
FileManager.default.url(
  forUbiquityContainerIdentifier: "iCloud.com.niki.xxread"
)
```

必要时创建 `Documents/books`。递归列出受支持文件，并返回 `relativePath`、`name`、`size`、`modifiedTime` 和下载状态。

物化流程：

1. 解析并验证 `Documents/books` 下的相对路径。
2. 对占位文件调用 `startDownloadingUbiquitousItem(at:)`。
3. 轮询资源值，直到下载完成或达到 30 秒超时。
4. 使用 `NSFileCoordinator` 把来源复制到指定暂存目标。
5. 失败时删除未完成的目标文件。

绝不接受包含 `..` 的相对路径，也不接受解析到 books 目录之外的路径。

- [ ] **步骤 6：注册 Swift 桥接**

在 `AppDelegate.register(with:)` 中，先执行 `GeneratedPluginRegistrant.register(with:)`，再注册 `StorageBridge`，并保留现有的 `reader_ui` channel。

- [ ] **步骤 7：实现本地与 iCloud 扫描**

`scanIosSharedDocuments()` 会枚举 `getApplicationDocumentsDirectory()/books`，排除已经注册的 `sourceLocator` 值和 `BookDao.getBookByFilePath()` 返回的精确路径，并生成原地管理来源。这可以防止 v17 之前已有的本地导入以重复的暂存条目出现。

`scanICloudDocuments()` 使用桥接器，生成外部复制来源，并且只在对应队列项开始时才物化。这样可以避免用户按下 Import 之前就把所有已暂存云文件都下载下来。

- [ ] **步骤 8：添加原生路径校验测试**

用针对相对路径拒绝和 `Documents/books` 包含关系的测试替换占位 XCTest。单元测试不应要求真实的 iCloud 账号。

- [ ] **步骤 9：验证 plist、测试和签名构建设置**

运行：

```bash
plutil -lint ios/Runner/Info.plist ios/Runner/Runner.entitlements
flutter test test/book_import_source_service_test.dart
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -workspace ios/Runner.xcworkspace -scheme Runner -configuration Debug -destination 'generic/platform=iOS' -allowProvisioningUpdates build
```

预期：plist 校验 PASS；Flutter 测试 PASS；签名构建包含 CloudDocuments 和 `iCloud.com.niki.xxread`。如果 provisioning 失败，则报告 Apple 账号/容器阻塞，不要更改 bundle ID、team 或容器标识。

- [ ] **步骤 10：提交 iOS 存储来源**

```bash
git add ios/Runner/Runner.entitlements ios/Runner/StorageBridge.swift ios/Runner/Info.plist ios/Runner/AppDelegate.swift ios/Runner.xcodeproj/project.pbxproj ios/RunnerTests/RunnerTests.swift lib/services/books/book_import_source_service.dart test/book_import_source_service_test.dart
git commit -m "Expose Open Reading book sources through Files and iCloud" \
  -m "Keep the local Files folder as the managed library and add an app-owned iCloud Documents source that downloads and materializes books only when their queue item runs." \
  -m "Constraint: iCloud container identity is iCloud.com.niki.xxread" \
  -m "Confidence: medium" \
  -m "Scope-risk: moderate" \
  -m "Directive: Do not rename the iCloud container without a data migration" \
  -m "Tested: plist lint, source mapping tests, XCTest path validation, and signed generic iOS build" \
  -m "Not-tested: Real-device iCloud Drive visibility until device validation"
```

---

### 任务 7：把平台来源接到页面，并统一导航行为

**文件：**
- 修改：`lib/pages/import_book_page.dart`
- 修改：`lib/pages/library_page.dart`
- 修改：`lib/pages/home_shell_layout_part.dart`
- 修改：`lib/services/books/book_services.dart`
- 测试：`test/import_book_page_test.dart`

**接口：**
- 消费：Android 文件夹注册表、iOS 来源扫描和队列控制器。
- 产出：平台特定的来源操作和一致的路由完成行为。

- [ ] **步骤 1：为平台操作扩展 widget 测试**

断言：

- Android 显示“选择文件”“添加书籍目录”、已注册文件夹卡片、刷新和移除授权。
- 只有在 iCloud 可用时，iOS 才显示“文件与 iCloud Drive”“扫描 Open Reading 文件夹”和“从 iCloud 同步”。
- 点击来源操作只会暂存书籍，绝不会自动开始导入。
- 只有当至少有一项被导入或修复时，点击“完成”返回的路由结果才是 `true`。

- [ ] **步骤 2：连接页面初始化和来源操作**

页面初始化时：

1. 在 Android 上加载已持久化授权的文件夹。
2. 在 iOS 上解析 iCloud 可用状态。
3. 用户点击对应来源卡片前，不要自动扫描或下载。

在测试中使用注入的平台能力，而不要在 widget 内直接基于 `Platform` 分支。

- [ ] **步骤 3：在导入期间防止误关闭**

使用 `PopScope(canPop: !controller.isRunning)`。首个版本不提供伪取消按钮，因为底层导入服务不可取消。应用后台化可能会挂起当前导入；在操作系统允许的情况下，返回页面会从当前 Future 继续。

- [ ] **步骤 4：统一路由入口**

在 `LibraryPage` 中创建一个辅助方法，用来 await `ImportBookPage`，并在结果为 `true` 时刷新。让 header action、FAB 和空状态都调用它。更新 shell 中的 `_navigateToImport()`，使其 await 该路由，并依赖 `LibraryEventBus` 做跨页面刷新。

- [ ] **步骤 5：运行页面和导航测试**

运行：

```bash
flutter test test/import_book_page_test.dart test/widget_test.dart
```

预期：PASS，且没有重复的 hero tag、路由异常或布局溢出。

- [ ] **步骤 6：提交平台 UI 集成**

```bash
git add lib/pages/import_book_page.dart lib/pages/library_page.dart lib/pages/home_shell_layout_part.dart lib/services/books/book_services.dart test/import_book_page_test.dart test/widget_test.dart
git commit -m "Unify every add-book entry around the staged import queue" \
  -m "Connect Android folders and iOS Files/iCloud sources to one review-first page, prevent accidental dismissal during active work, and normalize route results across library entry points." \
  -m "Constraint: Source selection never auto-starts import" \
  -m "Confidence: high" \
  -m "Scope-risk: narrow" \
  -m "Tested: Platform source widget tests, route-result tests, and application widget smoke test"
```

---

### 任务 8：运行端到端验证并记录平台行为

**文件：**
- 修改：`CODEBASE_DOCUMENTATION.md`
- 修改：`Project.md`
- 修改：`docs/superpowers/specs/2026-07-17-ios-icloud-documents-design.md`

**接口：**
- 验证完整功能；不产生新的运行时接口。

- [ ] **步骤 1：运行格式化和生成代码检查**

```bash
dart format lib test
flutter gen-l10n
git diff --check
```

预期：没有格式或空白错误。

- [ ] **步骤 2：运行定向测试套件**

```bash
flutter test test/book_import_models_test.dart test/book_import_schema_migration_test.dart test/book_import_service_test.dart test/book_import_source_service_test.dart test/import_book_controller_test.dart test/import_book_page_test.dart
```

预期：PASS。

- [ ] **步骤 3：运行完整静态分析和回归测试**

```bash
flutter analyze
flutter test
```

预期：分析器零错误，所有测试 PASS。

- [ ] **步骤 4：验证 Android**

```bash
cd android
./gradlew :app:lintDebug :app:testDebugUnitTest :app:assembleDebug
```

手动证据：

1. 授权一个包含子目录的书籍目录。
2. 暂存多个受支持文件，并在导入前移除其中一个。
3. 顺序导入，验证成功、重复跳过和可重试失败三种结果。
4. 强制停止并重新启动应用，验证目录授权仍然保留。
5. 在系统设置中撤销授权，验证文件夹显示“权限已失效”且应用不会崩溃。
6. 删除本地书籍后，确认来源文件保持不变。

- [ ] **步骤 5：验证 iOS**

```bash
plutil -lint ios/Runner/Info.plist ios/Runner/Runner.entitlements
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -workspace ios/Runner.xcworkspace -scheme Runner -configuration Debug -destination 'generic/platform=iOS' -allowProvisioningUpdates build
```

真机证据：

1. 把书籍放入 `On My iPhone/Open Reading/books`，扫描并原地登记，不能生成重复副本。
2. 把书籍放入 `iCloud Drive/Open Reading/books`，暂存时不能立即下载全部文件。
3. 开始导入，验证每个 iCloud 条目只在成为当前任务时才下载并物化。
4. 关闭 iCloud Drive 或退出账号，验证来源显示不可用，而已经导入的本地书籍仍可打开。
5. 在登录同一 Apple ID 的另一台设备上安装应用，验证 iCloud 来源文件会出现，并可导入该设备的本地书库。

- [ ] **步骤 6：更新文档**

记录最终流程：

```text
文件/文件夹来源 -> 暂存队列 -> 一次一个物化 ->
哈希/重复检查 -> 本地管理副本或原地管理注册 ->
元数据/封面/数据库 -> 成功/跳过/失败汇总 -> 库事件
```

明确说明 Android/iCloud 源文件不会被删除、队列执行不会被持久化，以及阅读进度不会通过 iCloud 同步。

- [ ] **步骤 7：提交验证文档**

```bash
git add CODEBASE_DOCUMENTATION.md Project.md docs/superpowers/specs/2026-07-17-ios-icloud-documents-design.md
git commit -m "Make the cross-platform import contract discoverable" \
  -m "Document source ownership, staged queue behavior, Android SAF persistence, iCloud file-only synchronization, and the verification boundary for future maintainers." \
  -m "Constraint: Documentation must distinguish source files from local imported copies" \
  -m "Confidence: high" \
  -m "Scope-risk: narrow" \
  -m "Tested: Full Flutter suite, Android debug build, signed iOS build, and platform manual checks"
```

---

## 延后工作

- 进程结束后的队列恢复。
- 不打开导入页面时的后台自动导入。
- 直接读取 Android `content://` URI。
- 不经本地管理副本直接读取 iCloud 占位文件。
- 用户删除本地已导入副本后，为已忽略来源保留持久化墓碑记录。
- 通过 iCloud/CloudKit 同步阅读进度、笔记、书签或 SQLite。
- 桌面端拖拽导入和 macOS 沙盒权限声明工作。

## 最终验收清单

- [ ] 多文件选择会在导入前暂存所有受支持文件。
- [ ] 用户可以在开始前从队列中移除文件。
- [ ] 任一时刻只导入一个条目。
- [ ] 每个条目最终都会变成已导入、重复已跳过或失败。
- [ ] 失败项可以单独或一起重试，且不会重复创建成功的书籍。
- [ ] Android 目录权限在重启后仍然有效，并且不需要宽泛存储权限。
- [ ] Android SAF 文档会被物化；不会把 `content://` URI 传给 `dart:io File`。
- [ ] `On My iPhone/Open Reading/books` 会原地注册文件。
- [ ] iCloud 来源文件通过 `iCloud.com.niki.xxread` 同步，并按需导入到本地库。
- [ ] Android 和 iCloud 的来源文件保持不变。
- [ ] UI 在移动端、平板和桌面宽度测试尺寸下都不会溢出。
- [ ] 状态含义通过文本和图标传达，而不是只靠颜色。
- [ ] 英文、简体中文、繁体中文和日文的本地化都已完成。
- [ ] 定向测试、完整 Flutter 测试、analyzer、Android 构建和签名 iOS 构建都通过。
