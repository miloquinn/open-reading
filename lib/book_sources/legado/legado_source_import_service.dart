import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';

import '../protocol/book_source_protocol.dart';
import '../services/book_source_network_policy.dart';
import 'legado_book_source.dart';

class LegadoImportPreview {
  const LegadoImportPreview({required this.sources, required this.errors});

  final List<LegadoBookSource> sources;
  final List<String> errors;

  int get supported => _count(LegadoCompatibilityLevel.supported);
  int get partial => _count(LegadoCompatibilityLevel.partial);
  int get unsupported => _count(LegadoCompatibilityLevel.unsupported);

  int _count(LegadoCompatibilityLevel level) => sources
      .where(
        (source) =>
            const LegadoCompatibilityScanner().scan(source).level == level,
      )
      .length;
}

class LegadoSourceImportService {
  LegadoSourceImportService({
    Dio? dio,
    BookSourceNetworkPolicy networkPolicy = const BookSourceNetworkPolicy(),
  }) : _networkPolicy = networkPolicy,
       _dio =
           dio ??
           (Dio(
               BaseOptions(
                 connectTimeout: const Duration(seconds: 8),
                 receiveTimeout: const Duration(seconds: 20),
                 sendTimeout: const Duration(seconds: 8),
               ),
             )
             ..httpClientAdapter = IOHttpClientAdapter(
               createHttpClient: networkPolicy.createPinnedHttpClient,
             ));

  /// Large aggregate source lists commonly exceed 20 MiB. Keep a finite
  /// boundary for malformed or hostile responses without rejecting normal
  /// community-maintained collections.
  static const int maxImportBytes = 64 * 1024 * 1024;
  static const int maxSources = 10000;
  static const int maxNestedUrls = 50;
  static const int maxNestedDepth = 2;

  final Dio _dio;
  final BookSourceNetworkPolicy _networkPolicy;

  void close({bool force = true}) => _dio.close(force: force);

  Future<Uint8List> downloadBytes(String input) async {
    final uri = Uri.tryParse(input.trim());
    if (uri == null ||
        !uri.hasAuthority ||
        (uri.scheme != 'http' && uri.scheme != 'https')) {
      throw const FormatException('Import URL must use HTTP or HTTPS.');
    }
    return _download(uri);
  }

  LegadoImportPreview parseBytes(Uint8List bytes) {
    return _collect(_parseBytes(bytes));
  }

  LegadoSourceImportResult _parseBytes(Uint8List bytes) {
    if (bytes.length > maxImportBytes) {
      throw const FormatException('Source file exceeds the 64 MiB limit.');
    }
    late final String text;
    try {
      text = utf8.decode(bytes, allowMalformed: false);
    } on FormatException catch (error) {
      throw FormatException(
        'Source JSON must be valid UTF-8: ${error.message}',
      );
    }
    return parseLegadoSources(
      text,
      maxSources: maxSources,
      maxNestedUrls: maxNestedUrls,
    );
  }

  Future<LegadoImportPreview> loadUrl(String input) async {
    final uri = Uri.tryParse(input.trim());
    if (uri == null ||
        !uri.hasAuthority ||
        (uri.scheme != 'http' && uri.scheme != 'https')) {
      throw const FormatException('Import URL must use HTTP or HTTPS.');
    }
    final byUrl = <String, LegadoBookSource>{};
    final errors = <String>[];
    final visited = <String>{};
    await _loadRecursive(
      uri,
      depth: 0,
      visited: visited,
      byUrl: byUrl,
      errors: errors,
    );
    return LegadoImportPreview(
      sources: List.unmodifiable(byUrl.values),
      errors: List.unmodifiable(errors),
    );
  }

  Future<void> _loadRecursive(
    Uri uri, {
    required int depth,
    required Set<String> visited,
    required Map<String, LegadoBookSource> byUrl,
    required List<String> errors,
  }) async {
    if (depth > maxNestedDepth) {
      errors.add('$uri: nested import depth exceeds $maxNestedDepth.');
      return;
    }
    if (!visited.add(uri.toString())) return;
    if (visited.length > maxNestedUrls + 1) {
      throw const FormatException('Too many nested source URLs.');
    }
    final bytes = await _download(uri);
    final parsed = _parseBytes(bytes);
    for (final source in parsed.sources) {
      byUrl[source.url] = source;
      if (byUrl.length > maxSources) {
        throw const FormatException('Too many sources in import.');
      }
    }
    errors.addAll(parsed.errors.map((error) => '$uri: $error'));
    for (final nested in parsed.sourceUrls) {
      await _loadRecursive(
        nested,
        depth: depth + 1,
        visited: visited,
        byUrl: byUrl,
        errors: errors,
      );
    }
  }

  Future<Uint8List> _download(Uri initial) async {
    var current = initial;
    for (var redirects = 0; redirects <= 5; redirects++) {
      await _networkPolicy.validate(current);
      final cancelToken = CancelToken();
      try {
        final response = await _dio.getUri<List<int>>(
          current,
          options: Options(
            responseType: ResponseType.bytes,
            followRedirects: false,
            validateStatus: (status) =>
                status != null && status >= 200 && status < 400,
          ),
          cancelToken: cancelToken,
          onReceiveProgress: (received, total) {
            if (received > maxImportBytes || total > maxImportBytes) {
              cancelToken.cancel(
                'Source import exceeds $maxImportBytes bytes.',
              );
            }
          },
        );
        final status = response.statusCode ?? 0;
        if (status < 300) {
          final bytes = Uint8List.fromList(response.data ?? const []);
          if (bytes.length > maxImportBytes) {
            throw const FormatException('Source import exceeds 64 MiB.');
          }
          return bytes;
        }
        if (redirects == 5) {
          throw const BookSourceProtocolException(
            'Source import redirected too many times.',
          );
        }
        current = BookSourceNetworkPolicy.redirectTarget(
          current,
          response.headers.value(HttpHeaders.locationHeader),
        );
      } on DioException catch (error) {
        if (CancelToken.isCancel(error)) {
          throw const FormatException('Source import exceeds 64 MiB.');
        }
        rethrow;
      }
    }
    throw const BookSourceProtocolException('Source import failed.');
  }

  LegadoImportPreview _collect(LegadoSourceImportResult result) {
    return LegadoImportPreview(sources: result.sources, errors: result.errors);
  }
}
