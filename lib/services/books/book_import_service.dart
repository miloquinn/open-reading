// 文件说明：书籍导入总入口，统筹各格式元数据提取与入库。
// 技术要点：格式列表见 book_format_support.dart；File Picker、EPUBX、PDFX 等。
// 能力矩阵与后续目标：docs/book-format-support.md

import 'dart:io';
import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:epubx/epubx.dart';
import 'package:pdfx/pdfx.dart';
import 'package:html/parser.dart' as html_parser;
import 'dart:convert';
import 'package:crypto/crypto.dart';

import 'package:xxread/models/book.dart';
import 'package:xxread/services/books/book_dao.dart';
import 'package:xxread/services/books/enhanced_txt_import_service.dart';
import 'package:xxread/services/books/epub_native_parser.dart';
import 'package:xxread/services/books/text_preprocessor_helper.dart';
import 'package:xxread/services/books/cover_generator_service.dart';
import 'package:xxread/services/books/book_format_support.dart';
import 'package:xxread/services/books/book_import_limits.dart';
import 'package:xxread/services/books/book_import_isolate_service.dart';
import 'package:xxread/services/books/book_import_models.dart';
import 'package:xxread/services/books/comic_book_parser.dart';
import 'package:xxread/services/books/kindle_book_parser.dart';
import 'package:xxread/services/books/web_book_file_store.dart';
import 'package:xxread/services/library/library_event_bus_service.dart';
import 'package:xxread/services/ai/global_ai_reading_service.dart';

class EnhancedBookMetadata {
  final String title;
  final String author;
  final String? description;
  final String? language;
  final String? publisher;
  final String? publishDate;
  final String? isbn;
  final Uint8List? coverImage;
  final int estimatedPages;
  final List<String>? tags;
  final Map<String, dynamic>? additionalInfo;
  final String? textEncoding;

  EnhancedBookMetadata({
    required this.title,
    required this.author,
    this.description,
    this.language,
    this.publisher,
    this.publishDate,
    this.isbn,
    this.coverImage,
    required this.estimatedPages,
    this.tags,
    this.additionalInfo,
    this.textEncoding,
  });
}

/// 导入进度回调函数类型
typedef ImportProgressCallback = void Function(double progress, String message);

typedef ImportMetadataExtractor =
    Future<EnhancedBookMetadata> Function(
      String filePath,
      String fileName,
      String extension,
      ImportProgressCallback? onProgress,
    );

Future<Map<String, dynamic>> extractEpubMetadataInIsolate(
  Uint8List bytes,
) async {
  final book = await EpubReader.openBook(bytes);
  final schema = book.Schema;
  final package = schema?.Package;
  final metadata = package?.Metadata;
  final manifest = package?.Manifest?.Items ?? const <EpubManifestItem>[];
  final manifestById = <String, EpubManifestItem>{
    for (final item in manifest)
      if (item.Id != null) item.Id!: item,
  };

  Uint8List? coverImage;
  try {
    EpubManifestItem? coverItem;
    for (final item in manifest) {
      if ((item.Properties ?? '')
          .split(RegExp(r'\s+'))
          .contains('cover-image')) {
        coverItem = item;
        break;
      }
    }
    if (coverItem == null) {
      String? coverId;
      final metaItems = metadata?.MetaItems;
      if (metaItems != null) {
        for (final item in metaItems) {
          if (item.Name?.toLowerCase() == 'cover') {
            coverId = item.Content;
            break;
          }
        }
      }
      coverItem = coverId == null ? null : manifestById[coverId];
    }
    final href = coverItem?.Href;
    final reference = href == null ? null : book.Content?.Images?[href];
    if (reference != null) {
      coverImage = Uint8List.fromList(await reference.readContentAsBytes());
    }
  } catch (_) {
    coverImage = null;
  }

  final spineItems = package?.Spine?.Items ?? const <EpubSpineItemRef>[];
  final htmlRefs = book.Content?.Html ?? const {};
  var htmlBytes = 0;
  var chapterCount = 0;
  String? fallbackDescription;
  for (final itemRef in spineItems) {
    final item = manifestById[itemRef.IdRef];
    final href = item?.Href;
    final reference = href == null ? null : htmlRefs[href];
    if (reference == null) continue;
    chapterCount++;
    htmlBytes += reference.getContentFileEntry().size;
    if ((metadata?.Description ?? '').trim().isEmpty &&
        fallbackDescription == null) {
      try {
        final document = html_parser.parse(await reference.readContentAsText());
        final text = document.body?.text.replaceAll(RegExp(r'\s+'), ' ').trim();
        if (text != null && text.isNotEmpty) {
          fallbackDescription = text.length <= 500
              ? text
              : '${text.substring(0, 497)}...';
        }
      } catch (_) {}
    }
  }
  if (chapterCount == 0) {
    chapterCount = htmlRefs.length;
    for (final reference in htmlRefs.values) {
      htmlBytes += reference.getContentFileEntry().size;
    }
  }

  String? isbn;
  final identifiers = metadata?.Identifiers;
  if (identifiers != null) {
    for (final identifier in identifiers) {
      if (identifier.Scheme?.toLowerCase().contains('isbn') == true) {
        isbn = identifier.Identifier;
        break;
      }
    }
  }
  final description = (metadata?.Description ?? '').trim();
  return <String, dynamic>{
    'title': book.Title ?? '',
    'author': book.Author ?? '',
    'description': description.isEmpty ? fallbackDescription : description,
    'language': metadata?.Languages?.firstOrNull,
    'publisher': metadata?.Publishers?.firstOrNull,
    'publishDate': metadata?.Dates?.firstOrNull?.Date,
    'isbn': isbn,
    'coverImage': coverImage,
    'estimatedPages': (htmlBytes / 3000).ceil().clamp(1, 9999),
    'tags': metadata?.Subjects
        ?.where((subject) => subject.isNotEmpty)
        .toList(growable: false),
    'additionalInfo': <String, dynamic>{
      'format': 'EPUB',
      'hasImages': book.Content?.Images?.isNotEmpty == true,
      'chapterCount': chapterCount,
    },
  };
}

class BookImportService implements BookFileImporter {
  BookImportService({
    BookImportStore? store,
    Future<Directory> Function()? documentsDirectory,
    ImportMetadataExtractor? metadataExtractor,
    Future<void> Function(Book book)? scheduleAnalysis,
    WebBookFileStore? webBookFileStore,
  }) : _store = store ?? BookDao(),
       _documentsDirectory =
           documentsDirectory ?? getApplicationDocumentsDirectory,
       _metadataExtractorOverride = metadataExtractor,
       _webBookFileStore = webBookFileStore ?? WebBookFileStore(),
       _scheduleAnalysis =
           scheduleAnalysis ??
           ((book) => GlobalAIReadingService().scheduleImportedBookAnalysis(
             book: book,
           ));

  final BookImportStore _store;
  final Future<Directory> Function() _documentsDirectory;
  final ImportMetadataExtractor? _metadataExtractorOverride;
  final WebBookFileStore _webBookFileStore;
  final Future<void> Function(Book book) _scheduleAnalysis;
  // 旧的单文件选择入口暂时保留给尚未迁移的调用方；新队列只使用 _store。
  final _bookDao = BookDao();
  final _enhancedTxtService = EnhancedTxtImportService();
  final _preprocessor = TextPreprocessor();

