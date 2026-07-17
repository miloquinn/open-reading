// 文件说明：发现多文件来源并在导入前将平台文档物化为可读取的本地文件。
// 技术要点：FilePicker 多选、格式过滤、iOS Documents 扫描、平台桥接。

import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:xxread/services/books/book_format_support.dart';
import 'package:xxread/services/books/book_import_models.dart';
import 'package:xxread/services/storage/platform_storage_bridge.dart';

abstract interface class BookImportSourcePreparer {
  Future<BookImportSource> prepare(BookImportSource source);

  Future<void> release(BookImportSource source);
}

class BookImportSourceService implements BookImportSourcePreparer {
  BookImportSourceService({
    Future<FilePickerResult?> Function()? filePicker,
    PlatformStorageBridge? platformBridge,
    Future<Directory> Function()? documentsDirectory,
    Future<Directory> Function()? temporaryDirectory,
  })  : _filePicker = filePicker ?? _pickSupportedFiles,
        _platformBridge = platformBridge ?? PlatformStorageBridge(),
        _documentsDirectory =
            documentsDirectory ?? getApplicationDocumentsDirectory,
        _temporaryDirectory = temporaryDirectory ?? getTemporaryDirectory;

  /// 与 [BookFormatRegistry.pickerExtensions] 同步；格式变更只改注册表。
  static Set<String> get supportedExtensions =>
      BookFormatRegistry.pickerExtensions;

  final Future<FilePickerResult?> Function() _filePicker;
  final PlatformStorageBridge _platformBridge;
  final Future<Directory> Function() _documentsDirectory;
  final Future<Directory> Function() _temporaryDirectory;

