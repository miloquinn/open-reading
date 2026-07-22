import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:xxread/data/migration/webdav_sync_schema_migration.dart';
import 'package:xxread/models/book.dart';
import 'package:xxread/services/books/book_import_models.dart';
import 'package:xxread/services/sync/secure_sync_config.dart';
import 'package:xxread/services/sync/sync_models.dart';
import 'package:xxread/services/sync/webdav_book_file_service.dart';
import 'package:xxread/services/sync/webdav_client.dart';

void main() {
  late Directory temporaryDirectory;
  late Database database;

  setUp(() async {
    sqfliteFfiInit();
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'open-reading-webdav-book-test-',
    );
    database = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await database.execute('''
      CREATE TABLE books(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        author TEXT NOT NULL,
        cover_image_path TEXT,
        source_id TEXT,
        source_book_id TEXT
      )
    ''');
    await WebDavSyncSchemaMigration.migrate(database);
  });

  tearDown(() async {
    await database.close();
    if (await temporaryDirectory.exists()) {
      await temporaryDirectory.delete(recursive: true);
    }
  });

  test('download rejects corrupted content before importing it', () async {
    final remoteBytes = [1, 2, 3, 4];
    final progress = <BookFileTransferProgress>[];
    final importer = _RejectingImporter();
    final service = WebDavBookFileService(
      configStore: _CredentialsStore(),
      clientFactory: (_) => _DownloadClient(remoteBytes),
      importer: importer,
      temporaryDirectory: () async => temporaryDirectory,
      database: () async => database,
    );

    await expectLater(
      service.download(
        const RemoteBookDescriptor(
          bookUid: 'book-1',
          title: 'Remote book',
          author: 'Author',
          format: 'epub',
          fileAvailable: true,
          sizeBytes: 4,
          blobSha256:
              '0000000000000000000000000000000000000000000000000000000000000000',
          remotePath: 'blobs/books/sha256/00/bad',
          fileName: 'remote.epub',
        ),
        onProgress: progress.add,
      ),
      throwsA(
        isA<WebDavSyncFailure>().having(
          (failure) => failure.code,
          'code',
          WebDavSyncErrorCode.corruptRemoteData,
        ),
      ),
    );

    expect(importer.called, isFalse);
    expect(progress.single.transferredBytes, remoteBytes.length);
    expect(progress.single.fraction, 1);
    expect(temporaryDirectory.listSync().whereType<File>(), isEmpty);
  });

  test('upload rejects files beyond the recoverable import limit', () async {
    final source = File('${temporaryDirectory.path}/large.pdf');
    await source.open(mode: FileMode.write).then((file) async {
      await file.truncate(WebDavBookFileService.maxRecoverableFileBytes + 1);
      await file.close();
    });
    final service = WebDavBookFileService();

    await expectLater(
      service.upload(
        Book(title: 'Large', filePath: source.path, format: 'pdf'),
      ),
      throwsA(
        isA<WebDavSyncFailure>().having(
          (failure) => failure.code,
          'code',
          WebDavSyncErrorCode.invalidConfiguration,
        ),
      ),
    );
  });

  test(
    'download restores remote title, author, and cover after import',
    () async {
      final bookBytes = [10, 20, 30, 40];
      final coverBytes = [137, 80, 78, 71, 1, 2, 3];
      final wrongCover = File('${temporaryDirectory.path}/wrong-cover.jpg');
      await wrongCover.writeAsBytes([0, 0, 0]);
      final importer = _DatabaseImporter(database, wrongCover.path);
      final client = _MemoryWebDavClient(
        bookBytes: bookBytes,
        coverBytes: coverBytes,
      );
      final service = WebDavBookFileService(
        configStore: _CredentialsStore(),
        clientFactory: (_) => client,
        importer: importer,
        temporaryDirectory: () async => temporaryDirectory,
        documentsDirectory: () async => temporaryDirectory,
        database: () async => database,
      );
      final bookHash = sha256.convert(bookBytes).toString();
      final coverHash = sha256.convert(coverBytes).toString();

      final restored = await service.download(
        RemoteBookDescriptor(
          bookUid: 'source:source-a:book-a',
          title: '远端正确书名',
          author: '远端正确作者',
          format: 'txt',
          fileAvailable: true,
          sizeBytes: bookBytes.length,
          blobSha256: bookHash,
          remotePath:
              'blobs/books/sha256/${bookHash.substring(0, 2)}/$bookHash',
          fileName: 'book-a.txt',
          sourceId: 'source-a',
          sourceBookId: 'book-a',
          coverAvailable: true,
          coverSizeBytes: coverBytes.length,
          coverBlobSha256: coverHash,
          coverRemotePath:
              'blobs/covers/sha256/${coverHash.substring(0, 2)}/$coverHash',
          coverFileName: 'source-cover.img',
        ),
      );

      expect(restored.title, '远端正确书名');
      expect(restored.author, '远端正确作者');
      expect(restored.sourceId, 'source-a');
      expect(restored.sourceBookId, 'book-a');
      expect(restored.coverImagePath, wrongCover.path);
      expect(await wrongCover.readAsBytes(), coverBytes);

      final bookRow = (await database.query(
        'books',
        where: 'id = ?',
        whereArgs: [restored.id],
      )).single;
      expect(bookRow['title'], '远端正确书名');
      expect(bookRow['author'], '远端正确作者');
      expect(bookRow['cover_image_path'], wrongCover.path);
      expect(bookRow['source_id'], 'source-a');
      expect(bookRow['source_book_id'], 'book-a');

      final fileRow = (await database.query('sync_book_files')).single;
      expect(fileRow['cover_blob_sha256'], coverHash);
      expect(fileRow['cover_file_size'], coverBytes.length);
      expect(fileRow['cover_remote_path'], contains('blobs/covers/sha256/'));
      expect(
        temporaryDirectory.listSync().whereType<File>().where(
          (file) => file.path.endsWith('.part'),
        ),
        isEmpty,
      );
    },
  );

  test(
    'download rejects a corrupted cover before importing and cleans parts',
    () async {
      final bookBytes = [1, 3, 5, 7];
      final coverBytes = [2, 4, 6, 8];
      final importer = _RejectingImporter();
      final service = WebDavBookFileService(
        configStore: _CredentialsStore(),
        clientFactory: (_) =>
            _MemoryWebDavClient(bookBytes: bookBytes, coverBytes: coverBytes),
        importer: importer,
        temporaryDirectory: () async => temporaryDirectory,
        database: () async => database,
      );
      final bookHash = sha256.convert(bookBytes).toString();

      await expectLater(
        service.download(
          RemoteBookDescriptor(
            bookUid: 'book-with-bad-cover',
            title: 'Remote book',
            author: 'Author',
            format: 'txt',
            fileAvailable: true,
            sizeBytes: bookBytes.length,
            blobSha256: bookHash,
            remotePath: 'blobs/books/sha256/00/book',
            fileName: 'book.txt',
            coverAvailable: true,
            coverSizeBytes: coverBytes.length,
            coverBlobSha256: List.filled(64, '0').join(),
            coverRemotePath: 'blobs/covers/sha256/00/cover',
            coverFileName: 'cover.img',
          ),
        ),
        throwsA(
          isA<WebDavSyncFailure>().having(
            (failure) => failure.code,
            'code',
            WebDavSyncErrorCode.corruptRemoteData,
          ),
        ),
      );

      expect(importer.called, isFalse);
      expect(
        temporaryDirectory.listSync().whereType<File>().where(
          (file) => file.path.endsWith('.part'),
        ),
        isEmpty,
      );
    },
  );

  test('upload stores a content-addressed cover reference', () async {
    final bookFile = File('${temporaryDirectory.path}/source-book.txt');
    final coverFile = File('${temporaryDirectory.path}/source-cover.img');
    await bookFile.writeAsBytes([11, 12, 13]);
    await coverFile.writeAsBytes([21, 22, 23, 24]);
    final client = _MemoryWebDavClient();
    final service = WebDavBookFileService(
      configStore: _CredentialsStore(),
      clientFactory: (_) => client,
      database: () async => database,
    );

    final descriptor = await service.upload(
      Book(
        id: 8,
        title: '书源书名',
        author: '书源作者',
        filePath: bookFile.path,
        format: 'txt',
        coverImagePath: coverFile.path,
        sourceId: 'source-a',
        sourceBookId: 'book-a',
      ),
    );

    final coverHash = sha256.convert(await coverFile.readAsBytes()).toString();
    expect(descriptor.title, '书源书名');
    expect(descriptor.author, '书源作者');
    expect(descriptor.coverAvailable, isTrue);
    expect(descriptor.coverBlobSha256, coverHash);
    expect(
      descriptor.coverRemotePath,
      'blobs/covers/sha256/${coverHash.substring(0, 2)}/$coverHash',
    );
    expect(
      client.movedDestinations.where(
        (uri) => uri.path.contains('/blobs/covers/sha256/'),
      ),
      hasLength(1),
    );

    final row = (await database.query('sync_book_files')).single;
    expect(row['cover_blob_sha256'], coverHash);
    expect(row['cover_file_name'], 'source-cover.img');
    expect(row['cover_file_size'], 4);
  });

  test('upload reuses a cover blob that already exists remotely', () async {
    final bookFile = File('${temporaryDirectory.path}/source-book.txt');
    final coverFile = File('${temporaryDirectory.path}/source-cover.img');
    await bookFile.writeAsBytes([31, 32, 33]);
    await coverFile.writeAsBytes([41, 42, 43]);
    final client = _MemoryWebDavClient(coverExists: true);
    final service = WebDavBookFileService(
      configStore: _CredentialsStore(),
      clientFactory: (_) => client,
      database: () async => database,
    );

    await service.upload(
      Book(
        title: 'Book',
        filePath: bookFile.path,
        format: 'txt',
        coverImagePath: coverFile.path,
      ),
    );

    expect(
      client.uploadedUris.where(
        (uri) => uri.path.contains('/blobs/covers/sha256/'),
      ),
      isEmpty,
    );
  });
}

