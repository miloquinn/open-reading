import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xxread/models/book.dart';
import 'package:xxread/services/books/book_import_models.dart';
import 'package:xxread/services/books/book_import_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory sandbox;
  late Directory documentsDirectory;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    sandbox = await Directory.systemTemp.createTemp('book-import-test-');
    documentsDirectory = Directory('${sandbox.path}/documents');
    await documentsDirectory.create(recursive: true);
  });

  tearDown(() async {
    if (await sandbox.exists()) {
      await sandbox.delete(recursive: true);
    }
  });

  test('重复书籍返回已跳过结果而不是抛出异常', () async {
    final sourceFile = await _fixtureFile(sandbox, 'same.txt', 'same content');
    final existing = Book(
      id: 7,
      title: '已存在',
      filePath: sourceFile.path,
      format: 'TXT',
      contentHash: md5.convert('same content'.codeUnits).toString(),
    );
    final store = _MemoryBookImportStore(initialBooks: <Book>[existing]);
    final importer = _testImporter(store, documentsDirectory);

    final result = await importer.importFile(_externalSource(sourceFile));

    expect(result.outcome, BookImportOutcome.duplicateSkipped);
    expect(result.book.id, 7);
  });

  test('应用管理的来源文件不会复制到自身或生成副本', () async {
    final managed = await _fixtureFile(sandbox, 'managed.txt', 'managed');
    final store = _MemoryBookImportStore();
    final importer = _testImporter(store, documentsDirectory);

    final result = await importer.importFile(_managedSource(managed));

    expect(result.outcome, BookImportOutcome.imported);
    expect(result.book.filePath, managed.path);
    expect(result.book.coverImagePath, isNotNull);
    expect(await File(result.book.coverImagePath!).exists(), isTrue);
    expect(await managed.exists(), isTrue);
    expect(
      await _filesUnder(Directory('${documentsDirectory.path}/books')),
      isEmpty,
    );
  });

  test('外部来源导入失败时只清理本次创建的文件', () async {
    final sourceFile = await _fixtureFile(sandbox, 'broken.txt', 'broken');
    final store = _MemoryBookImportStore(failBeforeInsert: true);
    final importer = _testImporter(store, documentsDirectory);

    await expectLater(
      importer.importFile(_externalSource(sourceFile)),
      throwsA(
        isA<BookImportFailure>().having(
          (failure) => failure.code,
          'code',
          'import_failed',
        ),
      ),
    );

    expect(await sourceFile.exists(), isTrue);
    expect(await _filesUnder(documentsDirectory), isEmpty);
  });
}

BookImportService _testImporter(
  BookImportStore store,
  Directory documentsDirectory,
) {
  return BookImportService(
    store: store,
    documentsDirectory: () async => documentsDirectory,
    metadataExtractor: (path, name, extension, onProgress) async {
      onProgress?.call(1, 'done');
      return EnhancedBookMetadata(
        title: name.replaceAll(RegExp(r'\.[^.]+$'), ''),
        author: '测试作者',
        estimatedPages: 1,
      );
    },
    scheduleAnalysis: (_) async {},
  );
}

Future<File> _fixtureFile(
  Directory directory,
  String name,
  String content,
) async {
  final file = File('${directory.path}/$name');
  await file.writeAsString(content);
  return file;
}

BookImportSource _externalSource(File file) => BookImportSource(
      id: file.path,
      kind: BookImportSourceKind.filePicker,
      ownership: BookImportOwnership.externalCopy,
      displayName: file.uri.pathSegments.last,
      extension: 'txt',
      locator: file.path,
      localPath: file.path,
    );

BookImportSource _managedSource(File file) => BookImportSource(
      id: file.path,
      kind: BookImportSourceKind.iosSharedDocuments,
      ownership: BookImportOwnership.managedInPlace,
      displayName: file.uri.pathSegments.last,
      extension: 'txt',
      locator: file.path,
      localPath: file.path,
    );

Future<List<File>> _filesUnder(Directory directory) async {
  if (!await directory.exists()) return const [];
  return directory
      .list(recursive: true)
      .where((entity) => entity is File)
      .cast<File>()
      .toList();
}

class _MemoryBookImportStore implements BookImportStore {
  _MemoryBookImportStore({
    Iterable<Book> initialBooks = const [],
    this.failBeforeInsert = false,
  }) : _books = initialBooks.toList();

  final List<Book> _books;
  final bool failBeforeInsert;
  var _nextId = 100;

  @override
  Future<Book?> getBookByHash(String contentHash) async {
    for (final book in _books) {
      if (book.contentHash == contentHash) return book;
    }
    return null;
  }

  @override
  Future<Book?> getBookByFilePath(String filePath) async {
    for (final book in _books) {
      if (book.filePath == filePath) return book;
    }
    return null;
  }

  @override
  Future<Book?> getBookBySourceLocator({
    required String sourceKind,
    required String sourceLocator,
  }) async {
    for (final book in _books) {
      if (book.sourceKind == sourceKind &&
          book.sourceLocator == sourceLocator) {
        return book;
      }
    }
    return null;
  }

  @override
  Future<BookInsertDecision> insertIfAbsentByHash(Book book) async {
    if (failBeforeInsert) {
      throw StateError('测试插入失败');
    }
    final duplicate = await getBookByHash(book.contentHash!);
    if (duplicate != null) {
      return BookInsertDecision.existing(duplicate);
    }
    final inserted = book.copyWith(id: _nextId++);
    _books.add(inserted);
    return BookInsertDecision.inserted(inserted);
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
    final index = _books.indexWhere((candidate) => candidate.id == book.id);
    _books[index] = updated;
    return updated;
  }
}
