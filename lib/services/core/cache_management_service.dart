import 'dart:io';

import 'package:flutter/painting.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../../book_sources/services/book_source_chapter_cache.dart';
import '../../book_sources/services/source_cover_cache.dart';

enum AppCacheCategory { sourceCovers, sourceData, temporaryFiles }

class AppCacheUsage {
  const AppCacheUsage(this.bytesByCategory);

  final Map<AppCacheCategory, int> bytesByCategory;

  int bytesFor(AppCacheCategory category) => bytesByCategory[category] ?? 0;
  int get totalBytes =>
      bytesByCategory.values.fold(0, (sum, value) => sum + value);
}

/// Reports and clears only cache directories explicitly owned by Open Reading.
///
/// Application documents, databases, imported books, saved covers, preferences,
/// and secure credentials are intentionally outside this service's directory
/// allowlist.
class AppCacheManager {
  AppCacheManager({
    SourceCoverCache? sourceCoverCache,
    Directory? temporaryDirectory,
    Future<void> Function()? clearFlutterImageCache,
    int Function()? imageCacheBytesReader,
  }) : _sourceCoverCache = sourceCoverCache ?? SourceCoverCache.instance,
       _temporaryDirectory = temporaryDirectory,
       _clearFlutterImageCache =
           clearFlutterImageCache ?? _defaultClearFlutterImageCache,
       _imageCacheBytesReader =
           imageCacheBytesReader ?? _defaultImageCacheBytesReader;

  static const String updateDirectoryName = 'updates';

  final SourceCoverCache _sourceCoverCache;
  final Directory? _temporaryDirectory;
  final Future<void> Function() _clearFlutterImageCache;
  final int Function() _imageCacheBytesReader;

  Future<AppCacheUsage> usage() async {
    final directories = await _directories();
    final bytesByCategory = <AppCacheCategory, int>{
      for (final category in AppCacheCategory.values)
        category: await _directoriesSize(directories[category]!),
    };
    bytesByCategory[AppCacheCategory.sourceCovers] =
        bytesByCategory[AppCacheCategory.sourceCovers]! +
        _sourceCoverCache.memorySizeBytes +
        _imageCacheBytesReader();
    return AppCacheUsage(bytesByCategory);
  }

  Future<void> clear(AppCacheCategory category) async {
    switch (category) {
      case AppCacheCategory.sourceCovers:
        await _sourceCoverCache.clear();
        await _clearFlutterImageCache();
        return;
      case AppCacheCategory.sourceData:
        BookSourceChapterCache.clearMemory();
        break;
      case AppCacheCategory.temporaryFiles:
        break;
    }
    final directories = (await _directories())[category]!;
    for (final directory in directories) {
      await _deleteDirectory(directory);
    }
  }

  Future<void> clearAll() async {
    for (final category in AppCacheCategory.values) {
      await clear(category);
    }
  }

  Future<Map<AppCacheCategory, List<Directory>>> _directories() async {
    final temp = _temporaryDirectory ?? await getTemporaryDirectory();
    return {
      AppCacheCategory.sourceCovers: [await _sourceCoverCache.directory()],
      AppCacheCategory.sourceData: [
        Directory(path.join(temp.path, BookSourceChapterCache.directoryName)),
      ],
      AppCacheCategory.temporaryFiles: [
        Directory(path.join(temp.path, updateDirectoryName)),
      ],
    };
  }

  Future<int> _directoriesSize(List<Directory> directories) async {
    var total = 0;
    for (final directory in directories) {
      total += await _directorySize(directory);
    }
    return total;
  }

  Future<int> _directorySize(Directory directory) async {
    if (!await directory.exists()) return 0;
    var total = 0;
    await for (final entity in directory.list(
      recursive: true,
      followLinks: false,
    )) {
      if (entity is! File) continue;
      try {
        total += await entity.length();
      } catch (_) {
        // A temporary file may disappear while sizes are being calculated.
      }
    }
    return total;
  }

  Future<void> _deleteDirectory(Directory directory) async {
    if (await directory.exists()) await directory.delete(recursive: true);
  }

  static Future<void> _defaultClearFlutterImageCache() async {
    final cache = PaintingBinding.instance.imageCache;
    cache.clear();
    cache.clearLiveImages();
  }

  static int _defaultImageCacheBytesReader() =>
      PaintingBinding.instance.imageCache.currentSizeBytes;

  static String formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(2)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}
