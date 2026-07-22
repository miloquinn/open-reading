import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:xxread/services/books/book_export_models.dart';
import 'package:xxread/services/storage/platform_storage_bridge.dart';

typedef BookSaveFilePicker = Future<String?> Function(String suggestedName);

BookExportBackend createDefaultBookExportBackend() => IoBookExportBackend();

class IoBookExportBackend implements BookExportBackend {
  IoBookExportBackend({
    PlatformStorageBridge? platformBridge,
    BookSaveFilePicker? saveFilePicker,
    TargetPlatform? platform,
  })  : _platformBridge = platformBridge ?? PlatformStorageBridge(),
        _saveFilePicker = saveFilePicker ?? _pickSavePath,
        _platform = platform ?? defaultTargetPlatform;

  final PlatformStorageBridge _platformBridge;
  final BookSaveFilePicker _saveFilePicker;
  final TargetPlatform _platform;

  static Future<String?> _pickSavePath(String suggestedName) {
    final extension =
        path.extension(suggestedName).replaceFirst('.', '').toLowerCase();
    return FilePicker.saveFile(
      fileName: suggestedName,
      type: extension.isEmpty ? FileType.any : FileType.custom,
      allowedExtensions: extension.isEmpty ? null : <String>[extension],
      lockParentWindow: true,
    );
  }

  @override
  Future<BookExportBackendResult> export(BookExportRequest request) async {
    if (_platform == TargetPlatform.android) {
      return _fromNative(
        await _platformBridge.exportBookToDownloads(
          sourcePath: request.sourcePath,
          displayName: request.suggestedName,
          mimeType: request.mimeType,
        ),
      );
    }
    if (_platform == TargetPlatform.iOS) {
      return _fromNative(
        await _platformBridge.exportDocument(
          sourcePath: request.sourcePath,
          displayName: request.suggestedName,
          mimeType: request.mimeType,
        ),
      );
    }
    if (_platform != TargetPlatform.windows &&
        _platform != TargetPlatform.macOS &&
        _platform != TargetPlatform.linux) {
      return const BookExportBackendResult.unsupported();
    }

    final destinationPath = await _saveFilePicker(request.suggestedName);
    if (destinationPath == null || destinationPath.isEmpty) {
      return const BookExportBackendResult.cancelled();
    }
    final source = File(request.sourcePath);
    final destination = File(destinationPath);
    if (path.canonicalize(source.path) == path.canonicalize(destination.path)) {
      return BookExportBackendResult.success(
        displayName: path.basename(destination.path),
        location: destination.path,
      );
    }
    await _copyAtomically(source, destination);
    return BookExportBackendResult.success(
      displayName: path.basename(destination.path),
      location: destination.path,
    );
  }

  BookExportBackendResult _fromNative(Map<String, Object?> row) {
    return switch (row['status']?.toString()) {
      'success' => BookExportBackendResult.success(
          displayName: row['displayName']?.toString() ?? '',
          location: row['displayLocation']?.toString() ??
              row['destinationPath']?.toString() ??
              row['location']?.toString(),
          uri: row['uri']?.toString(),
        ),
      'cancelled' => const BookExportBackendResult.cancelled(),
      'unsupported' => const BookExportBackendResult.unsupported(),
      _ => BookExportBackendResult.failure(row['errorCode']),
    };
  }

  Future<void> _copyAtomically(File source, File destination) async {
    await destination.parent.create(recursive: true);
    final partial = File(
      '${destination.path}.open-reading-${DateTime.now().microsecondsSinceEpoch}.partial',
    );
    File? backup;
    try {
      await source.openRead().pipe(partial.openWrite());
      if (await destination.exists()) {
        backup = File('${partial.path}.backup');
        await destination.rename(backup.path);
      }
      await partial.rename(destination.path);
      if (backup != null && await backup.exists()) await backup.delete();
    } catch (_) {
      if (await partial.exists()) await partial.delete();
      if (backup != null && await backup.exists()) {
        if (await destination.exists()) await destination.delete();
        await backup.rename(destination.path);
      }
      rethrow;
    }
  }
}
