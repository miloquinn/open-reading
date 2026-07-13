import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// A dependency-free reference server for Open Reading Source Protocol v1.
///
/// Run it from the repository root:
///
/// ```bash
/// dart run tool/example_book_source_server.dart
/// ```
///
/// Then add `http://127.0.0.1:8787` from the Sources page.
class ExampleBookSourceServer {
  final String sourceId;
  final String sourceName;
  HttpServer? _server;

  ExampleBookSourceServer({
    this.sourceId = 'dev.open-reading.example-source',
    this.sourceName = 'Open Reading 示例书源',
  });

  Uri get baseUri {
    final server = _server;
    if (server == null) {
      throw StateError('The example source server has not been started.');
    }
    return Uri(
      scheme: 'http',
      host: server.address.address,
      port: server.port,
      path: '/',
    );
  }

  Future<Uri> start({
    InternetAddress? address,
    int port = 8787,
  }) async {
    if (_server != null) return baseUri;
    _server = await HttpServer.bind(
      address ?? InternetAddress.loopbackIPv4,
      port,
    );
    unawaited(_serve(_server!));
    return baseUri;
  }

  Future<void> close({bool force = true}) async {
    final server = _server;
    _server = null;
    await server?.close(force: force);
  }

  Future<void> _serve(HttpServer server) async {
    await for (final request in server) {
      try {
        await _handle(request);
      } catch (error, stackTrace) {
        stderr.writeln('Example source request failed: $error');
        stderr.writeln(stackTrace);
        _json(
          request.response,
          HttpStatus.internalServerError,
          {
            'error': {
              'code': 'INTERNAL_ERROR',
              'message': 'The example source could not process the request.',
            },
          },
        );
      }
    }
  }

  Future<void> _handle(HttpRequest request) async {
    _applyCors(request.response);
    if (request.method == 'OPTIONS') {
      request.response.statusCode = HttpStatus.noContent;
      await request.response.close();
      return;
    }
    if (request.method != 'GET') {
      _error(
        request.response,
        HttpStatus.methodNotAllowed,
        'METHOD_NOT_ALLOWED',
        'Only GET is supported by this example source.',
      );
      return;
    }

    final segments = request.uri.pathSegments;
    if (request.uri.path == '/.well-known/open-reading-source.json') {
      _json(request.response, HttpStatus.ok, _manifest(request));
      return;
    }
    if (segments.length == 3 &&
        segments[0] == 'api' &&
        segments[1] == 'v1' &&
        segments[2] == 'search') {
      _search(request);
      return;
    }
    if (segments.length == 3 &&
        segments[0] == 'api' &&
        segments[1] == 'v1' &&
        segments[2] == 'discover') {
      _discover(request.response);
      return;
    }
    if (segments.length == 3 &&
        segments[0] == 'api' &&
        segments[1] == 'v1' &&
        segments[2] == 'categories') {
      _categories(request.response);
      return;
    }
    if (segments.length == 3 &&
        segments[0] == 'api' &&
        segments[1] == 'v1' &&
        segments[2] == 'browse') {
      _browse(request);
      return;
    }
    if (segments.length >= 4 &&
        segments[0] == 'api' &&
        segments[1] == 'v1' &&
        segments[2] == 'books') {
      final bookId = Uri.decodeComponent(segments[3]);
      if (segments.length == 4) {
        _bookDetails(request.response, bookId);
        return;
      }
      if (segments.length == 5 && segments[4] == 'chapters') {
        _chapters(request.response, bookId);
        return;
      }
      if (segments.length == 6 && segments[4] == 'chapters') {
        _chapterContent(
          request.response,
          bookId,
          Uri.decodeComponent(segments[5]),
        );
        return;
      }
    }

    _error(
      request.response,
      HttpStatus.notFound,
      'ROUTE_NOT_FOUND',
      'The requested endpoint does not exist.',
    );
  }

  Map<String, Object> _manifest(HttpRequest request) {
    final publicBaseUri = request.requestedUri.replace(
      path: '/',
      query: null,
      fragment: null,
    );
    return {
      'protocol': 'open-reading-source',
      'protocolVersion': '1.0',
      'id': sourceId,
      'name': sourceName,
      'description': '仓库内置的本地协议测试书源，仅包含原创示例文本。',
      'apiBaseUrl': publicBaseUri.resolve('api/').toString(),
      'websiteUrl': publicBaseUri.toString(),
      'languages': ['zh-CN', 'en'],
      'capabilities': [
        'search',
        'discover',
        'categories',
        'browse',
        'detail',
        'catalog',
        'content',
      ],
    };
  }

