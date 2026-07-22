import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;

import 'package:xxread/book_sources/services/book_source_chapter_cache.dart';
import 'package:xxread/book_sources/services/source_cover_cache.dart';
import 'package:xxread/services/core/cache_management_service.dart';

void main() {
  test('reports and clears only allowlisted cache categories', () async {
    final root = await Directory.systemTemp.createTemp('cache-manager-');
    addTearDown(() => root.delete(recursive: true));
    final covers = Directory(path.join(root.path, 'cover-cache'));
    final chapters = Directory(
      path.join(root.path, BookSourceChapterCache.directoryName),
    );
    final updates = Directory(
      path.join(root.path, AppCacheManager.updateDirectoryName),
    );
    final userDocuments = Directory(path.join(root.path, 'books'));
    for (final directory in [covers, chapters, updates, userDocuments]) {
      await directory.create(recursive: true);
    }
    await File(
      path.join(covers.path, 'cover.img'),
    ).writeAsBytes(List.filled(5, 1));
    await File(
      path.join(chapters.path, 'chapter.json'),
    ).writeAsBytes(List.filled(7, 1));
    await File(
      path.join(updates.path, 'update.part'),
    ).writeAsBytes(List.filled(13, 1));
    final book = File(path.join(userDocuments.path, 'book.epub'));
    await book.writeAsBytes(List.filled(17, 1));
    var imageCacheClears = 0;
    final coverCache = SourceCoverCache(
      cacheDirectory: covers,
      loader: (_) async => Uint8List.fromList([2, 3, 4]),
    );
    await coverCache.load(Uri.parse('https://example.org/cover.jpg'));
    final manager = AppCacheManager(
      sourceCoverCache: coverCache,
      temporaryDirectory: root,
      clearFlutterImageCache: () async => imageCacheClears++,
      imageCacheBytesReader: () => 19,
    );

    final usage = await manager.usage();
    expect(usage.bytesFor(AppCacheCategory.sourceCovers), 30);
    expect(usage.bytesFor(AppCacheCategory.sourceData), 7);
    expect(usage.bytesFor(AppCacheCategory.temporaryFiles), 13);
    expect(usage.totalBytes, 50);

    await manager.clear(AppCacheCategory.sourceCovers);
    expect(await covers.exists(), isFalse);
    expect(imageCacheClears, 1);
    expect(await chapters.exists(), isTrue);
    expect(await book.exists(), isTrue);

    await manager.clearAll();
    expect(await chapters.exists(), isFalse);
    expect(await updates.exists(), isFalse);
    expect(await book.exists(), isTrue);
  });

  test('formats exact bytes and megabytes', () {
    expect(AppCacheManager.formatBytes(123), '123 B');
    expect(AppCacheManager.formatBytes(512 * 1024), '512.00 KB');
    expect(AppCacheManager.formatBytes(2 * 1024 * 1024), '2.00 MB');
    expect(AppCacheManager.formatBytes(3 * 1024 * 1024 * 1024), '3.00 GB');
  });
}
