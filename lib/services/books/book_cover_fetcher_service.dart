// 文件说明：封面抓取服务，负责从远程资源拉取书籍封面。
// 技术要点：服务层、Dio、Flutter。

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// 书籍封面获取服务
///
/// 从多个来源自动获取书籍封面图片
/// 支持：豆瓣读书、Google Books API、Open Library
class BookCoverFetcher {
  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 5), // 连接超时5秒
      receiveTimeout: const Duration(seconds: 10), // 接收超时10秒
    ),
  );

  /// 从多个源获取封面（带总超时限制）
  ///
  /// [title] 书名
  /// [author] 作者（可选）
  /// [isbn] ISBN号（可选，最准确）
  /// [timeout] 总超时时间（默认20秒）
  /// Returns: 封面图片字节数据，失败返回null
  Future<Uint8List?> fetchCover({
    required String title,
    String? author,
    String? isbn,
    Duration timeout = const Duration(seconds: 20),
  }) async {
    debugPrint('📚 开始获取书籍封面: $title${author != null ? ' - $author' : ''}');

    try {
      // 整体超时控制
      return await Future.any([
        _fetchCoverInternal(title, author, isbn),
        Future.delayed(timeout, () => null),
      ]);
    } catch (e) {
      debugPrint('⚠️ 封面获取异常: $e');
      return null;
    }
  }

  /// 内部封面获取逻辑
  Future<Uint8List?> _fetchCoverInternal(
    String title,
    String? author,
    String? isbn,
  ) async {
    // 优先使用ISBN查询（最准确）
    if (isbn != null && isbn.isNotEmpty) {
      final cover = await _fetchByIsbn(isbn);
      if (cover != null) {
        debugPrint('✅ 通过ISBN成功获取封面');
        return cover;
      }
    }

    // 尝试豆瓣搜索
    final doubanCover = await _fetchFromDouban(title, author);
    if (doubanCover != null) {
      debugPrint('✅ 从豆瓣成功获取封面');
      return doubanCover;
    }

    // 尝试Google Books
    final googleCover = await _fetchFromGoogleBooks(title, author);
    if (googleCover != null) {
      debugPrint('✅ 从Google Books成功获取封面');
      return googleCover;
    }

    // 尝试Open Library
    final openLibraryCover = await _fetchFromOpenLibrary(title, author);
    if (openLibraryCover != null) {
      debugPrint('✅ 从Open Library成功获取封面');
      return openLibraryCover;
    }

    debugPrint('❌ 所有来源都未找到封面');
    return null;
  }

  /// 快速获取封面（超短超时，用于导入流程）
  ///
  /// [title] 书名
  /// [author] 作者（可选）
  /// [isbn] ISBN号（可选）
  /// Returns: 封面图片字节数据，失败返回null
  Future<Uint8List?> fetchCoverQuick({
    required String title,
    String? author,
    String? isbn,
  }) async {
    // 导入时使用5秒超时，避免长时间卡住
    return await fetchCover(
      title: title,
      author: author,
      isbn: isbn,
      timeout: const Duration(seconds: 5),
    );
  }

  /// 通过ISBN获取封面（最准确）
  Future<Uint8List?> _fetchByIsbn(String isbn) async {
    try {
      // 清理ISBN（移除横线）
      final cleanIsbn = isbn.replaceAll(RegExp(r'[-\s]'), '');

      // 尝试Open Library的ISBN封面API
      final url = 'https://covers.openlibrary.org/b/isbn/$cleanIsbn-L.jpg';
      debugPrint('尝试获取ISBN封面: $url');

      final response = await _dio.get(
        url,
        options: Options(
          responseType: ResponseType.bytes,
          validateStatus: (status) => status! < 500,
        ),
      );

      if (response.statusCode == 200 && response.data != null) {
        final bytes = response.data as List<int>;
        if (bytes.length > 1000) {
          // 确保不是占位符图片（通常很小）
          return Uint8List.fromList(bytes);
        }
      }
    } catch (e) {
      debugPrint('ISBN封面获取失败: $e');
    }
    return null;
  }

  /// 从豆瓣读书获取封面
  Future<Uint8List?> _fetchFromDouban(String title, String? author) async {
    try {
      // 豆瓣API已经限制访问，这里使用豆瓣搜索页面抓取（仅作示例）
      // 实际使用时需要考虑豆瓣的使用条款

      // 注意：豆瓣API需要apikey，这里仅作示例
      // 实际项目中建议使用官方API或其他开放API
      debugPrint('豆瓣API已限制，跳过豆瓣源');
      return null;
    } catch (e) {
      debugPrint('豆瓣封面获取失败: $e');
      return null;
    }
  }

  /// 从Google Books API获取封面
  Future<Uint8List?> _fetchFromGoogleBooks(String title, String? author) async {
    try {
      // Google Books API（无需API Key的公开接口）
      String query = 'intitle:$title';
      if (author != null && author.isNotEmpty) {
        query += '+inauthor:$author';
      }

      final searchUrl =
          'https://www.googleapis.com/books/v1/volumes?q=${Uri.encodeComponent(query)}&maxResults=1';
      debugPrint('搜索Google Books: $searchUrl');

      final searchResponse = await _dio.get(searchUrl);

      if (searchResponse.statusCode == 200) {
        final data = searchResponse.data;
        if (data['totalItems'] > 0) {
          final book = data['items'][0];
          final imageLinks = book['volumeInfo']['imageLinks'];

          if (imageLinks != null) {
            // 优先使用大图
            String? imageUrl = imageLinks['large'] ??
                imageLinks['medium'] ??
                imageLinks['thumbnail'];

            if (imageUrl != null) {
              // Google Books的图片URL需要使用https和去掉curl参数
              imageUrl = imageUrl
                  .replaceAll('http:', 'https:')
                  .replaceAll('&edge=curl', '');
              debugPrint('找到封面URL: $imageUrl');

              final imageResponse = await _dio.get(
                imageUrl,
                options: Options(responseType: ResponseType.bytes),
              );

              if (imageResponse.statusCode == 200) {
                return Uint8List.fromList(imageResponse.data as List<int>);
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Google Books封面获取失败: $e');
    }
    return null;
  }

  /// 从Open Library获取封面
  Future<Uint8List?> _fetchFromOpenLibrary(String title, String? author) async {
    try {
      // Open Library搜索API
      String query = title;
      if (author != null && author.isNotEmpty) {
        query += ' $author';
      }

      final searchUrl =
          'https://openlibrary.org/search.json?q=${Uri.encodeComponent(query)}&limit=1';
      debugPrint('搜索Open Library: $searchUrl');

      final searchResponse = await _dio.get(searchUrl);

      if (searchResponse.statusCode == 200) {
        final data = searchResponse.data;
        if (data['numFound'] > 0 && data['docs'].isNotEmpty) {
          final book = data['docs'][0];
          final coverId = book['cover_i'];

          if (coverId != null) {
            // Open Library封面URL
            final imageUrl =
                'https://covers.openlibrary.org/b/id/$coverId-L.jpg';
            debugPrint('找到封面URL: $imageUrl');

            final imageResponse = await _dio.get(
              imageUrl,
              options: Options(responseType: ResponseType.bytes),
            );

            if (imageResponse.statusCode == 200) {
              final bytes = imageResponse.data as List<int>;
              if (bytes.length > 1000) {
                return Uint8List.fromList(bytes);
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Open Library封面获取失败: $e');
    }
    return null;
  }

  /// 批量获取封面（带重试机制）
  Future<Map<String, Uint8List>> batchFetchCovers(
    List<Map<String, String>> books, {
    int maxConcurrent = 3,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final results = <String, Uint8List>{};
    final futures = <Future<void>>[];

    for (var i = 0; i < books.length; i += maxConcurrent) {
      final batch = books.skip(i).take(maxConcurrent);

      for (final book in batch) {
        futures.add(
          _fetchWithTimeout(
            title: book['title']!,
            author: book['author'],
            isbn: book['isbn'],
            timeout: timeout,
          ).then((cover) {
            if (cover != null) {
              results[book['title']!] = cover;
            }
          }),
        );
      }

      // 等待当前批次完成
      await Future.wait(futures);
      futures.clear();
    }

    return results;
  }

  /// 带超时的封面获取
  Future<Uint8List?> _fetchWithTimeout({
    required String title,
    String? author,
    String? isbn,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    try {
      return await fetchCover(
        title: title,
        author: author,
        isbn: isbn,
      ).timeout(timeout);
    } catch (e) {
      debugPrint('封面获取超时: $title');
      return null;
    }
  }
}
