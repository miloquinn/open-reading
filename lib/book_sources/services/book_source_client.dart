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
      final response = await _dio.getUri<Object?>(manifestUrl);
      final manifest = BookSourceManifest.fromJson(
        decodeBookSourceJson(response.data),
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
      final response = await _dio.getUri<Object?>(uri);
      return BookSourceSearchPage.fromJson(
        decodeBookSourceJson(response.data),
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
      final response = await _dio.getUri<Object?>(uri);
      return BookSourceBook.fromJson(decodeBookSourceJson(response.data));
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
      final response = await _dio.getUri<Object?>(uri);
      final json = decodeBookSourceJson(response.data);
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
      final response = await _dio.getUri<Object?>(uri);
      return BookSourceChapterContent.fromJson(
        decodeBookSourceJson(response.data),
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
