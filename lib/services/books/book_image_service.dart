// 文件说明：书籍图片缓存服务，负责图片落盘、去重和显示元数据管理。
// 技术要点：服务层、Path、Crypto 哈希、文件系统、渲染层、JSON。

import 'dart:io';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'package:crypto/crypto.dart';
import 'dart:convert';

/// 书籍图片管理服务
/// 负责EPUB等格式中图片的提取、缓存和加载
class BookImageManager {
  // 内存缓存 - 使用LRU策略
  final Map<String, ui.Image> _memoryCache = {};
  final List<String> _cacheKeys = [];

  // 图片尺寸缓存
  final Map<String, Size> _sizeCache = {};

  // 缓存目录
  late String _cacheDir;

  // 最大内存缓存数量
  static const int maxMemoryCacheSize = 50;

  // 单例模式
  static final BookImageManager _instance = BookImageManager._internal();
  factory BookImageManager() => _instance;
  BookImageManager._internal();

  /// 初始化缓存目录
  ///
  /// 参数：
  /// - [appDocumentsPath] 应用文档目录路径
  Future<void> initialize(String appDocumentsPath) async {
    _cacheDir = path.join(appDocumentsPath, 'book_images');
    final dir = Directory(_cacheDir);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    debugPrint('📁 图片缓存目录已初始化: $_cacheDir');
  }

  /// 保存图片数据到磁盘
  ///
  /// 参数：
  /// - [imageKey] 图片唯一标识
  /// - [imageData] 图片字节数据
  ///
  /// 返回：缓存文件路径
  Future<String> saveImage(String imageKey, Uint8List imageData) async {
    final fileName = _generateFileName(imageKey);
    final filePath = path.join(_cacheDir, fileName);
    final file = File(filePath);

    debugPrint('💾 准备保存图片:');
    debugPrint('   imageKey: $imageKey');
    debugPrint('   fileName: $fileName');
    debugPrint('   完整路径: $filePath');
    debugPrint('   数据大小: ${imageData.length} 字节');
    debugPrint('   缓存目录: $_cacheDir');

    await file.writeAsBytes(imageData);

    // 验证文件是否真的被保存
    final exists = await file.exists();
    final savedSize = exists ? await file.length() : 0;

    if (exists) {
      debugPrint('✅ 图片已保存: $imageKey -> $fileName');
      debugPrint('   文件大小: $savedSize 字节');
      debugPrint('   文件存在: $exists');
    } else {
      debugPrint('❌ 图片保存失败: 文件不存在！');
    }

    return filePath;
  }

  /// 批量保存图片
  ///
  /// 参数：
  /// - [images] 图片数据映射 {key: bytes}
  ///
  /// 返回：文件路径映射 {key: path}
  Future<Map<String, String>> saveImages(Map<String, Uint8List> images) async {
    final result = <String, String>{};

    for (var entry in images.entries) {
      try {
        final filePath = await saveImage(entry.key, entry.value);
        result[entry.key] = filePath;
      } catch (e) {
        debugPrint('❌ 保存图片失败: ${entry.key}, 错误: $e');
      }
    }

    debugPrint('✅ 批量保存完成: ${result.length}/${images.length} 张图片');
    return result;
  }

  /// 加载图片
  ///
  /// 参数：
  /// - [imagePath] 图片文件路径
  ///
  /// 返回：加载的图片对象，失败返回null
  Future<ui.Image?> loadImage(String imagePath) async {
    // 1. 检查内存缓存
    if (_memoryCache.containsKey(imagePath)) {
      debugPrint('📦 从内存缓存加载: ${path.basename(imagePath)}');
      return _memoryCache[imagePath];
    }

    try {
      // 2. 从文件加载
      final file = File(imagePath);
      if (!await file.exists()) {
        debugPrint('⚠️ 图片文件不存在: $imagePath');
        return null;
      }

      final bytes = await file.readAsBytes();
      final image = await _decodeImage(bytes);

      // 3. 添加到内存缓存
      _addToMemoryCache(imagePath, image);

      debugPrint(
          '✅ 图片加载成功: ${path.basename(imagePath)} (${image.width}x${image.height})');
      return image;
    } catch (e) {
      debugPrint('❌ 加载图片失败: $imagePath, 错误: $e');
      return null;
    }
  }

  /// 获取图片尺寸（不加载完整图片到内存）
  ///
  /// 参数：
  /// - [imagePath] 图片文件路径
  ///
  /// 返回：图片尺寸，失败返回null
  Future<Size?> getImageSize(String imagePath) async {
    // 检查缓存
    if (_sizeCache.containsKey(imagePath)) {
      return _sizeCache[imagePath];
    }

    try {
      final file = File(imagePath);
      if (!await file.exists()) {
        return null;
      }

      final bytes = await file.readAsBytes();
      final image = await _decodeImage(bytes);
      final size = Size(image.width.toDouble(), image.height.toDouble());

      _sizeCache[imagePath] = size;
      image.dispose(); // 立即释放，我们只需要尺寸

      return size;
    } catch (e) {
      debugPrint('❌ 获取图片尺寸失败: $imagePath, 错误: $e');
      return null;
    }
  }

