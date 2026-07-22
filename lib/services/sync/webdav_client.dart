import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:dio/dio.dart';

import 'secure_sync_config.dart';
import 'sync_models.dart';

class WebDavClient {
  WebDavClient({required Dio dio, required StoredSyncCredentials credentials})
      : _dio = dio,
        _credentials = credentials,
        _origin = validateWebDavConfiguration(credentials.configuration);

  factory WebDavClient.standard(StoredSyncCredentials credentials) {
    return WebDavClient(
      dio: Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 15),
          sendTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 30),
          responseType: ResponseType.plain,
        ),
      ),
      credentials: credentials,
    );
  }

  final Dio _dio;
  final StoredSyncCredentials _credentials;
  final Uri _origin;
  DateTime? lastServerDate;

  Uri get protocolRoot => _pathUri([
        ..._rootSegments,
        'v1',
      ]);

  List<String> get _rootSegments => _credentials.configuration.rootPath
      .split('/')
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty)
      .toList(growable: false);

  Uri path(List<String> relativeSegments) =>
      _pathUri([..._rootSegments, 'v1', ...relativeSegments]);

  Uri _pathUri(List<String> segments) {
    final baseSegments = _origin.pathSegments.where((part) => part.isNotEmpty);
    return _origin.replace(
      pathSegments: [...baseSegments, ...segments],
      query: null,
      fragment: null,
    );
  }

  Future<ConnectionTestResult> testConnection() async {
    try {
      final options = await _request('OPTIONS', _origin);
      await ensureCollection([..._rootSegments]);
      final rootProbe = await _request(
        'PROPFIND',
        _pathUri(_rootSegments),
        headers: const {'Depth': '0'},
        data: _propfindBody,
      );
      final suffix =
          '${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(1 << 32)}';
      final testCollection =
          _pathUri([..._rootSegments, '.open-reading-test-$suffix']);
      final testFile = testCollection.replace(
        pathSegments: [...testCollection.pathSegments, 'probe.txt'],
      );
      await _request('MKCOL', testCollection);
      try {
        final put =
            await _request('PUT', testFile, data: 'open-reading-webdav-probe');
        final get = await _request('GET', testFile);
        if (get.data != 'open-reading-webdav-probe') {
          throw const WebDavSyncFailure(
            WebDavSyncErrorCode.serverIncompatible,
            'The server did not return the test file unchanged.',
          );
        }
        await _request('DELETE', testFile);
        final allow = options.headers.value('allow')?.toUpperCase() ?? '';
        return ConnectionTestResult(
          success: true,
          supportsEtag: put.headers.value('etag') != null ||
              rootProbe.headers.value('etag') != null,
          supportsMove: allow.contains('MOVE'),
          serverDate: _serverDate(get),
        );
      } finally {
        try {
          await _request('DELETE', testCollection);
        } catch (_) {
          // The probe file is already removed. Some servers refuse collection
          // deletion; a unique empty test directory is harmless.
        }
      }
    } on WebDavSyncFailure catch (error) {
      return ConnectionTestResult(
        success: false,
        errorCode: error.code,
        message: error.message,
      );
    }
  }

  Future<void> ensureProtocolCollections(String deviceId) async {
    await ensureCollection(_rootSegments);
    await ensureCollection([..._rootSegments, 'v1']);
    await ensureCollection([..._rootSegments, 'v1', 'devices']);
    await ensureCollection([..._rootSegments, 'v1', 'devices', deviceId]);
    await ensureCollection([
      ..._rootSegments,
      'v1',
      'devices',
      deviceId,
      'changes',
    ]);
  }

  Future<void> ensureProtocolPath(List<String> relativeSegments) async {
    await ensureCollection([
      ..._rootSegments,
      'v1',
      ...relativeSegments,
    ]);
  }

  Future<void> ensureCollection(List<String> segments) async {
    final built = <String>[];
    for (final segment in segments) {
      built.add(segment);
      try {
        await _request('MKCOL', _pathUri(built));
      } on WebDavSyncFailure catch (error) {
        if (error.statusCode != 405) rethrow;
      }
    }
  }

  Future<String?> getText(Uri uri, {bool allowNotFound = false}) async {
    try {
      final response = await _request('GET', uri);
      return response.data;
    } on WebDavSyncFailure catch (error) {
      if (allowNotFound && error.statusCode == 404) return null;
      rethrow;
    }
  }

  Future<bool> exists(Uri uri) async {
    try {
      await _request('HEAD', uri);
      return true;
    } on WebDavSyncFailure catch (error) {
      if (error.statusCode == 404) return false;
      rethrow;
    }
  }

  Future<void> putFile(
    Uri uri,
    File file, {
    void Function(int sent, int total)? onProgress,
  }) async {
    if (!_sameOrigin(uri, _origin)) {
      throw const WebDavSyncFailure(
        WebDavSyncErrorCode.serverIncompatible,
        'Book files can only be uploaded to the configured WebDAV origin.',
      );
    }
    final total = await file.length();
    try {
      final response = await _dio.request<void>(
        uri.toString(),
        data: file.openRead(),
        onSendProgress: onProgress,
        options: Options(
          method: 'PUT',
          followRedirects: false,
          validateStatus: (_) => true,
          headers: {
            'Authorization': _authorization,
            Headers.contentLengthHeader: total,
            Headers.contentTypeHeader: 'application/octet-stream',
          },
        ),
      );
      final status = response.statusCode ?? 0;
      if (status < 200 || status >= 300) throw _statusFailure(status);
    } on DioException catch (error) {
      throw _dioFailure(error);
    }
  }

  Future<void> downloadFile(
    Uri uri,
    File target, {
    void Function(int received, int total)? onProgress,
  }) async {
    if (!_sameOrigin(uri, _origin)) {
      throw const WebDavSyncFailure(
        WebDavSyncErrorCode.serverIncompatible,
        'Book files can only be downloaded from the configured WebDAV origin.',
      );
    }
    try {
      final response = await _dio.get<ResponseBody>(
        uri.toString(),
        options: Options(
          followRedirects: false,
          validateStatus: (_) => true,
          responseType: ResponseType.stream,
          headers: {'Authorization': _authorization},
        ),
      );
      final status = response.statusCode ?? 0;
      if (status < 200 || status >= 300) throw _statusFailure(status);
      final body = response.data;
      if (body == null) {
        throw const WebDavSyncFailure(
          WebDavSyncErrorCode.serverIncompatible,
          'The WebDAV server returned an empty book-file response.',
        );
      }
      final total = int.tryParse(
            response.headers.value(Headers.contentLengthHeader) ?? '',
          ) ??
          -1;
      final sink = target.openWrite();
      var received = 0;
      try {
        await for (final chunk in body.stream) {
          sink.add(chunk);
          received += chunk.length;
          onProgress?.call(received, total);
        }
        await sink.flush();
      } finally {
        await sink.close();
      }
    } on DioException catch (error) {
      throw _dioFailure(error);
    }
  }

  Future<void> delete(Uri uri, {bool allowNotFound = true}) async {
    try {
      await _request('DELETE', uri);
    } on WebDavSyncFailure catch (error) {
      if (!allowNotFound || error.statusCode != 404) rethrow;
    }
  }

  Future<void> move(
    Uri source,
    Uri destination, {
    bool overwrite = false,
  }) async {
    if (!_sameOrigin(destination, _origin)) {
      throw const WebDavSyncFailure(
        WebDavSyncErrorCode.serverIncompatible,
        'WebDAV MOVE is restricted to the configured server origin.',
      );
    }
    await _request(
      'MOVE',
      source,
      headers: {
        'Destination': destination.toString(),
        'Overwrite': overwrite ? 'T' : 'F',
      },
    );
  }

  Future<void> putText(
    Uri uri,
    String content, {
    bool immutable = false,
  }) async {
    try {
      await _request(
        'PUT',
        uri,
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          if (immutable) 'If-None-Match': '*',
        },
        data: content,
      );
    } on WebDavSyncFailure catch (error) {
      if (!immutable || (error.statusCode != 409 && error.statusCode != 412)) {
        rethrow;
      }
    }
    if (immutable) {
      final stored = await getText(uri);
      if (stored != content) {
        throw const WebDavSyncFailure(
          WebDavSyncErrorCode.conflict,
          'The server already contains different data at an immutable batch path.',
        );
      }
    }
  }

  Future<List<Uri>> list(Uri collection, {int depth = 1}) async {
    final response = await _request(
      'PROPFIND',
      collection,
      headers: {'Depth': '$depth'},
      data: _propfindBody,
    );
    final body = response.data ?? '';
    final hrefPattern = RegExp(
      r'<(?:[A-Za-z0-9_-]+:)?href[^>]*>(.*?)</(?:[A-Za-z0-9_-]+:)?href>',
      caseSensitive: false,
      dotAll: true,
    );
    final uris = <Uri>[];
    for (final match in hrefPattern.allMatches(body)) {
      final decoded = _decodeXml(match.group(1)!.trim());
      final resolved = collection.resolve(decoded);
      if (_sameOrigin(resolved, _origin)) uris.add(resolved);
    }
    return uris;
  }

  Future<Response<String>> _request(
    String method,
    Uri uri, {
    Map<String, String>? headers,
    Object? data,
    int redirects = 0,
  }) async {
    if (!_sameOrigin(uri, _origin)) {
      throw const WebDavSyncFailure(
        WebDavSyncErrorCode.serverIncompatible,
        'The WebDAV server attempted to redirect credentials to another origin.',
      );
    }
    try {
      final response = await _dio.request<String>(
        uri.toString(),
        data: data,
        options: Options(
          method: method,
          followRedirects: false,
          validateStatus: (_) => true,
          responseType: ResponseType.plain,
          headers: {
            'Authorization': _authorization,
            ...?headers,
          },
        ),
      );
      final status = response.statusCode ?? 0;
      final dateHeader = response.headers.value('date');
      if (dateHeader != null) {
        lastServerDate = _parseHttpDate(dateHeader);
      }
      if (status >= 300 && status < 400) {
        if (redirects >= 5) {
          throw const WebDavSyncFailure(
            WebDavSyncErrorCode.serverIncompatible,
            'The WebDAV server returned too many redirects.',
          );
        }
        final location = response.headers.value('location');
        if (location == null) {
          throw _statusFailure(status);
        }
        final redirected = uri.resolve(location);
        if (!_sameOrigin(redirected, uri)) {
          throw const WebDavSyncFailure(
            WebDavSyncErrorCode.serverIncompatible,
            'The WebDAV server attempted to redirect credentials to another origin.',
          );
        }
        return _request(
          method,
          redirected,
          headers: headers,
          data: data,
          redirects: redirects + 1,
        );
      }
      if (status < 200 || status >= 300) throw _statusFailure(status);
      return response;
    } on DioException catch (error) {
      throw _dioFailure(error);
    }
  }

  DateTime? _serverDate(Response response) {
    final value = response.headers.value('date');
    return value == null ? null : _parseHttpDate(value);
  }

  String get _authorization =>
      'Basic ${base64Encode(utf8.encode('${_credentials.configuration.username}:${_credentials.password}'))}';
}

