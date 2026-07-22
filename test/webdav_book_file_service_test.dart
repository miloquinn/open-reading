import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xxread/models/book.dart';
import 'package:xxread/services/books/book_import_models.dart';
import 'package:xxread/services/sync/secure_sync_config.dart';
import 'package:xxread/services/sync/sync_models.dart';
import 'package:xxread/services/sync/webdav_book_file_service.dart';
import 'package:xxread/services/sync/webdav_client.dart';

void main() {
  late Directory temporaryDirectory;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'open-reading-webdav-book-test-',
    );
  });

  tearDown(() async {
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
    expect(
      temporaryDirectory.listSync().whereType<File>(),
      isEmpty,
    );
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
  _DownloadClient(this.bytes)
      : super(
          dio: Dio(),
          credentials: _credentials,
        );

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
