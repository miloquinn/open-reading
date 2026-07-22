import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../models/book.dart';
import '../books/book_import_models.dart';
import '../books/book_import_service.dart';
import '../core/database_service.dart';
import 'adapters/metadata_sync_adapters.dart';
import 'secure_sync_config.dart';
import 'sync_engine.dart';
import 'sync_models.dart';
import 'webdav_client.dart';

class WebDavBookFileService {
  WebDavBookFileService({
    SecureSyncConfigStore? configStore,
    DatabaseService? databaseService,
    WebDavClientFactory? clientFactory,
    BookFileImporter? importer,
    Future<Directory> Function()? temporaryDirectory,
  })  : _configStore = configStore ?? SecureSyncConfigStore(),
        _databaseService = databaseService ?? DatabaseService(),
        _clientFactory = clientFactory ?? WebDavClient.standard,
        _importer = importer ?? BookImportService(),
        _temporaryDirectory = temporaryDirectory ?? getTemporaryDirectory;

  static const int maxRecoverableFileBytes = 100 * 1024 * 1024;

  final SecureSyncConfigStore _configStore;
  final DatabaseService _databaseService;
  final WebDavClientFactory _clientFactory;
  final BookFileImporter _importer;
  final Future<Directory> Function() _temporaryDirectory;