  static Future<FilePickerResult?> _pickSupportedFiles() {
    return FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions:
          BookFormatRegistry.pickerExtensions.toList(growable: false),
      allowMultiple: true,
      withData: false,
    );
  }

  Future<List<BookImportSource>> pickFiles() async {
    final result = await _filePicker();
    if (result == null) return const [];

    final sources = <BookImportSource>[];
    for (final pickedFile in result.files) {
      final path = pickedFile.path;
      final fileExtension = _normalizedExtension(
        pickedFile.extension ?? extension(pickedFile.name),
      );
      if (path == null || !supportedExtensions.contains(fileExtension)) {
        continue;
      }
      final file = File(path);
      final stat = await file.stat();
      sources.add(
        BookImportSource(
          id: '${BookImportSourceKind.filePicker.storageValue}:$path',
          kind: BookImportSourceKind.filePicker,
          ownership: BookImportOwnership.externalCopy,
          displayName: pickedFile.name,
          extension: fileExtension,
          locator: path,
          localPath: path,
          sizeBytes: pickedFile.size,
          modifiedTime: stat.modified.millisecondsSinceEpoch,
        ),
      );
    }
    return _deduplicate(sources);
  }

  Future<List<BookImportSource>> scanIosSharedDocuments() async {
    final documents = await _documentsDirectory();
    final books = Directory(join(documents.path, 'books'));
    if (!await books.exists()) {
      await books.create(recursive: true);
      return const [];
    }

    final sources = <BookImportSource>[];
    await for (final entity in books.list(recursive: true)) {
      if (entity is! File) continue;
      final fileExtension = _normalizedExtension(extension(entity.path));
      if (!supportedExtensions.contains(fileExtension) ||
          entity.path.endsWith('.partial')) {
        continue;
      }
      final stat = await entity.stat();
      sources.add(
        BookImportSource(
          id: '${BookImportSourceKind.iosSharedDocuments.storageValue}:${entity.path}',
          kind: BookImportSourceKind.iosSharedDocuments,
          ownership: BookImportOwnership.managedInPlace,
          displayName: basename(entity.path),
          extension: fileExtension,
          locator: entity.path,
          localPath: entity.path,
          sizeBytes: stat.size,
          modifiedTime: stat.modified.millisecondsSinceEpoch,
        ),
      );
    }
    return _deduplicate(sources);
  }

  Future<List<BookImportSource>> scanAndroidTree(String treeUri) async {
    final rows = await _platformBridge.listAndroidDocuments(treeUri);
    return _sourcesFromRows(
      rows,
      kind: BookImportSourceKind.androidTree,
      ownership: BookImportOwnership.externalCopy,
    );
  }

  Future<List<BookImportSource>> scanICloudDocuments() async {
    final rows = await _platformBridge.listICloudDocuments();
    return _sourcesFromRows(
      rows,
      kind: BookImportSourceKind.iosICloud,
      ownership: BookImportOwnership.externalCopy,
    );
  }

  Future<bool> isICloudAvailable() async {
    final status = await _platformBridge.getICloudStatus();
    return status['available'] == true;
  }

  @override
  Future<BookImportSource> prepare(BookImportSource source) async {
    if (source.localPath != null) return source;

    final temporaryRoot = await _temporaryDirectory();
    final materializedDirectory = Directory(
      join(temporaryRoot.path, 'book_import_sources'),
    );
    await materializedDirectory.create(recursive: true);
    final destination = await _allocateTemporaryDestination(
      materializedDirectory,
      source.displayName,
    );

    final localPath = switch (source.kind) {
      BookImportSourceKind.androidTree =>
        await _platformBridge.materializeAndroidDocument(
          documentUri: source.locator,
          destinationPath: destination.path,
        ),
      BookImportSourceKind.iosICloud =>
        await _platformBridge.materializeICloudDocument(
          locator: source.locator,
          destinationPath: destination.path,
        ),
      BookImportSourceKind.filePicker ||
      BookImportSourceKind.iosSharedDocuments =>
        throw StateError('${source.kind.name} 来源缺少本地路径'),
    };
    return source.copyWithLocalPath(localPath);
  }

  @override
  Future<void> release(BookImportSource source) async {
    if (source.kind != BookImportSourceKind.androidTree &&
        source.kind != BookImportSourceKind.iosICloud) {
      return;
    }
    final localPath = source.localPath;
    if (localPath == null) return;
    final temporaryRoot = await _temporaryDirectory();
    final materializedRoot = join(
      temporaryRoot.path,
      'book_import_sources',
    );
    if (!isWithin(materializedRoot, localPath)) return;
    final file = File(localPath);
    if (await file.exists()) {
      await file.delete();
    }
  }

  List<BookImportSource> _sourcesFromRows(
    List<Map<String, Object?>> rows, {
    required BookImportSourceKind kind,
    required BookImportOwnership ownership,
  }) {
    final sources = <BookImportSource>[];
    for (final row in rows) {
      final locator =
          row['locator']?.toString() ?? row['documentUri']?.toString() ?? '';
      final displayName =
          row['displayName']?.toString() ?? row['name']?.toString() ?? '';
      final fileExtension = _normalizedExtension(
        row['extension']?.toString() ?? extension(displayName),
      );
      if (locator.isEmpty ||
          displayName.isEmpty ||
          !supportedExtensions.contains(fileExtension)) {
        continue;
      }
      sources.add(
        BookImportSource(
          id: '${kind.storageValue}:$locator',
          kind: kind,
          ownership: ownership,
          displayName: displayName,
          extension: fileExtension,
          locator: locator,
          localPath: row['localPath']?.toString(),
          sizeBytes: _asInt(row['sizeBytes'] ?? row['size']),
          modifiedTime: _asInt(row['modifiedTime']),
        ),
      );
    }
    return _deduplicate(sources);
  }

  Future<File> _allocateTemporaryDestination(
    Directory directory,
    String displayName,
  ) async {
    final safeName = basename(displayName);
    for (var counter = 0; counter < 1000; counter++) {
      final candidate = File(
        join(
          directory.path,
          counter == 0 ? safeName : '${counter}_$safeName',
        ),
      );
      if (!await candidate.exists()) return candidate;
    }
    throw StateError('无法分配临时导入路径');
  }

  String _normalizedExtension(String value) {
    return value.replaceFirst(RegExp(r'^\.'), '').toLowerCase();
  }

  int? _asInt(Object? value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '');
  }

  List<BookImportSource> _deduplicate(Iterable<BookImportSource> sources) {
    final byId = <String, BookImportSource>{};
    for (final source in sources) {
      byId.putIfAbsent(source.id, () => source);
    }
    final result = byId.values.toList();
    result.sort((a, b) {
      final byName = a.displayName.toLowerCase().compareTo(
            b.displayName.toLowerCase(),
          );
      return byName != 0 ? byName : a.locator.compareTo(b.locator);
    });
    return result;
  }
}