const _credentials = StoredSyncCredentials(
  WebDavSyncConfiguration(
    serverUrl: 'https://dav.example.com',
    username: 'reader',
  ),
  'secret',
);

class _CredentialsStore extends SecureSyncConfigStore {
  @override
  Future<StoredSyncCredentials?> readCredentials() async => _credentials;
}

class _DownloadClient extends WebDavClient {
  _DownloadClient(this.bytes) : super(dio: Dio(), credentials: _credentials);

  final List<int> bytes;

  @override
  Future<void> downloadFile(
    Uri uri,
    File target, {
    void Function(int received, int total)? onProgress,
  }) async {
    await target.writeAsBytes(bytes);
    onProgress?.call(bytes.length, bytes.length);
  }
}

class _MemoryWebDavClient extends WebDavClient {
  _MemoryWebDavClient({
    this.bookBytes = const [],
    this.coverBytes = const [],
    this.coverExists = false,
  }) : super(dio: Dio(), credentials: _credentials);

  final List<int> bookBytes;
  final List<int> coverBytes;
  final bool coverExists;
  final List<Uri> uploadedUris = [];
  final List<Uri> movedDestinations = [];

  @override
  Future<void> ensureProtocolPath(List<String> relativeSegments) async {}

  @override
  Future<bool> exists(Uri uri) async =>
      coverExists && uri.path.contains('/blobs/covers/sha256/');

