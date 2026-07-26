// 文件说明：整页图片阅读器（漫画/PDF 共用）的专属设置：阅读方向与页面背景。
// 技术要点：阅读方向按书持久化（日漫从右到左与普通 PDF 从左到右并存），
// 页面背景全局一份；SharedPreferences 存储，解码失败回退默认值。

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 翻页方向：[ltr] 常规从左到右，[rtl] 日漫从右到左。
enum ImageReaderDirection {
  ltr,
  rtl;

  static ImageReaderDirection fromName(String? name) =>
      name == rtl.name ? rtl : ltr;
}

/// 页面外围（信箱区）背景色；页面本体仍由图片内容决定。
enum ImageReaderBackground {
  black(Color(0xFF000000)),
  gray(Color(0xFF424242)),
  white(Color(0xFFFFFFFF));

  const ImageReaderBackground(this.color);

  final Color color;

  /// 背景为浅色时，加载指示与破图占位需要换成深色前景。
  bool get isLight => this == white;

  static ImageReaderBackground fromName(String? name) {
    for (final value in values) {
      if (value.name == name) return value;
    }
    return black;
  }
}

/// 图片阅读器设置存取；方向按书覆盖（默认从左到右不占存储），背景全局共享。
class PagedImageReaderSettingsStore {
  const PagedImageReaderSettingsStore();

  static const directionOverridesKey = 'image_reader_direction_overrides_v1';
  static const backgroundKey = 'image_reader_background_v1';

  Future<ImageReaderDirection> loadDirection(int? bookId) async {
    if (bookId == null) return ImageReaderDirection.ltr;
    final overrides = await _loadOverrides();
    return ImageReaderDirection.fromName(overrides['$bookId']);
  }

  Future<void> saveDirection(
    int? bookId,
    ImageReaderDirection direction,
  ) async {
    if (bookId == null) return;
    final overrides = await _loadOverrides();
    if (direction == ImageReaderDirection.ltr) {
      overrides.remove('$bookId');
    } else {
      overrides['$bookId'] = direction.name;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(directionOverridesKey, jsonEncode(overrides));
  }

  Future<ImageReaderBackground> loadBackground() async {
    final prefs = await SharedPreferences.getInstance();
    return ImageReaderBackground.fromName(prefs.getString(backgroundKey));
  }

  Future<void> saveBackground(ImageReaderBackground background) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(backgroundKey, background.name);
  }

  Future<Map<String, String>> _loadOverrides() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(directionOverridesKey);
    if (raw == null || raw.isEmpty) return <String, String>{};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return <String, String>{};
      return <String, String>{
        for (final entry in decoded.entries)
          if (entry.value is String) '${entry.key}': entry.value as String,
      };
    } on FormatException {
      return <String, String>{};
    }
  }
}