  void _search(HttpRequest request) {
    final query = (request.uri.queryParameters['q'] ?? '').trim().toLowerCase();
    final page = _positiveInt(request.uri.queryParameters['page'], fallback: 1);
    final pageSize = _positiveInt(
      request.uri.queryParameters['pageSize'],
      fallback: 20,
    ).clamp(1, 100);
    final matched = _books.values.where((entry) {
      if (query.isEmpty) return true;
      final book = entry.book;
      return '${book['title']} ${book['author']}'.toLowerCase().contains(query);
    }).toList(growable: false);
    final start = (page - 1) * pageSize;
    final items = start >= matched.length
        ? const <Map<String, Object>>[]
        : matched
            .skip(start)
            .take(pageSize)
            .map((entry) => entry.book)
            .toList(growable: false);

    _json(request.response, HttpStatus.ok, {
      'items': items,
      'page': page,
      'pageSize': pageSize,
      'total': matched.length,
      'hasMore': start + items.length < matched.length,
    });
  }

  void _discover(HttpResponse response) {
    final books = _books.values.map((entry) => entry.book).toList();
    _json(response, HttpStatus.ok, {
      'sections': [
        {
          'id': 'featured',
          'title': '编辑精选',
          'items': books,
        },
        {
          'id': 'recent',
          'title': '最近更新',
          'items': books.reversed.toList(growable: false),
        },
      ],
    });
  }

  void _categories(HttpResponse response) {
    final categories = <String>{};
    for (final entry in _books.values) {
      final values = entry.book['categories'];
      if (values is List) categories.addAll(values.whereType<String>());
    }
    _json(response, HttpStatus.ok, {
      'items': categories
          .map((category) => {'id': category, 'name': category})
          .toList(growable: false),
    });
  }

  void _browse(HttpRequest request) {
    final category = request.uri.queryParameters['category']?.trim();
    final sort = request.uri.queryParameters['sort'] ?? 'latest';
    final page = _positiveInt(request.uri.queryParameters['page'], fallback: 1);
    final pageSize = _positiveInt(
      request.uri.queryParameters['pageSize'],
      fallback: 20,
    ).clamp(1, 100);
    final matched = _books.values
        .where((entry) {
          if (category == null || category.isEmpty) return true;
          final values = entry.book['categories'];
          return values is List && values.contains(category);
        })
        .map((entry) => entry.book)
        .toList();
    if (sort == 'latest') {
      matched.sort(
        (a, b) => '${b['updatedAt']}'.compareTo('${a['updatedAt']}'),
      );
    }
    final start = (page - 1) * pageSize;
    final items = start >= matched.length
        ? const <Map<String, Object>>[]
        : matched.skip(start).take(pageSize).toList(growable: false);
    _json(request.response, HttpStatus.ok, {
      'items': items,
      'page': page,
      'pageSize': pageSize,
      'total': matched.length,
      'hasMore': start + items.length < matched.length,
    });
  }

  void _bookDetails(HttpResponse response, String bookId) {
    final entry = _books[bookId];
    if (entry == null) {
      _notFound(
          response, 'BOOK_NOT_FOUND', 'The requested book was not found.');
      return;
    }
    _json(response, HttpStatus.ok, entry.book);
  }

  void _chapters(HttpResponse response, String bookId) {
    final entry = _books[bookId];
    if (entry == null) {
      _notFound(
          response, 'BOOK_NOT_FOUND', 'The requested book was not found.');
      return;
    }
    _json(response, HttpStatus.ok, {
      'items': entry.chapters
          .map((chapter) => chapter.metadata)
          .toList(growable: false),
    });
  }

  void _chapterContent(
    HttpResponse response,
    String bookId,
    String chapterId,
  ) {
    final entry = _books[bookId];
    if (entry == null) {
      _notFound(
          response, 'BOOK_NOT_FOUND', 'The requested book was not found.');
      return;
    }
    final chapter =
        entry.chapters.where((item) => item.id == chapterId).firstOrNull;
    if (chapter == null) {
      _notFound(
        response,
        'CHAPTER_NOT_FOUND',
        'The requested chapter was not found.',
      );
      return;
    }
    _json(response, HttpStatus.ok, {
      'bookId': bookId,
      'chapterId': chapter.id,
      'title': chapter.title,
      'contentType': 'text/plain',
      'content': chapter.content,
    });
  }

  void _notFound(HttpResponse response, String code, String message) {
    _error(response, HttpStatus.notFound, code, message);
  }

  void _error(
    HttpResponse response,
    int status,
    String code,
    String message,
  ) {
    _json(response, status, {
      'error': {'code': code, 'message': message},
    });
  }

  void _json(HttpResponse response, int status, Object body) {
    response
      ..statusCode = status
      ..headers.contentType = ContentType.json
      ..write(jsonEncode(body))
      ..close();
  }

  void _applyCors(HttpResponse response) {
    response.headers
      ..set('Access-Control-Allow-Origin', '*')
      ..set('Access-Control-Allow-Methods', 'GET, OPTIONS')
      ..set(
        'Access-Control-Allow-Headers',
        'Content-Type, X-Open-Reading-Protocol',
      );
  }

  int _positiveInt(String? value, {required int fallback}) {
    final parsed = int.tryParse(value ?? '');
    return parsed == null || parsed < 1 ? fallback : parsed;
  }
}

