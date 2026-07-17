import 'package:flutter_test/flutter_test.dart';
import 'package:xxread/models/book.dart';
import 'package:xxread/pages/import_book/import_book_controller.dart';
import 'package:xxread/services/books/book_import_models.dart';
import 'package:xxread/services/books/book_import_source_service.dart';

void main() {
  test('队列严格顺序导入并在单本失败后继续', () async {
    final importer = _RecordingImporter(<String, Object>{
      'a': _importedResult('a'),
      'b': const BookImportFailure(code: 'broken', message: 'broken'),
      'c': _importedResult('c'),
    });
    final controller = ImportBookController(
      importer: importer,
      sourcePreparer: const _PassthroughSourcePreparer(),
    );
    controller.addSources(<BookImportSource>[
      _source('a'),
      _source('b'),
      _source('c'),
    ]);

    await controller.start();

    expect(importer.maxConcurrent, 1);
    expect(importer.order, <String>['a', 'b', 'c']);
    expect(controller.succeededCount, 2);
    expect(controller.failedCount, 1);
  });

  test('重复项记为跳过且不会进入失败重试', () async {
    final importer = _RecordingImporter(<String, Object>{
      'a': _duplicateResult('a'),
    });
    final controller = ImportBookController(
      importer: importer,
      sourcePreparer: const _PassthroughSourcePreparer(),
    );
    controller.addSources(<BookImportSource>[_source('a')]);

    await controller.start();
    await controller.retryFailed();

    expect(controller.skippedCount, 1);
    expect(importer.order, <String>['a']);
  });

  test('暂存阶段可移除误选项，导入运行时不能移除', () async {
    final importer = _RecordingImporter(<String, Object>{
      'a': _importedResult('a'),
      'b': _importedResult('b'),
    });
    final controller = ImportBookController(
      importer: importer,
      sourcePreparer: const _PassthroughSourcePreparer(),
    );
    controller.addSources(<BookImportSource>[_source('a'), _source('b')]);

    controller.removeQueued('a');
    await controller.start();

    expect(importer.order, <String>['b']);
    expect(controller.totalCount, 1);
  });

  test('平台临时文件每次导入后释放，重试会重新准备', () async {
    const source = BookImportSource(
      id: 'icloud-a',
      kind: BookImportSourceKind.iosICloud,
      ownership: BookImportOwnership.externalCopy,
      displayName: 'a.txt',
      extension: 'txt',
      locator: 'a.txt',
    );
    final preparer = _MaterializingPreparer();
    final importer = _RetryImporter();
    final controller = ImportBookController(
      importer: importer,
      sourcePreparer: preparer,
    );
    controller.addSources(<BookImportSource>[source]);

    await controller.start();
    expect(controller.failedCount, 1);
    expect(controller.items.single.source.localPath, isNull);

    await controller.retryOne(source.id);

    expect(controller.succeededCount, 1);
    expect(preparer.prepareCalls, 2);
    expect(preparer.releaseCalls, 2);
    expect(preparer.receivedLocalPaths, <String?>[null, null]);
  });
}

BookImportSource _source(String id) => BookImportSource(
      id: id,
      kind: BookImportSourceKind.filePicker,
      ownership: BookImportOwnership.externalCopy,
      displayName: '$id.txt',
      extension: 'txt',
      locator: '/tmp/$id.txt',
      localPath: '/tmp/$id.txt',
    );

BookImportResult _importedResult(String id) => BookImportResult(
      source: _source(id),
      outcome: BookImportOutcome.imported,
      book: Book(
        id: id.hashCode,
        title: id,
        filePath: '/managed/$id.txt',
        format: 'TXT',
      ),
    );

BookImportResult _duplicateResult(String id) => BookImportResult(
      source: _source(id),
      outcome: BookImportOutcome.duplicateSkipped,
      book: Book(
        id: id.hashCode,
        title: id,
        filePath: '/managed/$id.txt',
        format: 'TXT',
      ),
    );

class _PassthroughSourcePreparer implements BookImportSourcePreparer {
  const _PassthroughSourcePreparer();

  @override
  Future<BookImportSource> prepare(BookImportSource source) async => source;

  @override
  Future<void> release(BookImportSource source) async {}
}

class _RecordingImporter implements BookFileImporter {
  _RecordingImporter(this.results);

  final Map<String, Object> results;
  final List<String> order = <String>[];
  var concurrent = 0;
  var maxConcurrent = 0;

  @override
  Future<BookImportResult> importFile(
    BookImportSource source, {
    BookImportProgress? onProgress,
  }) async {
    order.add(source.id);
    concurrent++;
    if (concurrent > maxConcurrent) maxConcurrent = concurrent;
    try {
      onProgress?.call(BookImportPhase.analyzing, 0.5, 'analyzing');
      await Future<void>.delayed(Duration.zero);
      final result = results[source.id]!;
      if (result is BookImportFailure) throw result;
      return result as BookImportResult;
    } finally {
      concurrent--;
    }
  }
}

class _MaterializingPreparer implements BookImportSourcePreparer {
  var prepareCalls = 0;
  var releaseCalls = 0;
  final List<String?> receivedLocalPaths = <String?>[];

  @override
  Future<BookImportSource> prepare(BookImportSource source) async {
    prepareCalls++;
    receivedLocalPaths.add(source.localPath);
    return source.copyWithLocalPath('/tmp/materialized-$prepareCalls.txt');
  }

  @override
  Future<void> release(BookImportSource source) async {
    releaseCalls++;
  }
}

class _RetryImporter implements BookFileImporter {
  var attempts = 0;

  @override
  Future<BookImportResult> importFile(
    BookImportSource source, {
    BookImportProgress? onProgress,
  }) async {
    attempts++;
    if (attempts == 1) {
      throw const BookImportFailure(code: 'first_failed', message: 'first');
    }
    return BookImportResult(
      source: source,
      outcome: BookImportOutcome.imported,
      book: Book(
        id: 1,
        title: 'a',
        filePath: '/managed/a.txt',
        format: 'TXT',
      ),
    );
  }
}
