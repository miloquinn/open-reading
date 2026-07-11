// 文件说明：书籍导入总入口，统筹 TXT、EPUB、PDF 和压缩包的导入流程。
// 技术要点：服务层、File Picker、Path、Path Provider、SharedPreferences、EPUBX。

import 'dart:io';
import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:epubx/epubx.dart';
import 'package:pdfx/pdfx.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';

import 'package:xxread/models/book.dart';
import 'package:xxread/services/books/book_dao.dart';
import 'package:xxread/services/books/enhanced_txt_import_service.dart';
import 'package:xxread/services/books/text_preprocessor_helper.dart';
import 'package:xxread/services/books/cover_generator_service.dart';
import 'package:xxread/services/books/book_cover_fetcher_service.dart';
import 'package:xxread/services/books/book_import_isolate_service.dart';
import 'package:xxread/services/books/epub_image_extractor_service.dart';
import 'package:xxread/services/books/book_image_map_service.dart';
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

/// 顶层函数：在 isolate 中解析 EPUB（zip 解压 + XML 解析是 CPU
/// 密集操作，放主线程会掉帧）。
Future<EpubBook> parseEpubBookInIsolate(Uint8List bytes) {
  return EpubReader.readBook(bytes);
}

class BookImportService {
  final _bookDao = BookDao();
  final _enhancedTxtService = EnhancedTxtImportService();
  final _preprocessor = TextPreprocessor();
  final _coverFetcher = BookCoverFetcher();
  final _imageExtractor = EpubImageExtractor();
  final _imageMapService = BookImageMapService();

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

  /// 计算文件的MD5哈希值（使用isolate优化）
  ///
  /// 参数 [filePath] 文件的完整路径
  /// 返回计算出的MD5哈希值字符串，失败返回null
  Future<String?> _calculateFileHash(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        debugPrint('File does not exist: $filePath');
        return null;
      }

      // 小文件直接在主线程处理
      final fileSize = await file.length();
      if (fileSize < 5 * 1024 * 1024) {
        // 小于5MB，直接处理
        final bytes = await file.readAsBytes();
        final digest = md5.convert(bytes);
        return digest.toString();
      }

