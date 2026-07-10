// 文件说明：本地阅读文件服务器，为 Web 阅读器提供本地文件访问能力。
// 技术要点：服务层、文件系统。

import 'dart:io';
import 'dart:math';

/// Lightweight localhost file server for reader engines.
/// Serving EPUB through http://127.0.0.1 avoids file:// fetch quirks on
/// different WebView implementations.
class LocalReaderFileServer {
  LocalReaderFileServer._();

  static final LocalReaderFileServer instance = LocalReaderFileServer._();

  final Map<String, String> _tokenToPath = <String, String>{};
  final Random _random = Random.secure();
  HttpServer? _server;

  Future<String> registerBookFile(String filePath) async {
    await _ensureServer();
    final token = _createToken();
    if (_tokenToPath.length > 64) {
      _tokenToPath.remove(_tokenToPath.keys.first);
    }
    _tokenToPath[token] = filePath;
    final port = _server!.port;
    return 'http://127.0.0.1:$port/book/$token';
  }

  Future<void> _ensureServer() async {
    if (_server != null) {
      return;
    }
    final server = await HttpServer.bind(
      InternetAddress.loopbackIPv4,
      0,
      shared: true,
    );
    server.autoCompress = false;
    server.listen(_handleRequest);
    _server = server;
  }

  Future<void> _handleRequest(HttpRequest request) async {
    final response = request.response;
    response.headers.set(HttpHeaders.accessControlAllowOriginHeader, '*');
    response.headers.set(HttpHeaders.cacheControlHeader, 'no-store');

    if (request.method == 'OPTIONS') {
      response.statusCode = HttpStatus.noContent;
      await response.close();
      return;
    }

    final segments = request.uri.pathSegments;
    if (segments.length != 2 || segments.first != 'book') {
      await _respondWithStatus(response, HttpStatus.notFound);
      return;
    }

    final token = segments[1];
    final filePath = _tokenToPath[token];
    if (filePath == null) {
      await _respondWithStatus(response, HttpStatus.notFound);
      return;
    }

    final file = File(filePath);
    if (!await file.exists()) {
      await _respondWithStatus(response, HttpStatus.notFound);
      return;
    }

    if (request.method != 'GET' && request.method != 'HEAD') {
      await _respondWithStatus(response, HttpStatus.methodNotAllowed);
      return;
    }

    final length = await file.length();
    response.statusCode = HttpStatus.ok;
    response.headers.contentType = _contentTypeForPath(filePath);
    response.headers.set(HttpHeaders.contentLengthHeader, length.toString());
    response.headers.set(HttpHeaders.acceptRangesHeader, 'none');

    if (request.method == 'HEAD') {
      await response.close();
      return;
    }

    await response.addStream(file.openRead());
    await response.close();
  }

  Future<void> _respondWithStatus(HttpResponse response, int status) async {
    response.statusCode = status;
    await response.close();
  }

  String _createToken() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final bytes = List<int>.generate(18, (_) => _random.nextInt(chars.length));
    return bytes.map((index) => chars[index]).join();
  }

  ContentType _contentTypeForPath(String filePath) {
    final lower = filePath.toLowerCase();
    if (lower.endsWith('.epub')) {
      return ContentType('application', 'epub+zip');
    }
    if (lower.endsWith('.pdf')) {
      return ContentType('application', 'pdf');
    }
    if (lower.endsWith('.xhtml') ||
        lower.endsWith('.html') ||
        lower.endsWith('.htm')) {
      return ContentType('text', 'html', charset: 'utf-8');
    }
    if (lower.endsWith('.txt')) {
      return ContentType('text', 'plain', charset: 'utf-8');
    }
    return ContentType.binary;
  }
}
