// 文件说明：定义跨平台书籍导入的来源、进度、结果和存储边界。
// 技术要点：类型化状态、来源所有权、可测试的导入器与数据存储接口。

import 'package:xxread/models/book.dart';

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

  @override
  String toString() => 'BookImportFailure($code): $message';
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
