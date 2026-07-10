// 文件说明：EPUB 图片路径映射服务，维护原始资源路径到本地缓存路径的映射。
// 技术要点：服务层、Path Provider、Path、文件系统、JSON、Flutter。

import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

/// 书籍图片映射管理服务
/// 负责保存和加载EPUB等格式中图片文件名到缓存路径的映射关系
class BookImageMapService {
  // 单例模式
  static final BookImageMapService _instance = BookImageMapService._internal();
  factory BookImageMapService() => _instance;
  BookImageMapService._internal();

  /// 保存图片映射到JSON文件
  ///
  /// 参数：
  /// - [bookId] 书籍ID
  /// - [imageMap] 图片映射 {imageKey: cachePath}
  ///
  /// 返回：是否保存成功
  Future<bool> saveImageMap(int bookId, Map<String, String> imageMap) async {
    if (imageMap.isEmpty) {
      debugPrint('⚠️ 图片映射为空，跳过保存');
      return false;
    }

    try {
      final appDir = await getApplicationDocumentsDirectory();
      final imageDir = Directory(path.join(appDir.path, 'book_images'));

      // 确保目录存在
      if (!await imageDir.exists()) {
        await imageDir.create(recursive: true);
      }

      // 保存到JSON文件
      final mapFile = File(path.join(imageDir.path, 'image_map_$bookId.json'));
      await mapFile.writeAsString(jsonEncode(imageMap));

      debugPrint('✅ 图片映射已保存: $bookId (${imageMap.length} 张图片)');
      debugPrint('   文件: ${mapFile.path}');
      return true;
    } catch (e) {
      debugPrint('❌ 保存图片映射失败: $e');
      return false;
    }
  }

  /// 加载图片映射
  ///
  /// 参数：
  /// - [bookId] 书籍ID
  ///
  /// 返回：图片映射 {imageKey: cachePath}，失败返回空Map
  Future<Map<String, String>> loadImageMap(int bookId) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final mapFile = File(
        path.join(appDir.path, 'book_images', 'image_map_$bookId.json'),
      );

      if (!await mapFile.exists()) {
        debugPrint('⚠️ 图片映射文件不存在: $bookId');
        return {};
      }

      final jsonStr = await mapFile.readAsString();
      final decoded = jsonDecode(jsonStr);
      final map = Map<String, String>.from(decoded);

      debugPrint('✅ 图片映射已加载: $bookId (${map.length} 张图片)');
      return map;
    } catch (e) {
      debugPrint('❌ 加载图片映射失败: $e');
      return {};
    }
  }

  /// 删除图片映射文件
  ///
  /// 参数：
  /// - [bookId] 书籍ID
  Future<void> deleteImageMap(int bookId) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final mapFile = File(
        path.join(appDir.path, 'book_images', 'image_map_$bookId.json'),
      );

      if (await mapFile.exists()) {
        await mapFile.delete();
        debugPrint('🗑️ 图片映射已删除: $bookId');
      }
    } catch (e) {
      debugPrint('❌ 删除图片映射失败: $e');
    }
  }

  /// 获取所有图片映射文件
  Future<List<String>> getAllImageMapFiles() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final imageDir = Directory(path.join(appDir.path, 'book_images'));

      if (!await imageDir.exists()) {
        return [];
      }

      final files = <String>[];
      await for (var entity in imageDir.list()) {
        if (entity is File && entity.path.endsWith('.json')) {
          files.add(entity.path);
        }
      }

      return files;
    } catch (e) {
      debugPrint('❌ 获取图片映射文件列表失败: $e');
      return [];
    }
  }

  /// 清理所有图片映射文件
  Future<void> clearAllImageMaps() async {
    try {
      final files = await getAllImageMapFiles();
      for (var filePath in files) {
        await File(filePath).delete();
      }
      debugPrint('🗑️ 已清理所有图片映射文件: ${files.length} 个');
    } catch (e) {
      debugPrint('❌ 清理图片映射失败: $e');
    }
  }
}