  /// 预加载图片列表
  ///
  /// 参数：
  /// - [imagePaths] 图片路径列表
  Future<void> preloadImages(List<String> imagePaths) async {
    debugPrint('🔄 开始预加载 ${imagePaths.length} 张图片...');

    int successCount = 0;
    for (var imagePath in imagePaths) {
      if (!_memoryCache.containsKey(imagePath)) {
        final image = await loadImage(imagePath);
        if (image != null) {
          successCount++;
        }
      }
    }

    debugPrint('✅ 预加载完成: $successCount/${imagePaths.length} 张图片');
  }

  /// 清理内存缓存
  void clearMemoryCache() {
    for (var image in _memoryCache.values) {
      image.dispose();
    }
    _memoryCache.clear();
    _cacheKeys.clear();
    _sizeCache.clear();
    debugPrint('🗑️ 内存缓存已清理');
  }

  /// 清理磁盘缓存
  Future<void> clearDiskCache() async {
    final dir = Directory(_cacheDir);
    if (await dir.exists()) {
      await dir.delete(recursive: true);
      await dir.create();
      debugPrint('🗑️ 磁盘缓存已清理');
    }
  }

  /// 获取磁盘缓存大小（字节）
  Future<int> getCacheSize() async {
    var totalSize = 0;
    final dir = Directory(_cacheDir);

    if (await dir.exists()) {
      await for (var entity in dir.list(recursive: true)) {
        if (entity is File) {
          totalSize += await entity.length();
        }
      }
    }

    return totalSize;
  }

  /// 获取缓存统计信息
  Future<Map<String, dynamic>> getCacheStats() async {
    final diskSize = await getCacheSize();
    final diskSizeMB = (diskSize / 1024 / 1024).toStringAsFixed(2);

    return {
      'memory_cached': _memoryCache.length,
      'disk_cached': await _getDiskFileCount(),
      'disk_size_mb': diskSizeMB,
      'size_cache': _sizeCache.length,
    };
  }

  // ========== 私有方法 ==========

  /// 解码图片
  Future<ui.Image> _decodeImage(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    return frame.image;
  }

  /// 添加到内存缓存（LRU策略）
  void _addToMemoryCache(String key, ui.Image image) {
    // 如果已经存在，先移除
    if (_memoryCache.containsKey(key)) {
      _cacheKeys.remove(key);
    }

    // 如果缓存已满，移除最旧的
    if (_memoryCache.length >= maxMemoryCacheSize) {
      final oldestKey = _cacheKeys.removeAt(0);
      _memoryCache[oldestKey]?.dispose();
      _memoryCache.remove(oldestKey);
    }

    // 添加新缓存
    _memoryCache[key] = image;
    _cacheKeys.add(key);
  }

  /// 生成文件名（使用MD5避免特殊字符）
  String _generateFileName(String key) {
    final hash = md5.convert(utf8.encode(key)).toString();
    // 尝试保留原始扩展名
    final extension = path.extension(key);
    return extension.isNotEmpty ? '$hash$extension' : hash;
  }

  /// 获取磁盘文件数量
  Future<int> _getDiskFileCount() async {
    var count = 0;
    final dir = Directory(_cacheDir);

    if (await dir.exists()) {
      await for (var entity in dir.list()) {
        if (entity is File) {
          count++;
        }
      }
    }

    return count;
  }

  /// 释放资源
  void dispose() {
    clearMemoryCache();
  }
}

/// 图片显示样式
enum ImageDisplayStyle {
  /// 自动缩放（保持比例）
  auto,

  /// 填充宽度
  fullWidth,

  /// 独占一页
  fullPage,

  /// 嵌入文字中
  inline,
}

/// 图片信息
class BookImage {
  final String key; // 唯一标识
  final String filePath; // 文件路径
  final Size? size; // 尺寸
  final ui.Image? image; // 加载的图片对象

  const BookImage({
    required this.key,
    required this.filePath,
    this.size,
    this.image,
  });

  /// 是否已加载
  bool get isLoaded => image != null;

  /// 创建副本
  BookImage copyWith({
    String? key,
    String? filePath,
    Size? size,
    ui.Image? image,
  }) {
    return BookImage(
      key: key ?? this.key,
      filePath: filePath ?? this.filePath,
      size: size ?? this.size,
      image: image ?? this.image,
    );
  }
}
