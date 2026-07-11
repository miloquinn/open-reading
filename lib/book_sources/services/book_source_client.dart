import 'dart:io';

import 'package:dio/dio.dart';

import '../models/registered_book_source.dart';
import '../protocol/book_source_protocol.dart';

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

  /// 单次响应体上限。书源返回的都是 JSON 元数据/章节文本，
  /// 超过该值基本可以判定为异常或恶意响应，中途截断防止 OOM。
  static const int maxResponseBytes = 8 * 1024 * 1024;

  BookSourceClient({Dio? dio})
      : _dio = dio ??
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
  Future<Object?> _getBounded(Uri uri) async {
    ensureSafeTarget(uri);
    final cancelToken = CancelToken();
    final response = await _dio.getUri<Object?>(
      uri,
      cancelToken: cancelToken,
      onReceiveProgress: (received, total) {
        if (received > maxResponseBytes || total > maxResponseBytes) {
          cancelToken.cancel('Response exceeds $maxResponseBytes bytes.');
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

  Future<BookSourceChapterContent> getChapterContent(
    RegisteredBookSource source, {
    required String bookId,
    required String chapterId,
  }) async {
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