  @override
  Future<void> putFile(
    Uri uri,
    File file, {
    void Function(int sent, int total)? onProgress,
  }) async {
    uploadedUris.add(uri);
    final size = await file.length();
    onProgress?.call(size, size);
  }

  @override
  Future<void> move(
    Uri source,
    Uri destination, {
    bool overwrite = false,
  }) async {
    movedDestinations.add(destination);
  }

  @override
  Future<void> delete(Uri uri, {bool allowNotFound = true}) async {}

  @override
  Future<void> downloadFile(
    Uri uri,
    File target, {
    void Function(int received, int total)? onProgress,
  }) async {
    final bytes = uri.path.contains('/blobs/covers/') ? coverBytes : bookBytes;
    await target.writeAsBytes(bytes);
    onProgress?.call(bytes.length, bytes.length);
  }
}

class _DatabaseImporter implements BookFileImporter {
  _DatabaseImporter(this.database, this.wrongCoverPath);

  final Database database;
  final String wrongCoverPath;

  @override
  Future<BookImportResult> importFile(
    BookImportSource source, {
    BookImportProgress? onProgress,
  }) async {
    final id = await database.insert('books', {
      'title': '第一章',
      'author': '错误作者',
      'cover_image_path': wrongCoverPath,
    });
    return BookImportResult(
      source: source,
      outcome: BookImportOutcome.imported,
      book: Book(
        id: id,
        title: '第一章',
        author: '错误作者',
        filePath: source.localPath!,
        format: source.extension,
        coverImagePath: wrongCoverPath,
      ),
    );
  }
}

class _RejectingImporter implements BookFileImporter {
  bool called = false;

  @override
  Future<BookImportResult> importFile(
    BookImportSource source, {
    BookImportProgress? onProgress,
  }) async {
    called = true;
    throw StateError('Corrupted files must not reach the importer.');
  }
}