  /// 流式复制文件，支持大文件和进度回调
  ///
  /// 参数 [source] 源文件
  /// 参数 [target] 目标文件
  /// 参数 [progressCallback] 进度回调函数，接收0.0-1.0的进度值
  Future<void> _copyFileWithProgress(
    File source,
    File target, {
    Function(double)? progressCallback,
  }) async {
    final fileSize = await source.length();
    final sourceStream = source.openRead();
    final targetSink = target.openWrite();

    int bytesCopied = 0;
    int lastReportedBytes = 0;
    const reportInterval = 1024 * 1024;

    try {
      await for (var chunk in sourceStream) {
        targetSink.add(chunk);
        bytesCopied += chunk.length;

        // 每复制约1MB或完成时更新进度（chunk 边界几乎不会恰好对齐
        // 1MB 整数倍，所以按累计增量判断而不是取模）
        if (bytesCopied - lastReportedBytes >= reportInterval ||
            bytesCopied >= fileSize) {
          lastReportedBytes = bytesCopied;
          final progress = bytesCopied / fileSize;
          progressCallback?.call(progress);
        }
      }

      await targetSink.flush();
      await targetSink.close();

      debugPrint('文件复制完成: ${fileSize / 1024 / 1024} MB');
    } catch (e) {
      await targetSink.close();
      // 清理写了一半的目标文件，避免残留脏文件被后续查重逻辑误认
      try {
        if (await target.exists()) {
          await target.delete();
        }
      } catch (_) {}
      debugPrint('文件复制失败: $e');
      rethrow;
    }
  }

  /// 计算文件的 MD5 哈希。导入队列不能在哈希未知时继续写库。
  Future<String> _calculateRequiredHash(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        throw const BookImportFailure(code: 'source_missing');
      }

      final fileSize = await file.length();
      if (fileSize < 5 * 1024 * 1024) {
        final bytes = await file.readAsBytes();
        return md5.convert(bytes).toString();
      }