      // 大文件使用isolate分块处理
      debugPrint('使用isolate处理大文件哈希计算: ${fileSize / 1024 / 1024} MB');
      final result = await compute(
        calculateFileHashInIsolate,
        HashCalculationParams(filePath: filePath),
      );
      debugPrint('哈希计算完成: ${result.hash}');
      return result.hash;
    } catch (e) {
      debugPrint('Error calculating file hash: $e');
      return null;
    }
  }

  /// 检查书籍是否已通过哈希值导入
  ///
  /// 参数 [hash] 文件的MD5哈希值
  /// 返回已存在的书籍对象，如果不存在返回null
  Future<Book?> _checkDuplicateByHash(String hash) async {
    try {
      return await _bookDao.getBookByHash(hash);
    } catch (e) {
      debugPrint('Error checking duplicate by hash: $e');
      return null;
    }
  }

  /// 导入书籍，支持进度回调
  ///
  /// 参数 [progressCallback] 可选的进度回调函数，接收进度值(0.0-1.0)和描述信息
  /// 返回成功导入的Book对象，失败或取消返回null
  Future<Book?> importBook({
    ImportProgressCallback? progressCallback,
  }) async {
    try {
      progressCallback?.call(0.0, '选择文件中...');

      // 使用路径模式而非数据模式，避免大文件加载到内存
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: [
          'txt',
          'epub',
          'pdf',
          'mobi',
          'azw',
          'azw3',
          'fb2',
          'rtf',
          'doc',
          'docx',
          'cbz',
          'cbr',
        ],
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
            '选择的文件: ${pickedFile.name}, 大小: ${fileSizeMB.toStringAsFixed(2)} MB');

        // 检查文件大小，对超大文件给出警告
        if (fileSizeMB > 100) {
          // 超过100MB，拒绝导入
          throw Exception('文件过大无法导入\n\n'
              '文件大小：${fileSizeMB.toStringAsFixed(1)} MB\n'
              '限制大小：100 MB\n\n'
              '建议：\n'
              '1. 将书籍分割为多个较小的文件\n'
              '2. 或压缩文件后再导入\n'
              '3. 使用专门的大文件阅读器');
        } else if (fileSizeMB > 50) {
          // 50-100MB，给出严重警告
          debugPrint(
              '⚠️ 警告：文件非常大 (${fileSizeMB.toStringAsFixed(1)} MB)，可能导致性能问题');
          progressCallback?.call(
              0.05, '文件较大 (${fileSizeMB.toStringAsFixed(0)}MB)，导入可能较慢...');
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
            final nameWithoutExt =
                pickedFile.name.replaceAll(RegExp(r'\.[^.]+$'), '');
            final ext = pickedFile.extension ?? '';
            newFilePath =
                join(booksDir.path, '${nameWithoutExt}_$counter.$ext');
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
                  '旧文件不存在，更新文件路径: ${existingBook.filePath} -> $newFilePath');

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
        if (metadata.coverImage != null) {
          progressCallback?.call(0.85, '保存封面图片...');
          coverImagePath = await _saveCoverImage(
            metadata.coverImage!,
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

        // 🖼️ 如果是EPUB格式，保存图片映射
        if (pickedFile.extension?.toLowerCase() == 'epub' &&
            metadata.additionalInfo?['imageMap'] != null) {
          final oldImageMap =
              metadata.additionalInfo!['imageMap'] as Map<String, String>;
          if (oldImageMap.isNotEmpty) {
            progressCallback?.call(0.95, '保存图片映射...');

            // 🔧 修复键名：将临时bookId替换为真正的bookId
            final newImageMap = <String, String>{};
            final bookIdStr = bookId.toString();

            for (var entry in oldImageMap.entries) {
              // 提取文件名部分（去掉临时bookId前缀）
              final parts = entry.key.split('_');
              if (parts.length >= 2) {
                // 重建键名：真实bookId_文件名
                final fileName = parts.sublist(1).join('_');
                final newKey = '${bookIdStr}_$fileName';
                // 🔧 清理路径：移除所有换行符和多余空白
                final cleanPath =
                    entry.value.replaceAll(RegExp(r'[\r\n\t]'), '').trim();
                newImageMap[newKey] = cleanPath;
                debugPrint('🔧 修复映射键: ${entry.key} -> $newKey');
              } else {
                // 保持原样（以防万一）
                final cleanPath =
                    entry.value.replaceAll(RegExp(r'[\r\n\t]'), '').trim();
                newImageMap[entry.key] = cleanPath;
              }
            }

            await _imageMapService.saveImageMap(bookId, newImageMap);
            debugPrint('✅ 图片映射已保存: ${newImageMap.length} 张');

            // 当前阅读引擎按需分页，无需在导入阶段清除分页结果。
          }
        }

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

    // 📖 修改：TXT文件也完整读取，不再限制为10MB
    // 这样可以确保元数据提取基于完整内容
    Uint8List bytes;

    // 对于超大的非TXT文件（如大PDF），仍然限制读取大小避免内存问题
    const int maxBytesForMetadata = 10 * 1024 * 1024; // 10MB

    if (fileSize > maxBytesForMetadata && ext != 'txt' && ext != 'epub') {
      // 非TXT/EPUB的大文件只读取前10MB用于元数据提取
      debugPrint('⚠️ 大型${ext.toUpperCase()}文件，只读取前10MB用于元数据提取');
      progressCallback?.call(0.1, '读取大文件头部...');

      final stream = file.openRead(0, maxBytesForMetadata);
      final chunks = await stream.toList();
      final totalLength =
          chunks.fold<int>(0, (sum, chunk) => sum + chunk.length);
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
            '📖 完整读取${ext.toUpperCase()}文件 (${fileSizeMB.toStringAsFixed(1)} MB)');
      }
      progressCallback?.call(0.2, '加载文件内容...');
      bytes = await file.readAsBytes();
      progressCallback?.call(0.4, '解析文件格式...');
    }

    try {
      EnhancedBookMetadata metadata;

      switch (ext) {
        case 'epub':
          progressCallback?.call(0.5, '解析EPUB格式...');
          metadata = await _extractEpubMetadata(bytes, fileName);
          break;
        case 'pdf':
          progressCallback?.call(0.5, '解析PDF格式...');
          metadata = await _extractPdfMetadata(bytes, fileName);
          break;
        case 'txt':
          progressCallback?.call(0.5, '检测文本编码...');
          metadata = await _extractTxtMetadata(bytes, fileName);
          break;
        case 'mobi':
        case 'azw':
        case 'azw3':
          progressCallback?.call(0.5, '解析MOBI格式...');
          metadata = await _extractMobiMetadata(bytes, fileName);
          break;
        case 'fb2':
          progressCallback?.call(0.5, '解析FB2格式...');
          metadata = await _extractFb2Metadata(bytes, fileName);
          break;
        case 'cbz':
        case 'cbr':
          progressCallback?.call(0.5, '解析漫画格式...');
          metadata = await _extractComicMetadata(bytes, fileName);
          break;
        case 'rtf':
          progressCallback?.call(0.5, '解析RTF格式...');
          metadata = await _extractRtfMetadata(bytes, fileName);
          break;
        default:
          progressCallback?.call(0.5, '提取基本信息...');
          metadata = _extractBasicMetadata(bytes, fileName);
      }

      progressCallback?.call(1.0, '元数据提取完成');
      return metadata;
    } catch (e) {
      debugPrint('❌ 元数据提取失败: $e');
      progressCallback?.call(0.8, '使用默认信息...');
      return _extractBasicMetadata(bytes, fileName);
    }
  }

  /// Extract comprehensive EPUB metadata
  Future<EnhancedBookMetadata> _extractEpubMetadata(
    Uint8List bytes,
    String fileName,
  ) async {
    try {
      EpubBook epubBook;
      try {
        epubBook = await compute(parseEpubBookInIsolate, bytes);
      } catch (e) {
        // isolate 解析或结果传输失败时回退主线程解析
        debugPrint('⚠️ EPUB isolate 解析失败，回退主线程: $e');
        epubBook = await EpubReader.readBook(bytes);
      }

      // Extract basic metadata first (needed for cover fetching)
      final title = epubBook.Title?.isNotEmpty == true
          ? epubBook.Title!
          : fileName.replaceAll(RegExp(r'\.(epub)$'), '');
      final author =
          epubBook.Author?.isNotEmpty == true ? epubBook.Author! : 'Unknown';

      // 🖼️ 提取图片（恢复为同步，确保图片可用）
      // 注意：虽然是同步，但图片数量通常不多（<10张），影响很小
      final tempBookId = DateTime.now().millisecondsSinceEpoch.toString();
      debugPrint('🖼️ 开始提取EPUB图片...');
      Map<String, String> imageMap = {};
      try {
        imageMap = await _imageExtractor.extractImagesFromEpubBook(
          epubBook,
          tempBookId,
        );
        debugPrint('✅ 图片提取完成: ${imageMap.length} 张');
      } catch (e) {
        debugPrint('⚠️ 图片提取失败: $e，继续导入流程');
      }

      // Extract ISBN early (useful for cover fetching)
      String? isbn;
      if (epubBook.Schema?.Package?.Metadata?.Identifiers?.isNotEmpty == true) {
        for (final identifier
            in epubBook.Schema!.Package!.Metadata!.Identifiers!) {
          if (identifier.Scheme?.toLowerCase().contains('isbn') == true) {
            isbn = identifier.Identifier;
            break;
          }
        }
      }

      // Extract cover image with enhanced logic
      Uint8List? coverImage;
      try {
        // First try to extract from EPUB file
        coverImage = await _extractEpubCover(epubBook);

        // If no embedded cover, try fetching from network
        if (coverImage == null) {
          debugPrint('🌐 EPUB无内置封面，尝试从网络获取: $title');
          coverImage = await _coverFetcher.fetchCoverQuick(
            title: title,
            author: author,
            isbn: isbn,
          );

          if (coverImage != null) {
            debugPrint('✅ 从网络成功获取EPUB封面');
          } else {
            debugPrint('📝 网络未找到封面，生成EPUB默认封面');
            coverImage = await CoverGenerator.generateTextCover(
              title: title,
              author: author,
              format: 'EPUB',
            );
          }
        } else {
          debugPrint('✅ 成功从EPUB文件提取内置封面');
        }
      } catch (e) {
        debugPrint('⚠️ 封面处理失败: $e，生成默认封面');
        try {
          coverImage = await CoverGenerator.generateTextCover(
            title: title,
            author: author,
            format: 'EPUB',
          );
        } catch (genError) {
          debugPrint('❌ EPUB封面生成失败: $genError');
        }
      }

      // Try to extract description from available fields
      String? description;
      // EPUB standard doesn't have a direct Description property, so try alternative methods
      final allContent = await _getAllEpubContent(epubBook);
      if (allContent.isNotEmpty && allContent.length > 200) {
        // Take first 500 characters as description
        description =
            allContent.substring(0, allContent.length.clamp(0, 500)).trim();
        if (description.length >= 500) {
          description = '${description.substring(0, 497)}...';
        }
      }

      // Extract language - simple approach since Language property may not exist
      String? language;
      if (epubBook.Schema?.Package?.Metadata?.Languages?.isNotEmpty == true) {
        language = epubBook.Schema!.Package!.Metadata!.Languages!.first;
      }

      // Extract publisher - Publishers may be a list of strings
      String? publisher;
      if (epubBook.Schema?.Package?.Metadata?.Publishers?.isNotEmpty == true) {
        publisher = epubBook.Schema!.Package!.Metadata!.Publishers!.first;
      }

      // Extract publication date
      String? publishDate;
      if (epubBook.Schema?.Package?.Metadata?.Dates?.isNotEmpty == true) {
        publishDate = epubBook.Schema!.Package!.Metadata!.Dates!.first.Date;
      }

      // Extract subject tags - Subjects is likely a list of strings
      List<String>? tags;
      if (epubBook.Schema?.Package?.Metadata?.Subjects?.isNotEmpty == true) {
        tags = epubBook.Schema!.Package!.Metadata!.Subjects!
            .where((subject) => subject.isNotEmpty)
            .toList();
      }

      // Estimate pages based on content length
      final estimatedPages = (allContent.length / 1500).ceil().clamp(1, 9999);

      return EnhancedBookMetadata(
        title: title,
        author: author,
        description: description,
        language: language,
        publisher: publisher,
        publishDate: publishDate,
        isbn: isbn,
        coverImage: coverImage,
        estimatedPages: estimatedPages,
        tags: tags,
        additionalInfo: {
          'format': 'EPUB',
          'hasImages': epubBook.Content?.Images?.isNotEmpty == true,
          'chapterCount': epubBook.Chapters?.length ?? 0,
          'imageMap': imageMap, // 🖼️ 添加图片映射，用于阅读器渲染
        },
      );
    } catch (e) {
      debugPrint('EPUB metadata extraction failed: $e');
      return _extractBasicMetadata(bytes, fileName);
    }
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

      // 提取PDF封面（先尝试从PDF第一页，再尝试网络）
      Uint8List? coverImage;
      try {
        // Try extracting from PDF first page
        coverImage = await _extractPdfCover(bytes);

        // If no PDF cover, try network
        if (coverImage == null) {
          debugPrint('🌐 PDF无封面，尝试从网络获取: $title');
          coverImage = await _coverFetcher.fetchCoverQuick(
            title: title,
            author: author,
          );

          if (coverImage != null) {
            debugPrint('✅ 从网络成功获取PDF封面');
          } else {
            debugPrint('📝 网络未找到封面，生成PDF默认封面');
            coverImage = await CoverGenerator.generateTextCover(
              title: title,
              author: author,
              format: 'PDF',
            );
          }
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
        final lines =
            content.split('\n').where((e) => e.trim().isNotEmpty).toList();
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

      // 尝试从网络获取封面，失败则生成默认封面
      Uint8List? coverImage;
      try {
        debugPrint('🌐 尝试从网络获取书籍封面: ${simpleMetadata.title}');
        coverImage = await _coverFetcher.fetchCoverQuick(
          title: simpleMetadata.title,
          author: simpleMetadata.author,
        );

        if (coverImage != null) {
          debugPrint('✅ 从网络成功获取封面');
        } else {
          debugPrint('📝 网络未找到封面，生成默认封面');
          coverImage = await CoverGenerator.generateTextCover(
            title: simpleMetadata.title,
            author: simpleMetadata.author,
            format: 'TXT',
          );
          debugPrint('✅ TXT默认封面生成成功');
        }
      } catch (e) {
        debugPrint('封面获取失败，生成默认封面: $e');
        try {
          coverImage = await CoverGenerator.generateTextCover(
            title: simpleMetadata.title,
            author: simpleMetadata.author,
            format: 'TXT',
          );
        } catch (e2) {
          debugPrint('默认封面生成也失败: $e2');
        }
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
        additionalInfo: {
          'format': 'TXT',
          'fileSize': bytes.length,
        },
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

      // 对于大文件，使用isolate处理
      SimpleMetadata simpleMetadata;
      if (bytes.length > 5 * 1024 * 1024) {
        // 大于5MB，使用isolate
        debugPrint('使用isolate处理大MOBI文件: ${bytes.length / 1024 / 1024} MB');
        const headSliceBytes = 500 * 1024;
        simpleMetadata = await compute(
          extractMobiMetadataInIsolate,
          MetadataExtractionParams(
            bytes: bytes.sublist(0, headSliceBytes),
            fileName: fileName,
            extension: fileName.split('.').last.toLowerCase(),
            totalByteLength: bytes.length,
          ),
        );
      } else {
        // 小文件在主线程处理
        String title = fileName.replaceAll(
          RegExp(r'\.(mobi|azw|azw3)$', caseSensitive: false),
          '',
        );
        int estimatedPages = 100;

        if (bytes.length >= 68) {
          final identifier = String.fromCharCodes(bytes.sublist(60, 68));
          debugPrint('文件标识: $identifier');

          if (identifier.contains('BOOKMOBI') ||
              identifier.contains('TEXTREAD')) {
            debugPrint('✅ 检测到有效的MOBI文件');

            try {
              final content = _extractMobiText(bytes);
              if (content.isNotEmpty) {
                final lines = content.split('\n').take(100).toList();
                for (var line in lines) {
                  final trimmed = line.trim();
                  if (trimmed.isNotEmpty &&
                      trimmed.length > 3 &&
                      trimmed.length < 100) {
                    if (!trimmed.contains('Chapter') &&
                        !trimmed.contains('第') &&
                        !trimmed.contains('章') &&
                        !trimmed.contains('CHAPTER')) {
                      title = trimmed;
                      debugPrint('提取到标题: $title');
                      break;
                    }
                  }
                }
                estimatedPages = (content.length / 1500).ceil().clamp(10, 9999);
                debugPrint('内容长度: ${content.length}, 预估页数: $estimatedPages');
              }
            } catch (e) {
              debugPrint('提取MOBI文本内容失败: $e');
            }
          }
        }

        if (estimatedPages == 100) {
          estimatedPages = (bytes.length / 3000).ceil().clamp(50, 1000);
          debugPrint('基于文件大小估算页数: $estimatedPages');
        }

        simpleMetadata = SimpleMetadata(
          title: title,
          author: 'Unknown',
          estimatedPages: estimatedPages,
        );
      }

      // 尝试从网络获取封面，失败则生成MOBI格式的默认封面
      Uint8List? coverImage;
      try {
        debugPrint('🌐 尝试从网络获取书籍封面: ${simpleMetadata.title}');
        coverImage = await _coverFetcher.fetchCoverQuick(
          title: simpleMetadata.title,
          author: simpleMetadata.author,
        );

        if (coverImage != null) {
          debugPrint('✅ 从网络成功获取MOBI封面');
        } else {
          debugPrint('📝 网络未找到封面，生成MOBI默认封面');
          coverImage = await CoverGenerator.generateTextCover(
            title: simpleMetadata.title,
            author: simpleMetadata.author,
            format: 'MOBI',
          );
        }
      } catch (e) {
        debugPrint('⚠️ 网络获取封面失败: $e，生成默认封面');
        try {
          coverImage = await CoverGenerator.generateTextCover(
            title: simpleMetadata.title,
            author: simpleMetadata.author,
            format: 'MOBI',
          );
        } catch (genError) {
          debugPrint('❌ MOBI封面生成失败: $genError');
        }
      }

      debugPrint('✅ MOBI元数据提取完成:');
      debugPrint('   标题: ${simpleMetadata.title}');
      debugPrint('   作者: ${simpleMetadata.author}');
      debugPrint('   页数: ${simpleMetadata.estimatedPages}');

      return EnhancedBookMetadata(
        title: simpleMetadata.title,
        author: simpleMetadata.author,
        description: simpleMetadata.description,
        language: simpleMetadata.language,
        publisher: null,
        publishDate: null,
        isbn: null,
        coverImage: coverImage,
        estimatedPages: simpleMetadata.estimatedPages,
        tags: null,
        additionalInfo: {
          'format': 'MOBI/AZW',
          'fileSize': bytes.length,
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

  /// Extract Comic Book (CBZ/CBR) metadata
  Future<EnhancedBookMetadata> _extractComicMetadata(
    Uint8List bytes,
    String fileName,
  ) async {
    try {
      // CBZ files are ZIP archives containing images
      // CBR files are RAR archives containing images
      final extension = fileName.split('.').last.toLowerCase();
      final title = fileName.replaceAll(RegExp(r'\.(cbz|cbr)$'), '');

      // For comic books, we can extract some basic info
      String author = 'Unknown';

      // Try to extract info from filename patterns
      final seriesMatch = RegExp(r'^(.+?)\s*#?\d+').firstMatch(title);
      if (seriesMatch != null) {
        author = 'Series: ${seriesMatch.group(1)}';
      }

      // Estimate pages based on typical comic book length
      final estimatedPages =
          extension == 'cbz' ? 25 : 30; // Comics typically 20-40 pages

      return EnhancedBookMetadata(
        title: title,
        author: author,
        description: 'Comic book in ${extension.toUpperCase()} format',
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

      final documentsDir = await getApplicationDocumentsDirectory();
      final coversDir = Directory(join(documentsDir.path, 'covers'));
      if (!await coversDir.exists()) {
        await coversDir.create(recursive: true);
      }

      final bookName = bookFileName.replaceAll(RegExp(r'\.[^.]+$'), '');
      // 文件名加入完整文件名（含扩展名）的哈希后缀，
      // 避免"同名不同格式"的书封面互相覆盖
      final nameHash =
          md5.convert(utf8.encode(bookFileName)).toString().substring(0, 8);
      final coverPath =
          join(coversDir.path, '${bookName}_${nameHash}_cover.jpg');
      final coverFile = File(coverPath);

      await coverFile.writeAsBytes(imageBytes);
      debugPrint('Cover image saved to: $coverPath');

      return coverPath;
    } catch (e) {
      debugPrint('Failed to save cover image: $e');
      return null;
    }
  }

  // Recursively get all EPUB chapter content
  Future<String> _getAllEpubContent(EpubBook book) async {
    final buffer = StringBuffer();
    // Using book.Content is often more reliable for getting all text content
    if (book.Content != null) {
      // Iterate over all HTML files
      final htmlFiles = book.Content!.Html;
      if (htmlFiles != null) {
        for (var entry in htmlFiles.entries) {
          final htmlContent = entry.value.Content;
          if (htmlContent != null && htmlContent.isNotEmpty) {
            buffer.writeln(_stripHtml(htmlContent));
          }
        }
      }
    }
    return buffer.toString();
  }

  String _stripHtml(String html) {
    return html
        .replaceAll(RegExp(r'<[^>]*>'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// 提取MOBI文件的文本内容（支持多种字符集）
  String _extractMobiText(Uint8List bytes) {
    try {
      // MOBI文件通常包含HTML或纯文本内容
      String content = '';

      // 尝试UTF-8解码
      try {
        content = utf8.decode(bytes, allowMalformed: true);
      } catch (e) {
        // 如果UTF-8失败，尝试Latin1
        content = latin1.decode(bytes);
      }

      // 移除HTML标签
      content = content.replaceAll(RegExp(r'<[^>]*>'), ' ');

      // 移除多余的空白字符
      content = content.replaceAll(RegExp(r'\s+'), ' ').trim();

      // 移除控制字符，但保留常见的Unicode字符
      final cleanContent = content.split('').where((char) {
        final code = char.codeUnitAt(0);
        return (code >= 32 && code <= 126) || // ASCII可打印字符
            (code >= 0x4e00 && code <= 0x9fff) || // 中日韩统一表意文字
            (code >= 0x3000 && code <= 0x303f) || // CJK 符号和标点
            (code >= 0xff00 && code <= 0xffef) || // 全角ASCII、半角片假名和韩文
            (code >= 0x3040 && code <= 0x309f) || // 平假名
            (code >= 0x30a0 && code <= 0x30ff) || // 片假名
            (code >= 0xac00 && code <= 0xd7af) || // 韩文音节
            (code >= 0x0400 && code <= 0x04ff) || // 西里尔字母
            (code >= 0x00c0 && code <= 0x00ff) || // 拉丁扩展-A
            char == '\n' ||
            char == '\r' ||
            char == '\t';
      }).join();

      return cleanContent;
    } catch (e) {
      debugPrint('MOBI文本提取失败: $e');
      return '';
    }
  }

  String _stripXmlTags(String xml) {
    return xml
        .replaceAll(RegExp(r'<[^>]*>'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'&[a-zA-Z0-9#]+;'), ' ') // Remove XML entities
        .trim();
  }

  /// 增强的EPUB封面提取
  Future<Uint8List?> _extractEpubCover(EpubBook epubBook) async {
    try {
      // 方法1: 直接从CoverImage属性获取
      if (epubBook.CoverImage != null) {
        // 如果CoverImage是Uint8List类型
        if (epubBook.CoverImage is Uint8List) {
          return epubBook.CoverImage as Uint8List;
        }
        // 如果有其他类型，尝试转换
      }

      // 方法2: 从Content.Images中查找封面
      if (epubBook.Content?.Images != null &&
          epubBook.Content!.Images!.isNotEmpty) {
        // 优先查找名称包含"cover"的图片
        for (final entry in epubBook.Content!.Images!.entries) {
          final fileName = entry.key.toLowerCase();
          if (fileName.contains('cover') || fileName.contains('front')) {
            final imageFile = entry.value;
            if (imageFile.Content != null && imageFile.Content!.isNotEmpty) {
              final imageBytes = Uint8List.fromList(imageFile.Content!);
              if (_isValidImageFormat(imageBytes)) {
                return imageBytes;
              }
            }
          }
        }

        // 如果没找到，返回第一个有效的图片
        for (final entry in epubBook.Content!.Images!.entries) {
          final imageFile = entry.value;
          if (imageFile.Content != null && imageFile.Content!.isNotEmpty) {
            final imageBytes = Uint8List.fromList(imageFile.Content!);
            if (_isValidImageFormat(imageBytes)) {
              return imageBytes;
            }
          }
        }
      }

      // 方法3: 从manifest中查找封面引用
      if (epubBook.Schema?.Package?.Manifest?.Items != null) {
        for (final item in epubBook.Schema!.Package!.Manifest!.Items!) {
          // 查找cover相关的item
          if (item.Id?.toLowerCase().contains('cover') == true ||
              item.Href?.toLowerCase().contains('cover') == true ||
              item.Properties?.contains('cover-image') == true) {
            // 尝试从Images中获取对应的内容
            if (epubBook.Content?.Images != null && item.Href != null) {
              final imageFile = epubBook.Content!.Images![item.Href!];
              if (imageFile?.Content != null &&
                  imageFile!.Content!.isNotEmpty) {
                final imageBytes = Uint8List.fromList(imageFile.Content!);
                if (_isValidImageFormat(imageBytes)) {
                  return imageBytes;
                }
              }
            }
          }
        }
      }

      debugPrint('No cover image found in EPUB');
      return null;
    } catch (e) {
      debugPrint('Error extracting EPUB cover: $e');
      return null;
    }
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
