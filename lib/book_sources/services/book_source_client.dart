import 'dart:io';

import 'package:dio/dio.dart';

import '../models/registered_book_source.dart';
import '../protocol/book_source_protocol.dart';
import 'book_source_chapter_cache.dart';

class DiscoveredBookSource {
  final Uri manifestUrl;
  final BookSourceManifest manifest;

  const DiscoveredBookSource({
    required this.manifestUrl,
    required this.manifest,
  });
}

class BookSourceClient {
  final Dio _dio;
  final BookSourceChapterCache _chapterCache;

  /// 单次响应体上限。书源返回的都是 JSON 元数据/章节文本，
  /// 超过该值基本可以判定为异常或恶意响应，中途截断防止 OOM。
  static const int maxResponseBytes = 8 * 1024 * 1024;
  static const int maxDownloadResponseBytes = 24 * 1024 * 1024;
  static const Duration downloadReceiveTimeout = Duration(seconds: 90);
  static const int downloadMaxAttempts = 3;

  BookSourceClient({Dio? dio, BookSourceChapterCache? chapterCache})
      : _chapterCache = chapterCache ?? const BookSourceChapterCache(),
        _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 8),
                receiveTimeout: const Duration(seconds: 12),
                sendTimeout: const Duration(seconds: 8),
                headers: const {
                  'Accept': 'application/json',
                  'X-Open-Reading-Protocol': openReadingSourceProtocolVersion,
                },
              ),
            );

  /// 拒绝明显不该被书源指向的地址：链路本地（含云平台元数据端点
  /// 169.254.169.254）、0.0.0.0、组播。环回与私网地址保持合法，
  /// 本地测试书源和自建内网书源是受支持的使用场景。
  static void ensureSafeTarget(Uri uri) {
    final address = InternetAddress.tryParse(uri.host);
    if (address == null) return; // 域名交由 DNS 解析，不在此处拦截
    final isBlocked = address.isLinkLocal ||
        address.isMulticast ||
        address.address == '0.0.0.0' ||
        address.address == '::';
    if (isBlocked) {
      throw const BookSourceProtocolException(
        'This address is not allowed as a book source target.',
      );
    }
  }

  /// 统一的受限 GET：目标地址校验 + 响应体大小上限。
  Future<Object?> _getBounded(
    Uri uri, {
    int maxBytes = maxResponseBytes,
    Duration? receiveTimeout,
  }) async {
    ensureSafeTarget(uri);
    final cancelToken = CancelToken();
    final response = await _dio.getUri<Object?>(
      uri,
      options: Options(receiveTimeout: receiveTimeout),
      cancelToken: cancelToken,
      onReceiveProgress: (received, total) {
        if (received > maxBytes || total > maxBytes) {
          cancelToken.cancel('Response exceeds $maxBytes bytes.');
        }
      },
    );
    return response.data;
  }

  static Uri normalizeManifestUri(String input) {
    final trimmed = input.trim();
    final parsed = Uri.tryParse(trimmed);
    if (parsed == null ||
        !parsed.hasAuthority ||
        (parsed.scheme != 'http' && parsed.scheme != 'https')) {
      throw const BookSourceProtocolException(
        'Please enter a valid http or https URL.',
      );
    }
    if (parsed.path.endsWith('.json')) return parsed;

    final path = parsed.path.endsWith('/') ? parsed.path : '${parsed.path}/';
    return parsed
        .replace(path: path, query: null, fragment: null)
        .resolve(openReadingSourceDiscoveryPath);
  }

  Future<DiscoveredBookSource> discover(String input) async {
    final manifestUrl = normalizeManifestUri(input);
    try {
      final manifest = BookSourceManifest.fromJson(
        decodeBookSourceJson(await _getBounded(manifestUrl)),
      );
      return DiscoveredBookSource(
        manifestUrl: manifestUrl,
        manifest: manifest,
      );
    } on DioException catch (error) {
      throw BookSourceProtocolException(_dioErrorMessage(error));
    }
  }

  Future<BookSourceSearchPage> search(
    RegisteredBookSource source,
    String query, {
    int page = 1,
    int pageSize = 20,
  }) async {
    if (!source.capabilities.contains('search')) {
      throw const BookSourceProtocolException(
        'This source does not support search.',
      );
    }
    final uri = _apiUri(source.apiBaseUrl, 'v1/search').replace(
      queryParameters: {
        'q': query.trim(),
        'page': '$page',
        'pageSize': '$pageSize',
      },
    );
    try {
      return BookSourceSearchPage.fromJson(
        decodeBookSourceJson(await _getBounded(uri)),
      );
    } on DioException catch (error) {
      throw BookSourceProtocolException(_dioErrorMessage(error));
    }
  }

  Future<BookSourceBook> getBook(
    RegisteredBookSource source,
    String bookId,
  ) async {
    final uri = _apiUri(
      source.apiBaseUrl,
      'v1/books/${Uri.encodeComponent(bookId)}',
    );
    try {
      return BookSourceBook.fromJson(
        decodeBookSourceJson(await _getBounded(uri)),
      );
    } on DioException catch (error) {
      throw BookSourceProtocolException(_dioErrorMessage(error));
    }
  }

  Future<List<BookSourceChapter>> getChapters(
    RegisteredBookSource source,
    String bookId,
  ) async {
    final uri = _apiUri(
      source.apiBaseUrl,
      'v1/books/${Uri.encodeComponent(bookId)}/chapters',
    );
    try {
      final json = decodeBookSourceJson(await _getBounded(uri));
      final items = json['items'];
      if (items is! List) {
        throw const BookSourceProtocolException(
          'Chapter response must contain an items array.',
        );
      }
      return items
          .map((item) => BookSourceChapter.fromJson(
                decodeBookSourceJson(item),
              ))
          .toList(growable: false);
    } on DioException catch (error) {
      throw BookSourceProtocolException(_dioErrorMessage(error));
    }
  }

  Future<List<BookSourceChapter>> getChaptersForDownload(
    RegisteredBookSource source,
    String bookId,
  ) async {
    final uri = _apiUri(
      source.apiBaseUrl,
      'v1/books/${Uri.encodeComponent(bookId)}/chapters',
    );
    return _withDownloadRetries(() async {
      final json = decodeBookSourceJson(
        await _getBounded(
          uri,
          maxBytes: maxDownloadResponseBytes,
          receiveTimeout: downloadReceiveTimeout,
        ),
      );
      final items = json['items'];
      if (items is! List) {
        throw const BookSourceProtocolException(
          'Chapter response must contain an items array.',
        );
      }
      return items
          .map(
            (item) => BookSourceChapter.fromJson(decodeBookSourceJson(item)),
          )
          .toList(growable: false);
    });
  }

  Future<BookSourceChapterContent> getChapterContent(
    RegisteredBookSource source, {
    required String bookId,
    required String chapterId,
  }) async {
    return _chapterCache.getOrLoad(
      sourceId: source.id,
      bookId: bookId,
      chapterId: chapterId,
      loader: () async {
        final uri = _apiUri(
          source.apiBaseUrl,
          'v1/books/${Uri.encodeComponent(bookId)}/chapters/'
          '${Uri.encodeComponent(chapterId)}',
        );
        try {
          return BookSourceChapterContent.fromJson(
            decodeBookSourceJson(await _getBounded(uri)),
          );
        } on DioException catch (error) {
          throw BookSourceProtocolException(_dioErrorMessage(error));
        }
      },
    );
  }

  Future<BookSourceChapterContent> getChapterContentForDownload(
    RegisteredBookSource source, {
    required String bookId,
    required String chapterId,
  }) async {
    return _chapterCache.getOrLoad(
      sourceId: source.id,
      bookId: bookId,
      chapterId: chapterId,
      loader: () {
        final uri = _apiUri(
          source.apiBaseUrl,
          'v1/books/${Uri.encodeComponent(bookId)}/chapters/'
          '${Uri.encodeComponent(chapterId)}',
        );
        return _withDownloadRetries(
          () async => BookSourceChapterContent.fromJson(
            decodeBookSourceJson(
              await _getBounded(
                uri,
                maxBytes: maxDownloadResponseBytes,
                receiveTimeout: downloadReceiveTimeout,
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> prefetchChapterContent(
    RegisteredBookSource source, {
    required String bookId,
    required String chapterId,
  }) async {
    try {
      await getChapterContent(
        source,
        bookId: bookId,
        chapterId: chapterId,
      );
    } catch (_) {
      // Prefetching is opportunistic and must not surface reader errors.
    }
  }

  Future<T> _withDownloadRetries<T>(Future<T> Function() request) async {
    DioException? lastError;
    for (var attempt = 1; attempt <= downloadMaxAttempts; attempt++) {
      try {
        return await request();
      } on DioException catch (error) {
        lastError = error;
        if (attempt == downloadMaxAttempts) break;
        await Future<void>.delayed(
          Duration(milliseconds: 500 * attempt * attempt),
        );
      }
    }
    throw BookSourceProtocolException(
      _dioErrorMessage(lastError!),
    );
  }

  static Uri _apiUri(Uri baseUrl, String relativePath) {
    final normalizedPath =
        baseUrl.path.endsWith('/') ? baseUrl.path : '${baseUrl.path}/';
    return baseUrl.replace(path: normalizedPath).resolve(relativePath);
  }

  String _dioErrorMessage(DioException error) {
    final status = error.response?.statusCode;
    if (status != null) return 'Source request failed with HTTP $status.';
    return switch (error.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout =>
        'Source request timed out.',
      DioExceptionType.connectionError => 'Could not connect to the source.',
      _ => error.message ?? 'Source request failed.',
    };
  }
}
