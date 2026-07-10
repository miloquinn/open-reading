// 文件说明：EPUB 图片提取服务，把压缩包中的图片抽取到本地缓存目录。
// 技术要点：服务层、Archive ZIP、EPUBX、Path、文件系统、Flutter。

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:archive/archive.dart';
import 'package:epubx/epubx.dart';
import 'package:path/path.dart' as path;
import 'package:xxread/services/books/book_image_service.dart';

/// EPUB图片提取器
/// 从EPUB文件中提取所有图片并保存到缓存
class EpubImageExtractor {
  final BookImageManager imageManager;

  EpubImageExtractor({BookImageManager? imageManager})
      : imageManager = imageManager ?? BookImageManager();

  /// 从EPUB文件提取所有图片
  ///
  /// 参数：
  /// - [epubFilePath] EPUB文件路径
  /// - [bookId] 书籍ID（用于组织图片）
  ///
  /// 返回：图片映射 {图片key: 文件路径}
  Future<Map<String, String>> extractImages(
    String epubFilePath,
    String bookId,
  ) async {
    debugPrint('🖼️ 开始提取EPUB图片: $epubFilePath');

    try {
      // 读取EPUB文件
      final bytes = await File(epubFilePath).readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);

      final images = <String, Uint8List>{};

      // 遍历所有文件
      for (var file in archive.files) {
        if (file.isFile && _isImageFile(file.name)) {
          final imageData = file.content as List<int>;
          final imageBytes = Uint8List.fromList(imageData);

          // 使用文件名作为key
          final imageKey = '${bookId}_${path.basename(file.name)}';
          images[imageKey] = imageBytes;

          debugPrint('  ✓ 找到图片: ${file.name} (${imageBytes.length} 字节)');
        }
      }

      if (images.isEmpty) {
        debugPrint('⚠️ 未找到图片');
        return {};
      }

      // 批量保存图片
      final savedPaths = await imageManager.saveImages(images);

      debugPrint('✅ 提取完成: ${savedPaths.length} 张图片');
      return savedPaths;
    } catch (e) {
      debugPrint('❌ 提取图片失败: $e');
      return {};
    }
  }

  /// 从EpubBook对象提取图片
  ///
  /// 参数：
  /// - [epubBook] 已解析的EpubBook对象
  /// - [bookId] 书籍ID
  ///
  /// 返回：图片映射 {图片key: 文件路径}
  Future<Map<String, String>> extractImagesFromEpubBook(
    EpubBook epubBook,
    String bookId,
  ) async {
    debugPrint('🖼️ 从EpubBook提取图片...');

    try {
      final images = <String, Uint8List>{};

      // 从Content中提取图片
      if (epubBook.Content?.Images != null) {
        for (var entry in epubBook.Content!.Images!.entries) {
          final imageKey = '${bookId}_${path.basename(entry.key)}';
          images[imageKey] = Uint8List.fromList(entry.value.Content ?? []);

          debugPrint('  ✓ 找到图片: ${entry.key} (${images[imageKey]!.length} 字节)');
        }
      }

      if (images.isEmpty) {
        debugPrint('⚠️ 未找到图片');
        return {};
      }

      // 批量保存
      final savedPaths = await imageManager.saveImages(images);

      debugPrint('✅ 提取完成: ${savedPaths.length} 张图片');
      return savedPaths;
    } catch (e) {
      debugPrint('❌ 提取图片失败: $e');
      return {};
    }
  }

  /// 提取章节中的图片引用
  ///
  /// 参数：
  /// - [htmlContent] 章节HTML内容
  /// - [allImages] 所有已提取的图片映射
  /// - [bookId] 书籍ID
  ///
  /// 返回：章节图片映射 {占位符: 文件路径}
  Map<String, String> extractChapterImageReferences(
    String htmlContent,
    Map<String, String> allImages,
    String bookId,
  ) {
    final chapterImages = <String, String>{};

    // 匹配img标签的src属性
    final imgPattern = RegExp(r'<img[^>]+src="([^"]+)"', caseSensitive: false);

    for (var match in imgPattern.allMatches(htmlContent)) {
      final src = match.group(1);
      if (src == null) continue;

      // 提取文件名
      final fileName = path.basename(Uri.decodeFull(src));
      final imageKey = '${bookId}_$fileName';

      // 查找对应的图片路径
      if (allImages.containsKey(imageKey)) {
        chapterImages[fileName] = allImages[imageKey]!;
        debugPrint('  📎 章节引用图片: $fileName');
      }
    }

    return chapterImages;
  }

  /// 将HTML内容中的图片标签转换为占位符
  ///
  /// 参数：
  /// - [htmlContent] HTML内容
  ///
  /// 返回：转换后的文本（图片用{{img:xxx}}占位符替换）
  String convertImagesToPlaceholders(String htmlContent) {
    // 替换img标签为占位符
    final imgPattern =
        RegExp(r'<img[^>]+src="([^"]+)"[^>]*>', caseSensitive: false);

    return htmlContent.replaceAllMapped(imgPattern, (match) {
      final src = match.group(1);
      if (src == null) return '';

      final fileName = path.basename(Uri.decodeFull(src));
      return '{{img:$fileName}}';
    });
  }

  /// 判断文件是否为图片
  bool _isImageFile(String fileName) {
    final extension = path.extension(fileName).toLowerCase();
    return ['.jpg', '.jpeg', '.png', '.gif', '.webp', '.bmp', '.svg']
        .contains(extension);
  }

  /// 获取图片统计信息
  Future<Map<String, dynamic>> getImageStats(String epubFilePath) async {
    try {
      final bytes = await File(epubFilePath).readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);

      var imageCount = 0;
      var totalSize = 0;
      final imageTypes = <String, int>{};

      for (var file in archive.files) {
        if (file.isFile && _isImageFile(file.name)) {
          imageCount++;
          totalSize += file.size;

          final ext = path.extension(file.name).toLowerCase();
          imageTypes[ext] = (imageTypes[ext] ?? 0) + 1;
        }
      }

      return {
        'count': imageCount,
        'totalSize': totalSize,
        'totalSizeMB': (totalSize / 1024 / 1024).toStringAsFixed(2),
        'types': imageTypes,
      };
    } catch (e) {
      debugPrint('❌ 获取图片统计失败: $e');
      return {
        'count': 0,
        'totalSize': 0,
        'totalSizeMB': '0.00',
        'types': {},
      };
    }
  }
}

/// 图片提取结果
class ImageExtractionResult {
  final Map<String, String> images; // {imageKey: filePath}
  final int totalCount; // 总数
  final int extractedCount; // 成功提取数量
  final List<String> errors; // 错误列表

  const ImageExtractionResult({
    required this.images,
    required this.totalCount,
    required this.extractedCount,
    this.errors = const [],
  });

  bool get hasErrors => errors.isNotEmpty;
  bool get isSuccess => extractedCount > 0;
  double get successRate => totalCount > 0 ? extractedCount / totalCount : 0;
}