class _ExampleBook {
  final Map<String, Object> book;
  final List<_ExampleChapter> chapters;

  const _ExampleBook({required this.book, required this.chapters});
}

class _ExampleChapter {
  final String id;
  final String title;
  final int order;
  final String content;

  const _ExampleChapter({
    required this.id,
    required this.title,
    required this.order,
    required this.content,
  });

  Map<String, Object> get metadata => {
        'id': id,
        'title': title,
        'order': order,
        'updatedAt': '2026-07-11T00:00:00Z',
      };
}

const Map<String, _ExampleBook> _books = {
  'protocol-garden': _ExampleBook(
    book: {
      'id': 'protocol-garden',
      'title': '协议花园',
      'author': 'Open Reading',
      'description': '一本用于验证开放书源协议的原创微型故事。',
      'categories': ['原创', '测试'],
      'status': 'completed',
      'latestChapter': '第二章 共同的语言',
      'updatedAt': '2026-07-11T00:00:00Z',
    },
    chapters: [
      _ExampleChapter(
        id: 'seed',
        title: '第一章 一颗种子',
        order: 1,
        content: '清晨，阅读器收到了一颗没有名字的种子。'
            '它没有猜测种子会开什么花，而是先询问：你遵循什么协议？',
      ),
      _ExampleChapter(
        id: 'common-language',
        title: '第二章 共同的语言',
        order: 2,
        content: '当发现、搜索、目录和正文都有了共同的语言，'
            '花园里的每一位开发者都可以种下自己的故事。',
      ),
    ],
  ),
  'quiet-library': _ExampleBook(
    book: {
      'id': 'quiet-library',
      'title': '安静的书架',
      'author': 'Open Reading',
      'description': '用于测试多结果搜索和书籍详情接口的第二本原创示例。',
      'categories': ['原创', '短篇'],
      'status': 'completed',
      'latestChapter': '第一章 夜读',
      'updatedAt': '2026-07-11T00:00:00Z',
    },
    chapters: [
      _ExampleChapter(
        id: 'night-reading',
        title: '第一章 夜读',
        order: 1,
        content: '夜色落下时，书架没有发出声音。'
            '只有被翻开的那一页，替远方的作者继续说话。',
      ),
    ],
  ),
};

Future<void> main(List<String> arguments) async {
  final port = _readPort(arguments);
  final address = _readAddress(arguments);
  final server = ExampleBookSourceServer(
    sourceId:
        _readOption(arguments, '--id') ?? 'dev.open-reading.example-source',
    sourceName: _readOption(arguments, '--name') ?? 'Open Reading 示例书源',
  );
  final uri = await server.start(address: address, port: port);
  stdout.writeln('Open Reading example source is running.');
  if (address.address == InternetAddress.anyIPv4.address) {
    stdout.writeln('Local source URL: http://127.0.0.1:$port');
    stdout.writeln('Android emulator URL: http://10.0.2.2:$port');
    await _printLanSourceUrls(port);
  } else {
    stdout.writeln('Source URL: $uri');
  }
  stdout.writeln('Press Ctrl+C to stop.');

  final stopping = Completer<void>();
  StreamSubscription<ProcessSignal>? sigint;
  StreamSubscription<ProcessSignal>? sigterm;
  sigint = ProcessSignal.sigint.watch().listen((_) => stopping.complete());
  if (!Platform.isWindows) {
    sigterm = ProcessSignal.sigterm.watch().listen((_) => stopping.complete());
  }
  await stopping.future;
  await sigint.cancel();
  await sigterm?.cancel();
  await server.close();
}

int _readPort(List<String> arguments) {
  final index = arguments.indexOf('--port');
  if (index < 0 || index + 1 >= arguments.length) return 8787;
  return int.tryParse(arguments[index + 1]) ?? 8787;
}

InternetAddress _readAddress(List<String> arguments) {
  final index = arguments.indexOf('--host');
  if (index < 0 || index + 1 >= arguments.length) {
    return InternetAddress.loopbackIPv4;
  }
  final host = arguments[index + 1].trim();
  if (host == '0.0.0.0' || host == '*') return InternetAddress.anyIPv4;
  return InternetAddress(host);
}

String? _readOption(List<String> arguments, String option) {
  final index = arguments.indexOf(option);
  if (index < 0 || index + 1 >= arguments.length) return null;
  final value = arguments[index + 1].trim();
  return value.isEmpty ? null : value;
}

Future<void> _printLanSourceUrls(int port) async {
  final interfaces = await NetworkInterface.list(
    type: InternetAddressType.IPv4,
    includeLoopback: false,
  );
  final addresses = interfaces
      .expand((interface) => interface.addresses)
      .map((address) => address.address)
      .toSet()
      .toList()
    ..sort();
  for (final address in addresses) {
    stdout.writeln('LAN source URL: http://$address:$port');
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}
