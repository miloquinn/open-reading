import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gbk_codec/gbk_codec.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xxread/book_sources/legado/legado_book_source.dart';
import 'package:xxread/book_sources/legado/legado_request.dart';
import 'package:xxread/book_sources/legado/legado_rule_engine.dart';
import 'package:xxread/book_sources/legado/legado_runtime.dart';
import 'package:xxread/book_sources/protocol/book_source_protocol.dart';
import 'package:xxread/book_sources/services/book_source_network_policy.dart';
import 'package:xxread/book_sources/services/book_source_client.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('LegadoRequestTemplate', () {
    test('parses variables and limited POST options', () {
      final request = LegadoRequestTemplate.parse(
        '/search,{"method":"POST","body":"q={{key}}&p={{page}}",'
        '"charset":"GBK","headers":{"Referer":"https://books.test/"}}',
        baseUri: Uri.parse('https://books.test/root/'),
        variables: const {'key': '剑 来', 'page': '2'},
      );

      expect(request.url, Uri.parse('https://books.test/search'));
      expect(request.method, LegadoRequestMethod.post);
      expect(request.body, 'q=%E5%89%91+%E6%9D%A5&p=2');
      expect(request.charset, 'gbk');
      expect(request.headers['Referer'], 'https://books.test/');
      expect(
        request.headers['Content-Type'],
        'application/x-www-form-urlencoded; charset=gbk',
      );
    });

    test('accepts non-executable single-quoted legacy options', () {
      final request = LegadoRequestTemplate.parse(
        "/search,{'method':'POST','body':'q={{key}}','charset':'gbk'}",
        baseUri: Uri.parse('https://books.test/'),
        variables: const {'key': '剑来'},
      );

      expect(request.method, LegadoRequestMethod.post);
      expect(request.charset, 'gbk');
      expect(request.body, 'q=%E5%89%91%E6%9D%A5');
    });

    test('rejects unsupported methods and controlled headers', () {
      expect(
        () => LegadoRequestTemplate.parse(
          '/,{"method":"PUT"}',
          baseUri: Uri.parse('https://books.test'),
        ),
        throwsA(isA<BookSourceProtocolException>()),
      );
      expect(
        () => LegadoRequestTemplate.parse(
          '/search?offset={{(page-1)*20}}',
          baseUri: Uri.parse('https://books.test'),
          variables: const {'page': '2'},
        ),
        throwsA(isA<BookSourceProtocolException>()),
      );
      expect(
        () => LegadoRequestTemplate.parse(
          '/,{"headers":{"Cookie":"session=secret"}}',
          baseUri: Uri.parse('https://books.test'),
        ),
        throwsA(isA<BookSourceProtocolException>()),
      );
      expect(
        () => LegadoRequestTemplate.parse(
          '/',
          baseUri: Uri.parse('https://books.test'),
          sourceHeaders: const {'Host': 'internal.test'},
        ),
        throwsA(isA<BookSourceProtocolException>()),
      );
    });
  });

  group('LegadoRuleEngine', () {
    const engine = LegadoRuleEngine();

    test(
      'supports legacy DOM rules, CSS, fallback, concatenate and replace',
      () {
        final document = LegadoRuleDocument.parse(
          '<ul class="books">'
          '<li><a href="/1"><b>第一本</b></a><span>甲</span></li>'
          '<li><a href="/2"><b>第二本</b></a><span>乙</span></li>'
          '</ul>',
          Uri.parse('https://books.test/search'),
        );
        final items = engine.evaluateList(
          document,
          document.value,
          'class.books@li!0',
        );

        expect(items, hasLength(1));
        expect(
          engine.evaluateString(
            document,
            items.single,
            '.missing@text||a@b@text',
          ),
          '第二本',
        );
        expect(
          engine.evaluateString(
            document,
            items.single,
            'a@text&&span@text##第二##第 2###',
          ),
          '第 2本乙',
        );
        expect(
          engine.evaluateString(
            document,
            items.single,
            'a@href',
            resolveUrl: true,
          ),
          'https://books.test/2',
        );
      },
    );

    test('supports basic JSON properties, indexes, wildcard and templates', () {
      final document = LegadoRuleDocument.parse(
        '{"books":[{"id":7,"title":"山海"}]}',
        Uri.parse('https://api.test/'),
      );
      final books = engine.evaluateList(
        document,
        document.value,
        r'$.books[*]',
      );

      expect(books, hasLength(1));
      expect(engine.evaluateString(document, books.single, r'$.title'), '山海');
      expect(
        engine.evaluateString(
          document,
          document.value,
          r'@json:$.books[0].title',
        ),
        '山海',
      );
      expect(
        engine.evaluateString(
          document,
          books.single,
          r'/books/{{$.id}}',
          resolveUrl: true,
        ),
        'https://api.test/books/7',
      );
    });

    test(
      'supports CSS attributes, text lookup and regex capture replacement',
      () {
        final document = LegadoRuleDocument.parse(
          '<meta property="og:novel:author" content="甲">'
          '<p data-author="作者：乙<">正文</p><a href="/next">下一页</a>',
          Uri.parse('https://books.test/chapter'),
        );

        expect(
          engine.evaluateString(
            document,
            document.value,
            '[property="og:novel:author"]@content',
          ),
          '甲',
        );
        expect(
          engine.evaluateString(
            document,
            document.value,
            'text.下一页@href',
            resolveUrl: true,
          ),
          'https://books.test/next',
        );
        final paragraph = engine
            .evaluateList(document, document.value, 'p')
            .single;
        expect(
          engine.evaluateString(
            document,
            paragraph,
            r'data-author##作者：([^<]+)<##$1###',
          ),
          '乙',
        );
      },
    );

    test('accepts explicit and additive CSS prefixes', () {
      final document = LegadoRuleDocument.parse(
        '<ul class="librarylist"><li><a class="name">Book</a></li></ul>',
        Uri.parse('https://books.test'),
      );

      expect(
        engine.evaluateList(document, null, '+@css:.librarylist li'),
        hasLength(1),
      );
      expect(engine.evaluateString(document, null, '@css:.name@text'), 'Book');
    });

    test('supports staged regex lists and numbered capture fields', () {
      final document = LegadoRuleDocument.parse(
        '<h2>章节目录</h2><ul>'
        '<li><a href="/1">第一章</a></li>'
        '<li><a href="/2">第二章</a></li></ul>',
        Uri.parse('https://books.test/book'),
      );
      final chapters = engine.evaluateList(
        document,
        null,
        r':章节目录</h2>[\s\S]*?/ul&&href="([^"]*)"[^>]*>([^<]*)',
      );

      expect(chapters, hasLength(2));
      expect(engine.evaluateString(document, chapters.first, r'$2'), '第一章');
      expect(
        engine.evaluateString(
          document,
          chapters.first,
          r'$1',
          resolveUrl: true,
        ),
        'https://books.test/1',
      );
    });

    test('rejects scripts, XPath and complex JSONPath', () {
      for (final rule in const ['@js:result', '//div', r'$..books[*]']) {
        expect(
          () => LegadoRuleEngine.ensureSupported(rule, field: 'test'),
          throwsA(isA<BookSourceProtocolException>()),
        );
      }
    });
  });

  group('LegadoDeclarativeRuntime', () {
    test(
      'normalizes the complete text reading chain to protocol DTOs',
      () async {
        final transport = _FakeTransport({
          'https://books.test/search?q=%E5%89%91%E6%9D%A5&page=1': '''
          <div class="book">
            <a href="/book/1"><span class="name">剑来</span></a>
            <span class="author">烽火</span>
            <span class="kind">玄幻|连载</span>
            <img src="/cover/1.jpg">
          </div>
        ''',
          'https://books.test/book/1': '''
          <h1>剑来</h1><p class="author">烽火</p>
          <p class="intro">少年远游。</p><a class="toc" href="/book/1/toc">目录</a>
        ''',
          'https://books.test/book/1/toc': '''
          <ul id="chapters"><li><a href="/chapter/1">第一章</a></li></ul>
        ''',
          'https://books.test/chapter/1': '''
          <article id="content"><p>正文</p><div class="ad">广告</div></article>
        ''',
        });
        final source = _htmlSource().toRegisteredSource(enabled: true);
        final runtime = LegadoRuntime(transport: transport);

        final search = await runtime.search(source, '剑来');
        expect(search.items.single.id, 'https://books.test/book/1');
        expect(search.items.single.title, '剑来');
        expect(search.items.single.author, '烽火');
        expect(search.items.single.categories, ['玄幻', '连载']);
        expect(
          search.items.single.coverUrl,
          Uri.parse('https://books.test/cover/1.jpg'),
        );

        final book = await runtime.getBook(source, search.items.single.id);
        expect(book.description, '少年远游。');
        final chapters = await runtime.getChapters(source, book.id);
        expect(chapters.single.title, '第一章');
        expect(chapters.single.id, 'https://books.test/chapter/1');
        final content = await runtime.getChapterContent(
          source,
          bookId: book.id,
          chapterId: chapters.single.id,
        );
        expect(content.content, '<p>正文</p>');
        expect(content.contentType, 'text/html');
      },
    );

    test('supports a basic JSON source end to end', () async {
      final transport = _FakeTransport({
        'https://api.test/search?q=%E5%B1%B1%E6%B5%B7':
            '{"books":[{"id":7,"title":"山海","author":"甲"}]}',
        'https://api.test/books/7':
            '{"id":7,"title":"山海","author":"甲","toc":"/toc/7"}',
        'https://api.test/toc/7': '{"chapters":[{"id":9,"title":"开篇"}]}',
        'https://api.test/content/9': '{"body":"第一段\\n第二段"}',
      });
      final source = _jsonSource().toRegisteredSource(enabled: true);
      final runtime = LegadoRuntime(transport: transport);

      final result = await runtime.search(source, '山海');
      final book = await runtime.getBook(source, result.items.single.id);
      final chapters = await runtime.getChapters(source, book.id);
      final content = await runtime.getChapterContent(
        source,
        bookId: book.id,
        chapterId: chapters.single.id,
      );
      expect(book.title, '山海');
      expect(chapters.single.title, '开篇');
      expect(content.content, '第一段\n第二段');
    });

    test('rejects unsupported behavior before sending a request', () async {
      final transport = _FakeTransport(const {});
      final raw = Map<String, dynamic>.from(_htmlSource().raw);
      raw['ruleContent'] = {'content': '@js:result'};

      await expectLater(
        LegadoRuntime(transport: transport).search(
          LegadoBookSource.fromJson(raw).toRegisteredSource(enabled: true),
          'test',
        ),
        throwsA(isA<BookSourceProtocolException>()),
      );
      expect(transport.requests, isEmpty);
    });
  });

  test('unified client blocks compatible requests while the toggle is off', () {
    final client = BookSourceClient();
    addTearDown(client.close);

    expect(
      () => client.search(_htmlSource().toRegisteredSource(enabled: true), 'x'),
      throwsA(
        isA<BookSourceProtocolException>().having(
          (error) => error.message,
          'message',
          contains('disabled'),
        ),
      ),
    );
  });

  group('LegadoHttpTransport', () {
    late HttpServer server;

    tearDown(() async {
      await server.close(force: true);
    });

    test('sends and decodes bounded GBK POST responses', () async {
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final received = Completer<List<int>>();
      server.listen((request) async {
        received.complete(
          await request.fold<List<int>>([], (a, b) => a..addAll(b)),
        );
        request.response.headers.contentType = ContentType(
          'text',
          'plain',
          charset: 'gbk',
        );
        request.response.add(gbk_bytes.encode('结果'));
        await request.response.close();
      });
      final transport = LegadoHttpTransport(
        networkPolicy: const BookSourceNetworkPolicy(allowPrivateNetwork: true),
      );
      addTearDown(transport.close);
      final response = await transport.send(
        LegadoRequestTemplate.parse(
          'http://${server.address.address}:${server.port}/search,'
          '{"method":"POST","body":"关键词=剑来","charset":"gbk"}',
          baseUri: Uri.parse('https://unused.test'),
        ),
      );

      expect(response.body, '结果');
      expect(await received.future, gbk_bytes.encode('关键词=剑来'));
    });

    test(
      'decodes malformed GBK responses without initializing codec decoder',
      () async {
        server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        server.listen((request) async {
          request.response.headers.contentType = ContentType(
            'text',
            'plain',
            charset: 'gbk',
          );
          request.response.add(<int>[0xBD, 0xE1, 0xB9]);
          await request.response.close();
        });
        final transport = LegadoHttpTransport(
          networkPolicy: const BookSourceNetworkPolicy(
            allowPrivateNetwork: true,
          ),
        );
        addTearDown(transport.close);

        final response = await transport.send(
          LegadoRequestTemplate.parse(
            'http://${server.address.address}:${server.port}/',
            baseUri: Uri.parse('https://unused.test'),
          ),
        );

        expect(response.body, startsWith('结'));
        expect(response.body, hasLength(2));
      },
    );

    test('rejects responses over the configured bound', () async {
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((request) async {
        request.response.add(utf8.encode('12345'));
        await request.response.close();
      });
      final transport = LegadoHttpTransport(
        networkPolicy: const BookSourceNetworkPolicy(allowPrivateNetwork: true),
        maxResponseBytes: 4,
      );
      addTearDown(transport.close);

      expect(
        () => transport.send(
          LegadoRequestTemplate.parse(
            'http://${server.address.address}:${server.port}/',
            baseUri: Uri.parse('https://unused.test'),
          ),
        ),
        throwsA(isA<BookSourceProtocolException>()),
      );
    });
  });
}