  Future<RemoteBookDescriptor> upload(
    Book book, {
    void Function(BookFileTransferProgress progress)? onProgress,
  }) async {
    if (book.isOnline) {
      throw const WebDavSyncFailure(
        WebDavSyncErrorCode.invalidConfiguration,
        'Online-source chapter caches are not uploaded as book files.',
      );
    }
    final source = File(book.filePath);
    if (!await source.exists()) {
      throw const WebDavSyncFailure(
        WebDavSyncErrorCode.notFound,
        'The local book file no longer exists.',
      );
    }
    final size = await source.length();
    if (size > maxRecoverableFileBytes) {
      throw const WebDavSyncFailure(
        WebDavSyncErrorCode.invalidConfiguration,
        'This release can safely restore book files up to 100 MiB.',
      );
    }
    final credentials = await _credentials();
    final client = _clientFactory(credentials);
    final digest = await sha256.bind(source.openRead()).first;
    final hash = '$digest';
    final prefix = hash.substring(0, 2);
    final remoteSegments = ['blobs', 'books', 'sha256', prefix, hash];
    final remoteUri = client.path(remoteSegments);
    await client.ensureProtocolPath(
      ['blobs', 'books', 'sha256', prefix],
    );
    if (!await client.exists(remoteUri)) {
      final temporary = client.path([
        'blobs',
        'books',
        'sha256',
        prefix,
        '.$hash.${DateTime.now().microsecondsSinceEpoch}.part',
      ]);
      try {
        await client.putFile(
          temporary,
          source,
          onProgress: (sent, total) => onProgress?.call(
            BookFileTransferProgress(
              transferredBytes: sent,
              totalBytes: total,
            ),
          ),
        );
        await client.move(temporary, remoteUri);
      } finally {
        try {
          await client.delete(temporary);
        } catch (_) {
          // Cleanup must not hide the original upload or MOVE result.
        }
      }
    } else {
      onProgress?.call(
        BookFileTransferProgress(
          transferredBytes: size,
          totalBytes: size,
        ),
      );
    }

    final uid = await bookUidForMap(book.toMap());
    final fileName = path.basename(book.filePath);
    final remotePath = remoteSegments.join('/');
    final db = await _databaseService.database;
    await db.insert(
      'sync_book_files',
      {
        'book_uid': uid,
        'local_book_id': book.id,
        'blob_sha256': hash,
        'file_name': fileName,
        'file_size': size,
        'remote_path': remotePath,
        'sync_enabled': 1,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return RemoteBookDescriptor(
      bookUid: uid,
      title: book.title,
      author: book.author,
      format: book.format,
      fileAvailable: true,
      sizeBytes: size,
      blobSha256: hash,
      remotePath: remotePath,
      fileName: fileName,
      sourceId: book.sourceId,
      sourceBookId: book.sourceBookId,
    );
  }

  Future<Book> download(
    RemoteBookDescriptor descriptor, {
    void Function(BookFileTransferProgress progress)? onProgress,
  }) async {
    final remotePath = descriptor.remotePath;
    final expectedHash = descriptor.blobSha256;
    final fileName = descriptor.fileName;
    if (!descriptor.fileAvailable ||
        remotePath == null ||
        expectedHash == null ||
        fileName == null) {
      throw const WebDavSyncFailure(
        WebDavSyncErrorCode.notFound,
        'This remote book does not include a downloadable file.',
      );
    }
    final size = descriptor.sizeBytes;
    if (size != null && size > maxRecoverableFileBytes) {
      throw const WebDavSyncFailure(
        WebDavSyncErrorCode.invalidConfiguration,
        'This release can safely restore book files up to 100 MiB.',
      );
    }
    final credentials = await _credentials();
    final client = _clientFactory(credentials);
    final temporaryRoot = await _temporaryDirectory();
    final safeFileName = path.basename(fileName);
    final partial = File(
      path.join(
        temporaryRoot.path,
        'open-reading-webdav-${DateTime.now().microsecondsSinceEpoch}-$safeFileName.part',
      ),
    );
    try {
      await client.downloadFile(
        client.path(
          remotePath
              .split('/')
              .where((segment) => segment.isNotEmpty)
              .toList(growable: false),
        ),
        partial,
        onProgress: (received, total) => onProgress?.call(
          BookFileTransferProgress(
            transferredBytes: received,
            totalBytes: total > 0 ? total : size ?? 0,
          ),
        ),
      );
      final actualSize = await partial.length();
      if (size != null && actualSize != size) {
        throw const WebDavSyncFailure(
          WebDavSyncErrorCode.corruptRemoteData,
          'The downloaded book size does not match its metadata.',
        );
      }
      final actualHash = '${await sha256.bind(partial.openRead()).first}';
      if (actualHash != expectedHash) {
        throw const WebDavSyncFailure(
          WebDavSyncErrorCode.corruptRemoteData,
          'The downloaded book checksum does not match its metadata.',
        );
      }
      final extension = path.extension(safeFileName).replaceFirst('.', '');
      final result = await _importer.importFile(
        BookImportSource(
          id: 'webdav:${descriptor.bookUid}',
          kind: BookImportSourceKind.filePicker,
          ownership: BookImportOwnership.externalCopy,
          displayName: safeFileName,
          extension: extension,
          locator: remotePath,
          localPath: partial.path,
          sizeBytes: actualSize,
        ),
      );
      final db = await _databaseService.database;
      var restoredBook = result.book;
      if (descriptor.sourceId != null && descriptor.sourceBookId != null) {
        restoredBook = result.book.copyWith(
          sourceId: descriptor.sourceId,
          sourceBookId: descriptor.sourceBookId,
        );
        await db.update(
          'books',
          {
            'source_id': descriptor.sourceId,
            'source_book_id': descriptor.sourceBookId,
          },
          where: 'id = ?',
          whereArgs: [restoredBook.id],
        );
      }
      await db.insert(
        'sync_book_files',
        {
          'book_uid': descriptor.bookUid,
          'local_book_id': restoredBook.id,
          'blob_sha256': expectedHash,
          'file_name': safeFileName,
          'file_size': actualSize,
          'remote_path': remotePath,
          'sync_enabled': 1,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      return restoredBook;
    } finally {
      if (await partial.exists()) await partial.delete();
    }
  }

  Future<StoredSyncCredentials> _credentials() async {
    final credentials = await _configStore.readCredentials();
    if (credentials == null) {
      throw const WebDavSyncFailure(
        WebDavSyncErrorCode.authentication,
        'WebDAV is not configured or its secure password is unavailable.',
      );
    }
    return credentials;
  }
}