      debugPrint('使用isolate处理大文件哈希计算: ${fileSize / 1024 / 1024} MB');
      final result = await compute(
        calculateFileHashInIsolate,
        HashCalculationParams(filePath: filePath),
      );
      debugPrint('哈希计算完成: ${result.hash}');
      return result.hash;
    } on BookImportFailure {
      rethrow;
    } catch (error) {
      throw BookImportFailure(code: 'hash_failed', cause: error);
    }
  }

  Future<Directory> _managedBooksDirectory() async {
    final documentsDir = await _documentsDirectory();
    final booksDir = Directory(join(documentsDir.path, 'books'));
    if (!await booksDir.exists()) {
      await booksDir.create(recursive: true);
    }
    return booksDir;
  }

  Future<File> _allocateTarget(Directory booksDir, String displayName) async {
    final safeName = basename(displayName);
    final fileExtension = extension(safeName);
    final baseName = basenameWithoutExtension(safeName);

    for (var counter = 0; counter < 1000; counter++) {
      final suffix = counter == 0 ? '' : '_$counter';
      final candidateName = fileExtension.isEmpty
          ? '$baseName$suffix'
          : '$baseName$suffix$fileExtension';
      final candidate = File(join(booksDir.path, candidateName));
      if (!await candidate.exists() &&
          !await File('${candidate.path}.partial').exists()) {
        return candidate;
      }
    }

    throw const BookImportFailure(code: 'target_name_exhausted');
  }

  Future<_PreparedImportFile> _prepareFile(
    BookImportSource source,
    String sourceHash,
    BookImportProgress? onProgress,
  ) async {
    final sourcePath = source.localPath;
    if (sourcePath == null) {
      throw const BookImportFailure(code: 'source_not_materialized');
    }

    final sourceFile = File(sourcePath);
    if (!await sourceFile.exists()) {
      throw const BookImportFailure(code: 'source_missing');
    }

    if (source.ownership == BookImportOwnership.managedInPlace) {
      return _PreparedImportFile(
        file: sourceFile,
        ownsFile: false,
        contentHash: sourceHash,
      );
    }

    final booksDir = await _managedBooksDirectory();
    final finalFile = await _allocateTarget(booksDir, source.displayName);
    final partial = File('${finalFile.path}.partial');
    try {
      await _copyFileWithProgress(
        sourceFile,
        partial,
        progressCallback: (value) =>
            onProgress?.call(BookImportPhase.copying, value, 'copying'),
      );
      final copiedHash = await _calculateRequiredHash(partial.path);
      if (copiedHash != sourceHash) {
        throw const BookImportFailure(code: 'copy_verification_failed');
      }
      await partial.rename(finalFile.path);
      return _PreparedImportFile(
        file: finalFile,
        ownsFile: true,
        contentHash: copiedHash,
      );
    } catch (_) {
      if (await partial.exists()) {
        await partial.delete();
      }
      rethrow;
    }
  }

  Future<String?> _calculateFileHash(String filePath) async {
    try {
      return await _calculateRequiredHash(filePath);
    } catch (error) {
      debugPrint('Error calculating file hash: $error');
      return null;
    }
  }

  Future<Book?> _checkDuplicateByHash(String hash) async {
    try {
      return await _bookDao.getBookByHash(hash);
    } catch (error) {
      debugPrint('Error checking duplicate by hash: $error');
      return null;
    }
  }

  @override
  Future<BookImportResult> importFile(
    BookImportSource source, {
    BookImportProgress? onProgress,
  }) async {
    if (kIsWeb) {
      return _importWebFile(source, onProgress: onProgress);
    }

    _PreparedImportFile? prepared;
    String? createdCoverPath;
    var databaseCommitted = false;

    try {
      onProgress?.call(BookImportPhase.checking, 0, 'checking');
      final localPath = source.localPath;
      if (localPath == null) {
        throw const BookImportFailure(code: 'source_not_materialized');
      }

      final sourceFile = File(localPath);
      if (!await sourceFile.exists()) {
        throw const BookImportFailure(code: 'source_missing');
      }
      final size = await sourceFile.length();
      if (size > maximumBookImportBytes) {
        throw const BookImportFailure(code: 'file_too_large');
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

      prepared = await _prepareFile(source, sourceHash, onProgress);
      if (duplicate != null) {
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

      onProgress?.call(BookImportPhase.analyzing, 0, 'analyzing');
      void progressAdapter(double progress, String _) {
        onProgress?.call(BookImportPhase.analyzing, progress, 'analyzing');
      }

      final metadata = _metadataExtractorOverride != null
          ? await _metadataExtractorOverride(
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

      final resolvedCoverImage = await _resolveCoverImage(
        metadata,
        source.extension,
      );
      if (resolvedCoverImage != null) {
        createdCoverPath = await _saveCoverImage(
          resolvedCoverImage,
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
      throw BookImportFailure(code: 'import_failed', cause: error);
    } finally {
      if (!databaseCommitted && prepared?.ownsFile == true) {
        final file = prepared!.file;
        if (await file.exists()) {
          await file.delete();
        }
      }
      if (!databaseCommitted && createdCoverPath != null) {
        final cover = File(createdCoverPath);
        if (await cover.exists()) {
          await cover.delete();
        }
      }
    }
  }

  Future<BookImportResult> _importWebFile(
    BookImportSource source, {
    BookImportProgress? onProgress,
  }) async {
    final bytes = source.bytes;
    final virtualPath = source.localPath;
    if (bytes == null ||
        virtualPath == null ||
        !WebBookFileStore.isWebBookPath(virtualPath)) {
      throw const BookImportFailure(code: 'source_not_materialized');
    }
    if (bytes.length > maximumBookImportBytes) {
      throw const BookImportFailure(code: 'file_too_large');
    }

    final contentHash = WebBookFileStore.hashFromPath(virtualPath);
    var storedBeforeImport = false;
    try {
      onProgress?.call(BookImportPhase.checking, 0, 'checking');
      final duplicate = await _store.getBookByHash(contentHash);
      if (duplicate != null) {
        if (WebBookFileStore.isWebBookPath(duplicate.filePath) &&
            await _webBookFileStore.exists(duplicate.filePath)) {
          return BookImportResult(
            source: source,
            outcome: BookImportOutcome.duplicateSkipped,
            book: duplicate,
          );
        }
        await _webBookFileStore.put(virtualPath, bytes);
        final repaired = await _store.updateBookStorageLocation(
          book: duplicate,
          filePath: virtualPath,
          sourceKind: source.kind.storageValue,
          sourceLocator: source.locator,
          sourceModifiedTime: source.modifiedTime,
        );
        LibraryEventBus().notifyLibraryChanged();
        return BookImportResult(
          source: source,
          outcome: BookImportOutcome.existingRepaired,
          book: repaired,
        );
      }

      onProgress?.call(BookImportPhase.analyzing, 0, 'analyzing');
      final metadata = await _extractEnhancedMetadataFromBytes(
        bytes,
        source.displayName,
        source.extension,
        progressCallback: (progress, _) =>
            onProgress?.call(BookImportPhase.analyzing, progress, 'analyzing'),
      );
      final candidate = Book(
        title: metadata.title,
        author: metadata.author,
        filePath: virtualPath,
        format: source.extension.toUpperCase(),
        totalPages: metadata.estimatedPages,
        contentHash: contentHash,
        textEncoding: metadata.textEncoding,
        sourceKind: source.kind.storageValue,
        sourceLocator: source.locator,
        sourceModifiedTime: source.modifiedTime,
      );

      onProgress?.call(BookImportPhase.saving, 0, 'saving');
      storedBeforeImport = await _webBookFileStore.exists(virtualPath);
      await _webBookFileStore.put(virtualPath, bytes);
      final decision = await _store.insertIfAbsentByHash(candidate);
      LibraryEventBus().notifyLibraryChanged();
      return BookImportResult(
        source: source,
        outcome: decision.inserted
            ? BookImportOutcome.imported
            : BookImportOutcome.duplicateSkipped,
        book: decision.book,
      );
    } on BookImportFailure {
      rethrow;
    } catch (error) {
      if (!storedBeforeImport) {
        try {
          await _webBookFileStore.delete(virtualPath);
        } catch (_) {}
      }
      throw BookImportFailure(code: 'import_failed', cause: error);
    }
  }

  /// 导入书籍，支持进度回调
  ///
  /// 参数 [progressCallback] 可选的进度回调函数，接收进度值(0.0-1.0)和描述信息
  /// 返回成功导入的Book对象，失败或取消返回null
  Future<Book?> importBook({ImportProgressCallback? progressCallback}) async {
    try {
      progressCallback?.call(0.0, '选择文件中...');

      // 使用路径模式而非数据模式，避免大文件加载到内存
      FilePickerResult? result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: BookFormatRegistry.pickerExtensions.toList(
          growable: false,
        ),
        withData: false, // 关键修改：使用路径模式
      );

      if (result != null && result.files.isNotEmpty) {
        final pickedFile = result.files.first;

        // 获取原始文件路径
        final sourcePath = pickedFile.path;
        if (sourcePath == null) {
          throw Exception('无法获取文件路径');
        }

        final sourceFile = File(sourcePath);
        final fileSize = await sourceFile.length();
        final fileSizeMB = fileSize / 1024 / 1024;
        debugPrint(
          '选择的文件: ${pickedFile.name}, 大小: ${fileSizeMB.toStringAsFixed(2)} MB',
        );

        // 检查文件大小，对超大文件给出警告
        if (fileSize > maximumBookImportBytes) {
          // 超过单本书籍限制，拒绝导入
          throw Exception(
            '文件过大无法导入\n\n'
            '文件大小：${fileSizeMB.toStringAsFixed(1)} MB\n'
            '限制大小：$maximumBookImportMegabytes MB\n\n'
            '建议：\n'
            '1. 将书籍分割为多个较小的文件\n'
            '2. 或压缩文件后再导入\n'
            '3. 使用专门的大文件阅读器',
          );
        } else if (fileSizeMB > 50) {
          // 超过 50 MB 时提醒用户导入可能较慢
          debugPrint(
            '⚠️ 警告：文件非常大 (${fileSizeMB.toStringAsFixed(1)} MB)，可能导致性能问题',
          );
          progressCallback?.call(
            0.05,
            '文件较大 (${fileSizeMB.toStringAsFixed(0)}MB)，导入可能较慢...',
          );
        } else if (fileSizeMB > 30) {
          // 30-50MB，给出警告
          debugPrint('⚠️ 提示：文件较大 (${fileSizeMB.toStringAsFixed(1)} MB)');
          progressCallback?.call(0.05, '准备导入大文件...');
        } else {
          progressCallback?.call(0.05, '准备导入...');
        }

        // 1. Get application documents directory
        final documentsDir = await getApplicationDocumentsDirectory();
        final booksDir = Directory(join(documentsDir.path, 'books'));
        if (!await booksDir.exists()) {
          await booksDir.create(recursive: true);
        }

        progressCallback?.call(0.1, '检查重复...');

        // 2. 先计算源文件哈希值，检查是否重复（避免覆盖已存在文件）
        final sourceContentHash = await _calculateFileHash(sourceFile.path);
        if (sourceContentHash != null) {
          final existingBook = await _checkDuplicateByHash(sourceContentHash);
          if (existingBook != null) {
            // 检查已存在书籍的文件是否真实存在
            final existingFile = File(existingBook.filePath);
            final existingFileExists = await existingFile.exists();

            if (!existingFileExists) {
              // 旧文件不存在，需要复制新文件并更新数据库路径
              debugPrint('检测到重复书籍但旧文件丢失，准备恢复: ${existingBook.title}');

              progressCallback?.call(0.15, '恢复丢失的文件...');

              // 继续执行复制流程，然后更新路径
              // （不在这里return，让后续流程处理）
            } else {
              // 旧文件存在，这是真正的重复
              debugPrint('Duplicate book detected: ${existingBook.title}');
              throw Exception(
                '该书籍已存在于书库中：《${existingBook.title}》\n'
                '作者：${existingBook.author}\n'
                '导入日期：${existingBook.importDate}',
              );
            }
          }
          debugPrint('File hash calculated: $sourceContentHash');
        } else {
          debugPrint('Warning: Failed to calculate source file hash');
        }

        progressCallback?.call(0.2, '开始复制文件...');

        // 3. 生成唯一的目标文件路径（避免覆盖已存在文件）
        String newFilePath;
        File targetFile;
        int counter = 0;

        do {
          if (counter == 0) {
            newFilePath = join(booksDir.path, pickedFile.name);
          } else {
            // 添加数字后缀避免覆盖
            final nameWithoutExt = pickedFile.name.replaceAll(
              RegExp(r'\.[^.]+$'),
              '',
            );
            final ext = pickedFile.extension ?? '';
            newFilePath = join(
              booksDir.path,
              '${nameWithoutExt}_$counter.$ext',
            );
          }
          targetFile = File(newFilePath);
          counter++;
        } while (await targetFile.exists() && counter < 1000);

        // 4. 流式复制文件到目标位置（支持大文件）
        await _copyFileWithProgress(
          sourceFile,
          targetFile,
          progressCallback: (progress) {
            // 将复制进度映射到0.2-0.45区间（占25%）
            progressCallback?.call(
              0.2 + progress * 0.25,
              '复制文件 ${(progress * 100).toInt()}%',
            );
          },
        );

        debugPrint('Book file saved to: $newFilePath');

        progressCallback?.call(0.5, '验证文件...');

        // 5. 验证复制后的文件哈希值
        final contentHash = await _calculateFileHash(newFilePath);
        if (contentHash != null) {
          final existingBook = await _checkDuplicateByHash(contentHash);
          if (existingBook != null) {
            // 再次检查（双重保险），如果是旧文件丢失的情况，更新路径
            final existingFile = File(existingBook.filePath);
            final existingFileExists = await existingFile.exists();

            if (!existingFileExists) {
              // 旧文件不存在，更新数据库中的文件路径到新文件
              debugPrint(
                '旧文件不存在，更新文件路径: ${existingBook.filePath} -> $newFilePath',
              );

              progressCallback?.call(0.7, '更新文件路径...');

              final updatedBook = existingBook.copyWith(filePath: newFilePath);
              await _bookDao.updateBook(updatedBook);

              progressCallback?.call(1.0, '文件路径已恢复！');

              debugPrint('✅ 文件路径已更新，书籍已恢复访问');
              // 直接返回更新后的书籍，不继续后续流程
              return updatedBook;
            }
            // 如果走到这里说明有问题（不应该发生，因为前面已经检查过了）
            debugPrint('⚠️ 警告：检测到重复但前面的检查没有捕获到');
          }
          debugPrint('File hash verified: $contentHash');
        } else {
          debugPrint('Warning: Failed to verify file hash');
        }

        progressCallback?.call(0.55, '分析书籍信息...');

        // 6. Extract enhanced metadata based on format（从文件读取而非内存）
        final metadata = await _extractEnhancedMetadataFromFile(
          newFilePath,
          pickedFile.name,
          pickedFile.extension ?? '',
          progressCallback: (subProgress, message) {
            // 将子进度映射到0.55-0.85区间（占30%）
            final mappedProgress = 0.55 + (subProgress * 0.3);
            progressCallback?.call(mappedProgress, message);
          },
        );

        progressCallback?.call(0.80, '保存封面...');

        // 4. Save cover image if available
        String? coverImagePath;
        final resolvedCoverImage = await _resolveCoverImage(
          metadata,
          pickedFile.extension ?? 'unknown',
        );
        if (resolvedCoverImage != null) {
          progressCallback?.call(0.85, '保存封面图片...');
          coverImagePath = await _saveCoverImage(
            resolvedCoverImage,
            pickedFile.name,
          );
        }

        progressCallback?.call(0.90, '写入数据库...');

        // 5. Create Book object with enhanced metadata
        final book = Book(
          title: metadata.title,
          author: metadata.author,
          filePath: newFilePath,
          format: pickedFile.extension?.toUpperCase() ?? 'UNKNOWN',
          totalPages: metadata.estimatedPages,
          coverImagePath: coverImagePath,
          contentHash: contentHash,
          textEncoding: metadata.textEncoding,
        );

        // 7. Insert metadata into the database
        progressCallback?.call(0.90, '保存到数据库...');

        final bookId = await _bookDao.insertBook(book);
        debugPrint('Enhanced book metadata inserted with ID: $bookId');
        debugPrint('Title: ${metadata.title}');
        debugPrint('Author: ${metadata.author}');
        debugPrint('Pages: ${metadata.estimatedPages}');
        debugPrint('Language: ${metadata.language ?? 'Unknown'}');
        debugPrint('Publisher: ${metadata.publisher ?? 'Unknown'}');
        LibraryEventBus().notifyLibraryChanged();

        progressCallback?.call(1.0, '导入成功！');

        final imported = book.copyWith(id: bookId);
        unawaited(
          GlobalAIReadingService().scheduleImportedBookAnalysis(book: imported),
        );

        return imported;
      }
    } catch (e) {
      debugPrint('Enhanced import process failed: $e');
      progressCallback?.call(0.0, '导入失败');
      rethrow;
    }
    return null;
  }

  /// 从文件路径提取元数据（优化大文件处理）
  ///
  /// 参数 [filePath] 文件路径
  /// 参数 [fileName] 文件名
  /// 参数 [extension] 文件扩展名
  /// 参数 [progressCallback] 进度回调，接收0.0-1.0的进度值和消息
  /// 返回提取的元数据
  Future<EnhancedBookMetadata> _extractEnhancedMetadataFromFile(
    String filePath,
    String fileName,
    String extension, {
    Function(double, String)? progressCallback,
  }) async {
    final ext = extension.toLowerCase();
    final file = File(filePath);
    final fileSize = await file.length();

    debugPrint('📖 提取元数据: $fileName (${fileSize / 1024 / 1024} MB)');

    progressCallback?.call(0.0, '读取文件...');

    if (ext == 'epub') {
      try {
        progressCallback?.call(0.2, '解析 EPUB 元数据...');
        final metadata = await compute(
          extractEpubNativeMetadata,
          <String, dynamic>{'epubPath': filePath},
        );
        progressCallback?.call(1.0, '元数据提取完成');
        return _epubMetadataFromMap(metadata, fileName);
      } catch (error) {
        debugPrint('EPUB metadata extraction failed: $error');
        return EnhancedBookMetadata(
          title: fileName.replaceAll(
            RegExp(r'\.(epub)$', caseSensitive: false),
            '',
          ),
          author: 'Unknown',
          estimatedPages: (fileSize / 10000).ceil().clamp(1, 9999),
          additionalInfo: <String, dynamic>{
            'format': 'EPUB',
            'fileSize': fileSize,
          },
        );
      }
    }

    // 📖 修改：TXT文件也完整读取，不再限制为10MB
    // 这样可以确保元数据提取基于完整内容
    Uint8List bytes;

    // 对于超大的非TXT文件（如大PDF），仍然限制读取大小避免内存问题
    const int maxBytesForMetadata = 10 * 1024 * 1024; // 10MB

    // Kindle 的 EXTH 封面记录位于文件尾部，截断头部会丢封面且破坏
    // PalmDB 记录表偏移；漫画容器的 ZIP 中央目录也在尾部、TAR 条目
    // 顺序排布（页数与首页封面依赖完整包），因此这些格式必须完整读取。
    const fullReadExtensions = <String>{
      'txt',
      'epub',
      'mobi',
      'azw',
      'azw3',
      'cbz',
      'cbt',
      'cbr',
      'cb7',
    };
    if (fileSize > maxBytesForMetadata && !fullReadExtensions.contains(ext)) {
      // 非TXT/EPUB的大文件只读取前10MB用于元数据提取
      debugPrint('⚠️ 大型${ext.toUpperCase()}文件，只读取前10MB用于元数据提取');
      progressCallback?.call(0.1, '读取大文件头部...');

      final stream = file.openRead(0, maxBytesForMetadata);
      final chunks = await stream.toList();
      final totalLength = chunks.fold<int>(
        0,
        (sum, chunk) => sum + chunk.length,
      );
      final buffer = Uint8List(totalLength);
      int offset = 0;
      for (var chunk in chunks) {
        buffer.setRange(offset, offset + chunk.length, chunk);
        offset += chunk.length;
      }
      bytes = buffer;

      progressCallback?.call(0.3, '分析文件内容...');
    } else {
      // TXT、EPUB或小文件，完整读取
      final fileSizeMB = fileSize / 1024 / 1024;
      if (fileSizeMB > 10) {
        debugPrint(
          '📖 完整读取${ext.toUpperCase()}文件 (${fileSizeMB.toStringAsFixed(1)} MB)',
        );
      }
      progressCallback?.call(0.2, '加载文件内容...');
      bytes = await file.readAsBytes();
      progressCallback?.call(0.4, '解析文件格式...');
    }

    return _extractEnhancedMetadataFromBytes(
      bytes,
      fileName,
      extension,
      progressCallback: progressCallback,
    );
  }

  Future<EnhancedBookMetadata> _extractEnhancedMetadataFromBytes(
    Uint8List bytes,
    String fileName,
    String extension, {
    Function(double, String)? progressCallback,
  }) async {
    final ext = extension.toLowerCase();
    try {
      final metadata = switch (ext) {
        'epub' => _epubMetadataFromMap(
          await compute(extractEpubMetadataInIsolate, bytes),
          fileName,
        ),
        'pdf' => await _extractPdfMetadata(bytes, fileName),
        'txt' => await _extractTxtMetadata(bytes, fileName),
        'mobi' ||
        'azw' ||
        'azw3' => await _extractMobiMetadata(bytes, fileName),
        'fb2' => await _extractFb2Metadata(bytes, fileName),
        'cbz' ||
        'cbr' ||
        'cbt' ||
        'cb7' => await _extractComicMetadata(bytes, fileName),
        'rtf' => await _extractRtfMetadata(bytes, fileName),
        _ => _extractBasicMetadata(bytes, fileName),
      };
      progressCallback?.call(1.0, '元数据提取完成');
      return metadata;
    } catch (error) {
      debugPrint('❌ 元数据提取失败: $error');
      progressCallback?.call(0.8, '使用默认信息...');
      return _extractBasicMetadata(bytes, fileName);
    }
  }

  /// Extract comprehensive EPUB metadata
  EnhancedBookMetadata _epubMetadataFromMap(
    Map<String, dynamic> metadata,
    String fileName,
  ) {
    final title = (metadata['title'] as String? ?? '').trim();
    final author = (metadata['author'] as String? ?? '').trim();
    return EnhancedBookMetadata(
      title: title.isEmpty
          ? fileName.replaceAll(RegExp(r'\.(epub)$', caseSensitive: false), '')
          : title,
      author: author.isEmpty ? 'Unknown' : author,
      description: metadata['description'] as String?,
      language: metadata['language'] as String?,
      publisher: metadata['publisher'] as String?,
      publishDate: metadata['publishDate'] as String?,
      isbn: metadata['isbn'] as String?,
      coverImage: metadata['coverImage'] as Uint8List?,
      estimatedPages: metadata['estimatedPages'] as int? ?? 1,
      tags: (metadata['tags'] as List<dynamic>?)?.cast<String>(),
      additionalInfo: Map<String, dynamic>.from(
        metadata['additionalInfo'] as Map? ?? const {},
      ),
    );
  }

  /// Extract PDF metadata
  Future<EnhancedBookMetadata> _extractPdfMetadata(
    Uint8List bytes,
    String fileName,
  ) async {
    try {
      final pdfDocument = await PdfDocument.openData(bytes);
      final pageCount = pdfDocument.pagesCount;

      // Extract basic metadata - PDF metadata is often limited
      final title = fileName.replaceAll(RegExp(r'\.(pdf)$'), '');
      const author = 'Unknown';

      // 优先使用 PDF 第一页；失败时仅在本地生成默认封面。
      Uint8List? coverImage;
      try {
        coverImage = await _extractPdfCover(bytes);
        if (coverImage == null) {
          coverImage = await CoverGenerator.generateTextCover(
            title: title,
            author: author,
            format: 'PDF',
          );
        } else {
          debugPrint('✅ 成功从PDF提取封面（第一页）');
        }
      } catch (e) {
        debugPrint('⚠️ PDF封面处理失败: $e，生成默认封面');
        try {
          coverImage = await CoverGenerator.generateTextCover(
            title: title,
            author: author,
            format: 'PDF',
          );
        } catch (genError) {
          debugPrint('❌ PDF封面生成失败: $genError');
        }
      }

      await pdfDocument.close();

      return EnhancedBookMetadata(
        title: title,
        author: 'Unknown',
        estimatedPages: pageCount,
        coverImage: coverImage,
        additionalInfo: {'format': 'PDF', 'actualPageCount': pageCount},
      );
    } catch (e) {
      debugPrint('PDF metadata extraction failed: $e');
      final fileSize = bytes.length;
      final estimatedPages = (fileSize / 50000).ceil().clamp(1, 9999);

      return EnhancedBookMetadata(
        title: fileName.replaceAll(RegExp(r'\.(pdf)$'), ''),
        author: 'Unknown',
        estimatedPages: estimatedPages,
      );
    }
  }

  /// 使用增强服务提取TXT元数据（使用isolate优化），编码自动检测
  Future<EnhancedBookMetadata> _extractTxtMetadata(
    Uint8List bytes,
    String fileName,
  ) async {
    try {
      var resolvedEncoding = _enhancedTxtService.detectEncoding(bytes);

      // 对于大文件，使用isolate处理
      SimpleMetadata simpleMetadata;
      if (bytes.length > 5 * 1024 * 1024) {
        // 大于5MB，使用isolate。isolate 消息是拷贝语义，只传
        // 元数据分析所需的头部切片，完整长度单独传给页数估算。
        const headSliceBytes = 100 * 1024;
        simpleMetadata = await compute(
          extractTxtMetadataInIsolate,
          MetadataExtractionParams(
            // sublist 而非 sublistView：视图发给 isolate 会连带
            // 拷贝整个底层缓冲区
            bytes: bytes.sublist(0, headSliceBytes),
            fileName: fileName,
            extension: 'txt',
            encodingOverride: resolvedEncoding,
            totalByteLength: bytes.length,
          ),
        );
      } else {
        // 小文件在主线程处理
        String content;
        try {
          final decodeResult = _enhancedTxtService.decodeWithResult(
            bytes,
            encodingOverride: resolvedEncoding,
          );
          content = decodeResult.content;
          resolvedEncoding = decodeResult.encoding;
        } catch (e) {
          content = utf8.decode(bytes, allowMalformed: true);
          resolvedEncoding = 'utf8';
        }

        // 文本预处理：压缩空行、添加缩进、段落间距
        content = _preprocessor.process(
          content,
          indentSize: 2,
          indentDialogue: true,
          compressEmptyLines: true,
          paragraphSpacing: 0,
        );

        // 不要使用 trim()，否则会移除段首缩进
        final lines = content
            .split('\n')
            .where((e) => e.trim().isNotEmpty)
            .toList();
        var title = lines.isNotEmpty
            ? lines.first.substring(0, lines.first.length.clamp(0, 50))
            : fileName.replaceAll(RegExp(r'\.(txt)$'), '');
        if (_looksGarbled(title)) {
          title = fileName.replaceAll(RegExp(r'\.(txt)$'), '');
        }
        final estimatedPages = (content.length / 1500).ceil().clamp(1, 9999);

        simpleMetadata = SimpleMetadata(
          title: title,
          author: 'Unknown',
          estimatedPages: estimatedPages,
          description: content.length > 200 ? content.substring(0, 200) : null,
          language: 'zh',
        );
      }

      // TXT 没有嵌入封面，仅在本地生成默认封面。
      Uint8List? coverImage;
      try {
        coverImage = await CoverGenerator.generateTextCover(
          title: simpleMetadata.title,
          author: simpleMetadata.author,
          format: 'TXT',
        );
        debugPrint('✅ TXT默认封面生成成功');
      } catch (e) {
        debugPrint('默认封面生成失败: $e');
      }

      debugPrint('✅ TXT元数据提取完成:');
      debugPrint('   标题: ${simpleMetadata.title}');
      debugPrint('   作者: ${simpleMetadata.author}');
      debugPrint('   预估页数: ${simpleMetadata.estimatedPages}');

      return EnhancedBookMetadata(
        title: simpleMetadata.title,
        author: simpleMetadata.author,
        description: simpleMetadata.description,
        estimatedPages: simpleMetadata.estimatedPages,
        language: simpleMetadata.language,
        coverImage: coverImage,
        textEncoding: resolvedEncoding,
        additionalInfo: {'format': 'TXT', 'fileSize': bytes.length},
      );
    } catch (e, stackTrace) {
      debugPrint('❌ TXT元数据提取失败，回退到基础提取: $e');
      debugPrint('Stack trace: $stackTrace');
      return _extractBasicMetadata(bytes, fileName);
    }
  }

  bool _looksGarbled(String text) {
    final value = text.trim();
    if (value.isEmpty) {
      return true;
    }

    int total = 0;
    int cjk = 0;
    int asciiLetters = 0;
    int digits = 0;
    int latinExtended = 0;
    int otherNonAscii = 0;
    int replacement = 0;

    for (final rune in value.runes) {
      if (rune <= 0x20) {
        continue;
      }
      total++;
      if (rune == 0xfffd) {
        replacement++;
        continue;
      }
      if ((rune >= 0x4e00 && rune <= 0x9fff) ||
          (rune >= 0x3400 && rune <= 0x4dbf) ||
          (rune >= 0xf900 && rune <= 0xfaff)) {
        cjk++;
        continue;
      }
      if ((rune >= 0x41 && rune <= 0x5a) || (rune >= 0x61 && rune <= 0x7a)) {
        asciiLetters++;
        continue;
      }
      if (rune >= 0x30 && rune <= 0x39) {
        digits++;
        continue;
      }
      if (rune >= 0x00c0 && rune <= 0x024f) {
        latinExtended++;
        continue;
      }
      if (rune > 0x7e) {
        otherNonAscii++;
      }
    }

    if (total == 0 || replacement > 0) {
      return true;
    }

    final asciiRatio = (asciiLetters + digits) / total;
    final cjkRatio = cjk / total;
    final nonAsciiRatio = (latinExtended + otherNonAscii) / total;

    if (cjkRatio >= 0.2) {
      return false;
    }
    if (asciiRatio >= 0.6) {
      return false;
    }
    return nonAsciiRatio >= 0.3;
  }

  /// Extract FictionBook 2 (FB2) metadata
  Future<EnhancedBookMetadata> _extractFb2Metadata(
    Uint8List bytes,
    String fileName,
  ) async {
    try {
      debugPrint('FB2 metadata extraction - using basic XML parsing');

      // 直接使用 XML 解析
      return await _extractFb2MetadataXml(bytes, fileName);
    } catch (e) {
      debugPrint('FB2 metadata extraction failed: $e');
      return _extractBasicMetadata(bytes, fileName);
    }
  }

  /// FB2 XML 基础解析回退方案。
  Future<EnhancedBookMetadata> _extractFb2MetadataXml(
    Uint8List bytes,
    String fileName,
  ) async {
    try {
      final xmlContent = utf8.decode(bytes);

      // Parse FB2 XML structure
      String title = fileName.replaceAll(RegExp(r'\.(fb2)$'), '');
      String author = 'Unknown';
      String? description;
      String? language;
      List<String>? tags;
      Uint8List? coverImage;

      // Extract title
      final titleMatch = RegExp(
        r'<book-title[^>]*>(.*?)</book-title>',
        dotAll: true,
      ).firstMatch(xmlContent);
      if (titleMatch != null) {
        title = _stripXmlTags(titleMatch.group(1) ?? '').trim();
      }

      // Extract author (enhanced)
      final authorMatch = RegExp(
        r'<author[^>]*>.*?<first-name[^>]*>(.*?)</first-name>.*?<last-name[^>]*>(.*?)</last-name>.*?</author>',
        dotAll: true,
      ).firstMatch(xmlContent);
      if (authorMatch != null) {
        final firstName = _stripXmlTags(authorMatch.group(1) ?? '').trim();
        final lastName = _stripXmlTags(authorMatch.group(2) ?? '').trim();
        author = '$firstName $lastName'.trim();
      } else {
        // 尝试简单作者匹配
        final simpleAuthorMatch = RegExp(
          r'<author[^>]*>(.*?)</author>',
          dotAll: true,
        ).firstMatch(xmlContent);
        if (simpleAuthorMatch != null) {
          author = _stripXmlTags(simpleAuthorMatch.group(1) ?? '').trim();
        }
      }

      // Extract description (enhanced)
      final descMatch = RegExp(
        r'<annotation[^>]*>(.*?)</annotation>',
        dotAll: true,
      ).firstMatch(xmlContent);
      if (descMatch != null) {
        description = _stripXmlTags(descMatch.group(1) ?? '').trim();
        // 限制描述长度
        if (description.length > 500) {
          description = '${description.substring(0, 497)}...';
        }
      }

      // Extract language
      final langMatch = RegExp(
        r'<lang[^>]*>(.*?)</lang>',
      ).firstMatch(xmlContent);
      if (langMatch != null) {
        language = langMatch.group(1)?.trim();
      }

      // Extract genres as tags
      final genreMatches = RegExp(
        r'<genre[^>]*>(.*?)</genre>',
      ).allMatches(xmlContent);
      if (genreMatches.isNotEmpty) {
        tags = genreMatches
            .map((match) => match.group(1)?.trim() ?? '')
            .where((tag) => tag.isNotEmpty)
            .toList();
      }

      // Try to extract cover image from FB2
      coverImage = await _extractFb2Cover(xmlContent);

      final textContent = _stripXmlTags(xmlContent);
      final estimatedPages = (textContent.length / 1500).ceil().clamp(1, 9999);

      return EnhancedBookMetadata(
        title: title,
        author: author,
        description: description,
        language: language,
        coverImage: coverImage,
        estimatedPages: estimatedPages,
        tags: tags,
        additionalInfo: {
          'format': 'FB2',
          'characterCount': textContent.length,
          'parsedByXml': true,
        },
      );
    } catch (e) {
      debugPrint('FB2 XML metadata extraction failed: $e');
      return _extractBasicMetadata(bytes, fileName);
    }
  }

  /// 从 FB2 文件提取封面图片
  Future<Uint8List?> _extractFb2Cover(String xmlContent) async {
    try {
      // FB2 格式中的封面通常在 <binary> 标签中
      final binaryPattern = RegExp(
        r'<binary[^>]*id\s*=\s*["\x27]([^"\x27]*cover[^"\x27]*)["\x27][^>]*>(.*?)</binary>',
        dotAll: true,
        caseSensitive: false,
      );
      final binaryMatch = binaryPattern.firstMatch(xmlContent);

      if (binaryMatch != null) {
        final base64Content = binaryMatch.group(2)?.trim() ?? '';
        if (base64Content.isNotEmpty) {
          try {
            // 清理base64字符串（移除换行和空格）
            final cleanBase64 = base64Content.replaceAll(RegExp(r'\s+'), '');
            return base64.decode(cleanBase64);
          } catch (e) {
            debugPrint('FB2 封面base64解码失败: $e');
          }
        }
      }

      // 尝试查找其他可能的图片
      final allBinaryMatches = RegExp(
        r"<binary[^>]*>(.*?)</binary>",
        dotAll: true,
      ).allMatches(xmlContent);

      for (final match in allBinaryMatches) {
        final base64Content = match.group(1)?.trim() ?? '';
        if (base64Content.isNotEmpty && base64Content.length > 100) {
          try {
            final cleanBase64 = base64Content.replaceAll(RegExp(r'\s+'), '');
            final imageBytes = base64.decode(cleanBase64);
            if (_isValidImageFormat(imageBytes)) {
              return imageBytes;
            }
          } catch (e) {
            continue; // 尝试下一个
          }
        }
      }

      return null;
    } catch (e) {
      debugPrint('FB2 封面提取失败: $e');
      return null;
    }
  }

  /// Extract MOBI/AZW3 metadata using basic parsing（使用isolate优化）
  Future<EnhancedBookMetadata> _extractMobiMetadata(
    Uint8List bytes,
    String fileName,
  ) async {
    try {
      debugPrint('📚 开始MOBI/AZW/AZW3元数据提取: $fileName');

      // 头部解析（PalmDB/EXTH/封面记录切片）本身很轻，但大文件在
      // isolate 里做可避免记录表扫描挤占 UI 帧。
      final kindle = bytes.length > 5 * 1024 * 1024
          ? await compute(parseKindleMetadata, bytes)
          : parseKindleMetadata(bytes);

      final fallbackTitle = fileName.replaceAll(
        RegExp(r'\.(mobi|azw|azw3)$', caseSensitive: false),
        '',
      );
      final title = kindle.title.isNotEmpty ? kindle.title : fallbackTitle;
      final author = kindle.authors.isNotEmpty
          ? kindle.authors.join(', ')
          : 'Unknown';

      // 优先内嵌封面；没有时本地生成默认封面。
      Uint8List? coverImage = kindle.coverImage;
      if (coverImage == null || coverImage.isEmpty) {
        try {
          coverImage = await CoverGenerator.generateTextCover(
            title: title,
            author: author,
            format: 'MOBI',
          );
        } catch (e) {
          debugPrint('❌ MOBI默认封面生成失败: $e');
        }
      }

      // PalmDOC textLength 是未压缩正文字节数，比文件大小更接近真实篇幅。
      final estimatedPages = kindle.textLength > 0
          ? (kindle.textLength / 1500).ceil().clamp(1, 99999)
          : (bytes.length / 3000).ceil().clamp(50, 1000);

      debugPrint(
        '✅ MOBI元数据提取完成: $title / $author'
        '${kindle.hasDrm ? '（DRM 加密，正文不可读）' : ''}',
      );

      return EnhancedBookMetadata(
        title: title,
        author: author,
        description: kindle.description,
        language: kindle.language,
        publisher: kindle.publisher,
        publishDate: kindle.publishedDate,
        isbn: kindle.isbn,
        coverImage: coverImage,
        estimatedPages: estimatedPages,
        tags: kindle.subjects.isNotEmpty ? kindle.subjects : null,
        additionalInfo: {
          'format': 'MOBI/AZW',
          'fileSize': bytes.length,
          'hasDrm': kindle.hasDrm,
        },
      );
    } catch (e) {
      debugPrint('MOBI/AZW3 metadata extraction failed: $e');
      return _extractBasicMobiMetadata(bytes, fileName);
    }
  }

  /// MOBI 元数据基础解析回退方案。
  EnhancedBookMetadata _extractBasicMobiMetadata(
    Uint8List bytes,
    String fileName,
  ) {
    final title = fileName.replaceAll(RegExp(r'\.(mobi|azw|azw3)$'), '');
    final estimatedPages = (bytes.length / 3000).ceil().clamp(50, 1000);

    return EnhancedBookMetadata(
      title: title,
      author: 'Unknown',
      estimatedPages: estimatedPages,
      additionalInfo: {
        'format': fileName.split('.').last.toUpperCase(),
        'fileSize': bytes.length,
        'note': 'Basic metadata extraction fallback',
      },
    );
  }

  /// Extract Comic Book (CBZ/CBR/CBT/CB7) metadata
  Future<EnhancedBookMetadata> _extractComicMetadata(
    Uint8List bytes,
    String fileName,
  ) async {
    try {
      // 漫画容器统一按文件头识别：ZIP/TAR（含改名的 CBR/CB7）可解包。
      final extension = fileName.split('.').last.toLowerCase();
      final title = fileName.replaceAll(RegExp(r'\.(cbz|cbr|cbt|cb7)$'), '');

      // For comic books, we can extract some basic info
      String author = 'Unknown';

      // Try to extract info from filename patterns
      final seriesMatch = RegExp(r'^(.+?)\s*#?\d+').firstMatch(title);
      if (seriesMatch != null) {
        author = 'Series: ${seriesMatch.group(1)}';
      }

      // 可解包的容器取真实页数 + 第一页作封面；真 RAR/7z 或字节被
      // 截断时解包会抛错，回退到估算值和生成封面。
      int estimatedPages = extension == 'cbz' ? 25 : 30;
      Uint8List? coverImage;
      try {
        final pages = await compute(indexComicPages, <String, dynamic>{
          'bytes': bytes,
          'ext': extension,
        });
        if (pages.isNotEmpty) {
          estimatedPages = pages.length;
          coverImage = await compute(extractComicPage, <String, dynamic>{
            'bytes': bytes,
            'ext': extension,
            'name': pages.first,
          });
        }
      } catch (e) {
        debugPrint('漫画页索引/封面提取失败，使用回退元数据: $e');
      }

      return EnhancedBookMetadata(
        title: title,
        author: author,
        description: 'Comic book in ${extension.toUpperCase()} format',
        coverImage: coverImage,
        estimatedPages: estimatedPages,
        additionalInfo: {
          'format': extension.toUpperCase(),
          'mediaType': 'comic',
          'isArchive': true,
          'note': 'Comic book archive - contains image files',
        },
      );
    } catch (e) {
      debugPrint('Comic metadata extraction failed: $e');
      return _extractBasicMetadata(bytes, fileName);
    }
  }

  /// Extract RTF metadata
  Future<EnhancedBookMetadata> _extractRtfMetadata(
    Uint8List bytes,
    String fileName,
  ) async {
    try {
      final content = utf8.decode(bytes);

      // RTF files contain control codes, extract plain text
      String title = fileName.replaceAll(RegExp(r'\.(rtf)$'), '');
      String author = 'Unknown';

      // Extract title from RTF info if available
      final titleMatch = RegExp(r'\\title\s+([^}]+)').firstMatch(content);
      if (titleMatch != null) {
        title = titleMatch.group(1)?.trim() ?? title;
      }

      // Extract author from RTF info
      final authorMatch = RegExp(r'\\author\s+([^}]+)').firstMatch(content);
      if (authorMatch != null) {
        author = authorMatch.group(1)?.trim() ?? author;
      }

      // Strip RTF control codes to get plain text
      final plainText = content
          .replaceAll(RegExp(r'\\[a-z]+\d*\s*'), ' ')
          .replaceAll(RegExp(r'[{}]'), ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();

      final estimatedPages = (plainText.length / 1500).ceil().clamp(1, 9999);

      return EnhancedBookMetadata(
        title: title,
        author: author,
        estimatedPages: estimatedPages,
        additionalInfo: {'format': 'RTF', 'characterCount': plainText.length},
      );
    } catch (e) {
      debugPrint('RTF metadata extraction failed: $e');
      return _extractBasicMetadata(bytes, fileName);
    }
  }

  /// Basic metadata extraction fallback
  EnhancedBookMetadata _extractBasicMetadata(Uint8List bytes, String fileName) {
    final fileSize = bytes.length;
    final estimatedPages = (fileSize / 10000).ceil().clamp(1, 9999);
    final extension = fileName.split('.').last.toUpperCase();

    return EnhancedBookMetadata(
      title: fileName.replaceAll(RegExp(r'\.[^.]+$'), ''),
      author: 'Unknown',
      estimatedPages: estimatedPages,
      additionalInfo: {'format': extension, 'fileSize': fileSize},
    );
  }

  /// 所有本地导入格式共用的封面兜底。
  ///
  /// 格式解析器只负责尽量提供真实封面；若没有真实封面，则统一根据书名和
  /// 作者生成，避免不同格式各自维护一套默认封面分支。
  Future<Uint8List?> _resolveCoverImage(
    EnhancedBookMetadata metadata,
    String format,
  ) async {
    if (metadata.coverImage != null) return metadata.coverImage;
    try {
      return await CoverGenerator.generateTextCover(
        title: metadata.title,
        author: metadata.author,
        format: format,
      );
    } catch (error) {
      debugPrint('生成默认封面失败: $error');
      return null;
    }
  }

  /// Save cover image to disk
  Future<String?> _saveCoverImage(
    Uint8List imageBytes,
    String bookFileName,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final autoExtractEnabled =
          prefs.getBool('enableAutoExtractCover') ?? true;
      if (!autoExtractEnabled) {
        debugPrint('Auto cover extraction disabled, skip saving cover image.');
        return null;
      }

      final documentsDir = await _documentsDirectory();
      final coversDir = Directory(join(documentsDir.path, 'covers'));
      if (!await coversDir.exists()) {
        await coversDir.create(recursive: true);
      }

      final bookName = bookFileName.replaceAll(RegExp(r'\.[^.]+$'), '');
      // 文件名加入完整文件名（含扩展名）的哈希后缀，
      // 避免"同名不同格式"的书封面互相覆盖
      final nameHash = md5
          .convert(utf8.encode(bookFileName))
          .toString()
          .substring(0, 8);
      final coverPath = join(
        coversDir.path,
        '${bookName}_${nameHash}_cover.jpg',
      );
      final coverFile = File(coverPath);

      await coverFile.writeAsBytes(imageBytes);
      debugPrint('Cover image saved to: $coverPath');

      return coverPath;
    } catch (e) {
      debugPrint('Failed to save cover image: $e');
      return null;
    }
  }

  String _stripXmlTags(String xml) {
    return xml
        .replaceAll(RegExp(r'<[^>]*>'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'&[a-zA-Z0-9#]+;'), ' ') // Remove XML entities
        .trim();
  }

  /// 验证图片格式
  bool _isValidImageFormat(Uint8List bytes) {
    if (bytes.length < 10) return false;

    // 检查文件头
    final header = bytes.take(10).toList();

    // JPEG: FF D8 FF
    if (header[0] == 0xFF && header[1] == 0xD8 && header[2] == 0xFF) {
      return true;
    }

    // PNG: 89 50 4E 47 0D 0A 1A 0A
    if (header[0] == 0x89 &&
        header[1] == 0x50 &&
        header[2] == 0x4E &&
        header[3] == 0x47) {
      return true;
    }

    // GIF: 47 49 46 38
    if (header[0] == 0x47 &&
        header[1] == 0x49 &&
        header[2] == 0x46 &&
        header[3] == 0x38) {
      return true;
    }

    // WebP: 52 49 46 46 ... 57 45 42 50
    if (header[0] == 0x52 &&
        header[1] == 0x49 &&
        header[2] == 0x46 &&
        header[3] == 0x46 &&
        bytes.length > 12 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50) {
      return true;
    }

    return false;
  }

  /// 增强的PDF封面提取
  Future<Uint8List?> _extractPdfCover(Uint8List bytes) async {
    PdfDocument? pdfDocument;
    PdfPage? page;
    try {
      pdfDocument = await PdfDocument.openData(bytes);

      // 获取第一页作为封面
      if (pdfDocument.pagesCount > 0) {
        page = await pdfDocument.getPage(1);
        final pageImage = await page.render(
          width: 300, // 封面宽度
          height: 400, // 封面高度
        );

        if (pageImage?.bytes != null && pageImage!.bytes.isNotEmpty) {
          return pageImage.bytes;
        }
      }

      return null;
    } catch (e) {
      debugPrint('Error extracting PDF cover: $e');
      return null;
    } finally {
      // render 抛异常时也要释放原生 PDF 句柄
      try {
        await page?.close();
      } catch (_) {}
      try {
        await pdfDocument?.close();
      } catch (_) {}
    }
  }
}

class _PreparedImportFile {
  const _PreparedImportFile({
    required this.file,
    required this.ownsFile,
    required this.contentHash,
  });

  final File file;
  final bool ownsFile;
  final String contentHash;
}