const _propfindBody = '''<?xml version="1.0" encoding="utf-8" ?>
<d:propfind xmlns:d="DAV:"><d:prop><d:getetag/><d:resourcetype/></d:prop></d:propfind>''';

bool _sameOrigin(Uri a, Uri b) =>
    a.scheme.toLowerCase() == b.scheme.toLowerCase() &&
    a.host.toLowerCase() == b.host.toLowerCase() &&
    a.port == b.port;

DateTime? _parseHttpDate(String value) {
  try {
    return HttpDate.parse(value).toUtc();
  } catch (_) {
    return DateTime.tryParse(value)?.toUtc();
  }
}

String _decodeXml(String value) => value
    .replaceAll('&amp;', '&')
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&quot;', '"')
    .replaceAll('&apos;', "'");

WebDavSyncFailure _statusFailure(int status) {
  final code = switch (status) {
    401 => WebDavSyncErrorCode.authentication,
    403 => WebDavSyncErrorCode.permissionDenied,
    404 => WebDavSyncErrorCode.notFound,
    409 || 412 || 423 => WebDavSyncErrorCode.conflict,
    429 => WebDavSyncErrorCode.rateLimited,
    507 => WebDavSyncErrorCode.storageFull,
    _ => WebDavSyncErrorCode.serverIncompatible,
  };
  return WebDavSyncFailure(
    code,
    'The WebDAV server rejected the request (HTTP $status).',
    statusCode: status,
  );
}

WebDavSyncFailure _dioFailure(DioException error) {
  final code = switch (error.type) {
    DioExceptionType.connectionTimeout ||
    DioExceptionType.sendTimeout ||
    DioExceptionType.receiveTimeout =>
      WebDavSyncErrorCode.timeout,
    DioExceptionType.badCertificate => WebDavSyncErrorCode.tls,
    DioExceptionType.connectionError => WebDavSyncErrorCode.network,
    _ => WebDavSyncErrorCode.network,
  };
  return WebDavSyncFailure(
    code,
    code == WebDavSyncErrorCode.tls
        ? 'The WebDAV server certificate could not be verified.'
        : 'The WebDAV server could not be reached.',
  );
}
