import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:xxread/models/book.dart';
import 'package:xxread/services/books/book_export_models.dart';
import 'package:xxread/services/books/book_export_service.dart';

void main() {
  late Directory sandbox;

  setUp(() async {
    sandbox = await Directory.systemTemp.createTemp('book-export-test-');
  });

  tearDown(() async {
    if (await sandbox.exists()) await sandbox.delete(recursive: true);
  });

  test('passes a safe file name and MIME type to the backend', () async {
    final source = File('${sandbox.path}/Example.epub');
    await source.writeAsString('epub fixture');
    final backend = _RecordingBackend(
      const BookExportBackendResult.success(
        displayName: 'Example.epub',
        location: 'Download/开元阅读/Example.epub',
      ),
    );

    final result = await BookExportService(backend: backend).export(
      Book(title: 'Example', filePath: source.path, format: 'EPUB'),
    );

    expect(result.status, BookExportStatus.success);
    expect(backend.request?.sourcePath, source.path);
    expect(backend.request?.suggestedName, 'Example.epub');
    expect(backend.request?.mimeType, 'application/epub+zip');
    expect(await source.readAsString(), 'epub fixture');
  });

  test('downloaded source book exports its generated TXT file', () async {
    final source = File('${sandbox.path}/downloaded.txt');
    await source.writeAsString('content');
    final backend = _RecordingBackend(
      const BookExportBackendResult.success(displayName: 'downloaded.txt'),
    );

    final result = await BookExportService(backend: backend).export(
      Book(
        title: 'Downloaded',
        filePath: source.path,
        format: 'TXT',
        storageType: 'local',
        sourceId: 'source-id',
      ),
    );

    expect(result.status, BookExportStatus.success);
    expect(backend.request?.suggestedName, 'downloaded.txt');
    expect(backend.request?.mimeType, 'text/plain');
  });

  test('restores the format extension for legacy extensionless paths',
      () async {
    final source = File('${sandbox.path}/legacy-book');
    await source.writeAsString('content');
    final backend = _RecordingBackend(
      const BookExportBackendResult.success(displayName: 'legacy-book.txt'),
    );

    await BookExportService(backend: backend).export(
      Book(title: 'Legacy', filePath: source.path, format: 'TXT'),
    );

    expect(backend.request?.suggestedName, 'legacy-book.txt');
    expect(backend.request?.mimeType, 'text/plain');
  });

  test('online and missing books never call the backend', () async {
    final backend = _RecordingBackend(
      const BookExportBackendResult.success(displayName: 'unused.txt'),
    );
    final service = BookExportService(backend: backend);

    final online = await service.export(
      Book(
        title: 'Online',
        filePath: '',
        format: 'TXT',
        storageType: 'online',
      ),
    );
    expect(online.status, BookExportStatus.notDownloaded);
    expect(backend.request, isNull);

    final missing = await service.export(
      Book(
        title: 'Missing',
        filePath: '${sandbox.path}/missing.txt',
        format: 'TXT',
      ),
    );
    expect(missing.status, BookExportStatus.sourceMissing);
    expect(backend.request, isNull);
  });

  test('maps cancellation and backend exceptions to stable results', () async {
    final source = File('${sandbox.path}/book.txt');
    await source.writeAsString('content');
    final cancelled = await BookExportService(
      backend: _RecordingBackend(const BookExportBackendResult.cancelled()),
    ).export(Book(title: 'Book', filePath: source.path, format: 'TXT'));
    expect(cancelled.status, BookExportStatus.cancelled);

    final failed = await BookExportService(
      backend: _ThrowingBackend(),
    ).export(Book(title: 'Book', filePath: source.path, format: 'TXT'));
    expect(failed.status, BookExportStatus.failure);
    expect(failed.error, isA<StateError>());
  });
}

class _RecordingBackend implements BookExportBackend {
  _RecordingBackend(this.result);

  final BookExportBackendResult result;
  BookExportRequest? request;

  @override
  Future<BookExportBackendResult> export(BookExportRequest request) async {
    this.request = request;
    return result;
  }
}

class _ThrowingBackend implements BookExportBackend {
  @override
  Future<BookExportBackendResult> export(BookExportRequest request) {
    throw StateError('backend failed');
  }
}