LegadoBookSource _htmlSource() => LegadoBookSource.fromJson({
  'bookSourceName': 'HTML test',
  'bookSourceUrl': 'https://books.test',
  'searchUrl': '/search?q={{key}}&page={{page}}',
  'ruleSearch': {
    'bookList': 'class.book',
    'name': 'class.name@text',
    'author': 'class.author@text',
    'kind': 'class.kind@text',
    'bookUrl': 'tag.a@href',
    'coverUrl': 'tag.img@src',
  },
  'ruleBookInfo': {
    'name': 'h1@text',
    'author': 'class.author@text',
    'intro': 'class.intro@text',
    'tocUrl': 'class.toc@href',
  },
  'ruleToc': {
    'chapterList': '#chapters@li',
    'chapterName': 'a@text',
    'chapterUrl': 'a@href',
  },
  'ruleContent': {
    'content': '#content@html',
    'replaceRegex': '<div class="ad">.*</div>',
  },
});

LegadoBookSource _jsonSource() => LegadoBookSource.fromJson({
  'bookSourceName': 'JSON test',
  'bookSourceUrl': 'https://api.test',
  'searchUrl': '/search?q={{key}}',
  'ruleSearch': {
    'bookList': r'$.books[*]',
    'name': r'$.title',
    'author': r'$.author',
    'bookUrl': r'/books/{{$.id}}',
  },
  'ruleBookInfo': {
    'name': r'$.title',
    'author': r'$.author',
    'tocUrl': r'$.toc',
  },
  'ruleToc': {
    'chapterList': r'$.chapters[*]',
    'chapterName': r'$.title',
    'chapterUrl': r'/content/{{$.id}}',
  },
  'ruleContent': {'content': r'$.body'},
});

class _FakeTransport implements LegadoTransport {
  _FakeTransport(this.responses);

  final Map<String, String> responses;
  final List<LegadoRequestTemplate> requests = [];

  @override
  Future<LegadoResponse> send(LegadoRequestTemplate request) async {
    requests.add(request);
    final body = responses[request.url.toString()];
    if (body == null) {
      throw StateError('Missing fake response for ${request.url}');
    }
    return LegadoResponse(body: body, finalUri: request.url);
  }
}
