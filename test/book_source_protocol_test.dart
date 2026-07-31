import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:xxread/book_sources/models/registered_book_source.dart';
import 'package:xxread/book_sources/protocol/book_source_protocol.dart';
import 'package:xxread/book_sources/services/book_source_client.dart';
import 'package:xxread/book_sources/services/book_source_chapter_cache.dart';
import 'package:xxread/book_sources/services/book_source_network_policy.dart';
import 'package:xxread/book_sources/services/book_source_registry.dart';

class _ManifestClient extends BookSourceClient {
  _ManifestClient(this.source);

  final DiscoveredBookSource source;

  @override
  Future<DiscoveredBookSource> discover(String input) async => source;
}

void main() {
  group('Open Reading Source Protocol', () {
    test('parses a compatible manifest', () {
      final manifest = BookSourceManifest.fromJson({
        'protocol': 'open-reading-source',
        'protocolVersion': '1.2',
        'id': 'org.example.books',
        'name': 'Example Books',
        'apiBaseUrl': 'https://example.org/api/',
        'operatorName': 'Example Library',
        'contactUrl': 'https://example.org/contact',
        'contentLicense': 'CC BY 4.0',
        'rightsStatement': 'Licensed public catalog.',
        'languages': ['zh-CN'],
        'capabilities': ['search', 'detail', 'catalog', 'content'],
      });

      expect(manifest.id, 'org.example.books');
      expect(manifest.apiBaseUrl.toString(), 'https://example.org/api/');
      expect(manifest.supports('content'), isTrue);
      expect(manifest.operatorName, 'Example Library');
      expect(manifest.contactUrl?.toString(), 'https://example.org/contact');
      expect(manifest.contentLicense, 'CC BY 4.0');
      expect(manifest.rightsStatement, 'Licensed public catalog.');
      expect(manifest.maxCatalogPageSize, isNull);
    });

    test('honors a declared maxCatalogPageSize exactly, even below 100', () {
      // The 100-1000 range in ORSP §3 is a requirement on what a source is
      // supposed to declare, not something the client should force a
      // smaller value up to — a source that declares less still means it,
      // and requesting more than it declared gets rejected.
      final manifest = BookSourceManifest.fromJson({
        'protocol': 'open-reading-source',
        'protocolVersion': '1.1',
        'id': 'org.example.books',
        'name': 'Example Books',
        'apiBaseUrl': 'https://example.org/api/',
        'capabilities': ['search', 'detail', 'catalog', 'content'],
        'maxCatalogPageSize': 40,
      });

      expect(manifest.maxCatalogPageSize, 40);
    });

    test('rejects an incompatible major version', () {
      expect(
        () => BookSourceManifest.fromJson({
          'protocol': 'open-reading-source',
          'protocolVersion': '2.0',
          'id': 'org.example.books',
          'name': 'Example Books',
          'apiBaseUrl': 'https://example.org/api/',
          'capabilities': ['search', 'detail', 'catalog', 'content'],
        }),
        throwsA(isA<BookSourceProtocolException>()),
      );
    });

    test('rejects malformed protocol versions', () {
      for (final version in ['1', '1.', '1.foo', '1.4.0']) {
        expect(
          () => BookSourceManifest.fromJson({
            'protocol': 'open-reading-source',
            'protocolVersion': version,
            'id': 'org.example.books',
            'name': 'Example Books',
            'apiBaseUrl': 'https://example.org/api/',
            'capabilities': ['search', 'detail', 'catalog', 'content'],
          }),
          throwsA(isA<BookSourceProtocolException>()),
          reason: version,
        );
      }
    });

    test('rejects a manifest that omits a core reading capability', () {
      expect(
        () => BookSourceManifest.fromJson({
          'protocol': 'open-reading-source',
          'protocolVersion': '1.3',
          'id': 'org.example.books',
          'name': 'Example Books',
          'apiBaseUrl': 'https://example.org/api/',
          'capabilities': ['search', 'catalog', 'content'],
        }),
        throwsA(isA<BookSourceProtocolException>()),
      );
    });

    test('parses a search response', () {
      final page = BookSourceSearchPage.fromJson({
        'items': [
          {
            'id': 'book-1',
            'title': 'A Book',
            'author': 'A Writer',
            'categories': ['Fiction'],
          },
        ],
        'page': 1,
        'pageSize': 20,
        'total': 1,
        'hasMore': false,
      });

      expect(page.items.single.title, 'A Book');
      expect(page.total, 1);
      expect(page.hasMore, isFalse);
    });

    test('parses optional discovery and category responses', () {
      final discovery = BookSourceDiscoveryPage.fromJson({
        'sections': [
          {
            'id': 'featured',
            'title': 'Featured',
            'items': [
              {'id': 'book-1', 'title': 'A Book'},
            ],
          },
        ],
      });
      final category = BookSourceCategory.fromJson({
        'id': 'fiction',
        'name': 'Fiction',
      });

      expect(discovery.sections.single.id, 'featured');
      expect(discovery.sections.single.items.single.title, 'A Book');
      expect(category.name, 'Fiction');
    });

    test('allows chapter content to omit its duplicated title', () {
      final content = BookSourceChapterContent.fromJson({
        'bookId': 'book-1',
        'chapterId': 'chapter-1',
        'contentType': 'text/html',
        'content': '<p>Chapter body</p>',
      });

      expect(content.title, isEmpty);
      expect(content.content, '<p>Chapter body</p>');
    });

    test('parses a legacy single-page chapter response', () {
      final page = BookSourceChapterPage.fromJson({
        'items': [
          {'id': 'chapter-1', 'title': 'Chapter One', 'order': 1},
          {'id': 'chapter-2', 'title': 'Chapter Two', 'order': 2},
        ],
      });

      expect(page.items, hasLength(2));
      expect(page.page, 1);
      expect(page.pageSize, 2);
      expect(page.hasMore, isFalse);
      expect(page.total, isNull);
    });

    test('parses a paginated chapter response', () {
      final page = BookSourceChapterPage.fromJson({
        'items': [
          {'id': 'chapter-1', 'title': 'Chapter One', 'order': 1},
        ],
        'page': 1,
        'pageSize': 1,
        'total': 3,
        'hasMore': true,
      });

      expect(page.items.single.id, 'chapter-1');
      expect(page.pageSize, 1);
      expect(page.total, 3);
      expect(page.hasMore, isTrue);
    });

    test('normalizes service and discovery URLs', () {
      expect(
        BookSourceClient.normalizeManifestUri('https://example.org').toString(),
        'https://example.org/.well-known/open-reading-source.json',
      );
      expect(
        BookSourceClient.normalizeManifestUri(
          'https://example.org/source',
        ).toString(),
        'https://example.org/source/.well-known/open-reading-source.json',
      );
      expect(
        BookSourceClient.normalizeManifestUri(
          'https://example.org/source.json',
        ).toString(),
        'https://example.org/source.json',
      );
    });

    test('rejects invalid persisted source identity and URLs', () {
      expect(
        () => RegisteredBookSource.fromJson({
          ..._registeredSource('org.example.books', 'Example').toJson(),
          'name': '',
        }),
        throwsA(isA<BookSourceProtocolException>()),
      );
      expect(
        () => RegisteredBookSource.fromJson({
          ..._registeredSource('org.example.books', 'Example').toJson(),
          'apiBaseUrl': 'file:///tmp/source',
        }),
        throwsA(isA<BookSourceProtocolException>()),
      );
    });

    test('rejects a detail response for a different book', () async {
      final adapter = _JsonSequenceAdapter([
        '{"id":"other-book","title":"Wrong book"}',
      ]);
      final client = _clientWithAdapter(adapter);

      await expectLater(
        client.getBook(
          _registeredSource('org.example.books', 'Example'),
          'book-1',
        ),
        throwsA(isA<BookSourceProtocolException>()),
      );
    });

    test(
      'does not cache a chapter response with mismatched identity',
      () async {
        final directory = await Directory.systemTemp.createTemp(
          'book-source-identity-test-',
        );
        addTearDown(() => directory.delete(recursive: true));
        BookSourceChapterCache.clearMemory();
        final adapter = _JsonSequenceAdapter([
          '{"bookId":"other-book","chapterId":"other-chapter",'
              '"contentType":"text/plain","content":"wrong"}',
          '{"bookId":"book-1","chapterId":"chapter-1",'
              '"contentType":"text/plain","content":"correct"}',
        ]);
        final client = _clientWithAdapter(
          adapter,
          chapterCache: BookSourceChapterCache(cacheDirectory: directory),
        );
        final source = _registeredSource('org.example.books', 'Example');

        await expectLater(
          client.getChapterContent(
            source,
            bookId: 'book-1',
            chapterId: 'chapter-1',
          ),
          throwsA(isA<BookSourceProtocolException>()),
        );
        final content = await client.getChapterContent(
          source,
          bookId: 'book-1',
          chapterId: 'chapter-1',
        );

        expect(content.content, 'correct');
        expect(adapter.requestCount, 2);
      },
    );
  });

  group('BookSourceRegistry', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('persists enabled state without changing source identity', () async {
      final registry = BookSourceRegistry();
      final source = RegisteredBookSource(
        id: 'org.example.books',
        name: 'Example Books',
        description: 'Example',
        manifestUrl: Uri.parse(
          'https://example.org/.well-known/open-reading-source.json',
        ),
        apiBaseUrl: Uri.parse('https://example.org/api/'),
        protocolVersion: '1.0',
        languages: const ['en'],
        capabilities: const {'search'},
        operatorName: 'Example Library',
        contactUrl: Uri.parse('https://example.org/contact'),
        contentLicense: 'Public Domain',
        rightsStatement: 'Public-domain works.',
        enabled: true,
        addedAt: DateTime.utc(2026, 7, 11),
      );

      await registry.upsert(source);
      final disabled = await registry.setEnabled(source.id, false);

      expect(disabled.single.id, source.id);
      expect(disabled.single.enabled, isFalse);
      expect((await registry.load()).single.enabled, isFalse);
      final restored = (await registry.load()).single;
      expect(restored.operatorName, 'Example Library');
      expect(restored.contactUrl?.toString(), 'https://example.org/contact');
      expect(restored.contentLicense, 'Public Domain');
      expect(restored.rightsStatement, 'Public-domain works.');
    });

    test('serializes concurrent mutations without losing a source', () async {
      final registry = BookSourceRegistry();
      final first = _registeredSource('org.example.first', 'First');
      final second = _registeredSource('org.example.second', 'Second');

      await Future.wait([registry.upsert(first), registry.upsert(second)]);

      expect((await registry.load()).map((source) => source.id), {
        first.id,
        second.id,
      });
    });

    test(
      'refreshes a manifest without changing enabled state or added time',
      () async {
        final registry = BookSourceRegistry();
        final original = RegisteredBookSource(
          id: 'org.example.books',
          name: 'Old name',
          description: 'Old description',
          manifestUrl: Uri.parse(
            'https://example.org/.well-known/open-reading-source.json',
          ),
          apiBaseUrl: Uri.parse('https://example.org/api/'),
          protocolVersion: '1.4',
          languages: const ['en'],
          capabilities: const {'search', 'detail', 'catalog', 'content'},
          enabled: false,
          addedAt: DateTime.utc(2026, 7, 11),
        );
        await registry.upsert(original);
        final manifest = BookSourceManifest.fromJson({
          'protocol': 'open-reading-source',
          'protocolVersion': '1.4',
          'id': 'org.example.books',
          'name': 'New name',
          'description': 'New description',
          'apiBaseUrl': 'https://example.org/api/',
          'capabilities': [
            'search',
            'discover',
            'categories',
            'browse',
            'detail',
            'catalog',
            'content',
          ],
        });

        final sources = await registry.refresh(
          original,
          _ManifestClient(
            DiscoveredBookSource(
              manifestUrl: original.manifestUrl,
              manifest: manifest,
            ),
          ),
        );

        expect(sources.single.name, 'New name');
        expect(sources.single.capabilities, contains('browse'));
        expect(sources.single.enabled, isFalse);
        expect(sources.single.addedAt, original.addedAt);
      },
    );
  });
}

BookSourceClient _clientWithAdapter(
  HttpClientAdapter adapter, {
  BookSourceChapterCache? chapterCache,
}) {
  final dio = Dio()..httpClientAdapter = adapter;
  return BookSourceClient(
    dio: dio,
    chapterCache: chapterCache,
    networkPolicy: BookSourceNetworkPolicy(
      lookup: (_) async => [InternetAddress('93.184.216.34')],
    ),
  );
}

class _JsonSequenceAdapter implements HttpClientAdapter {
  _JsonSequenceAdapter(this.responses);

  final List<String> responses;
  int requestCount = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final body = responses[requestCount++];
    return ResponseBody.fromString(
      body,
      HttpStatus.ok,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

RegisteredBookSource _registeredSource(String id, String name) {
  return RegisteredBookSource(
    id: id,
    name: name,
    description: '',
    manifestUrl: Uri.parse('https://example.org/$id/source.json'),
    apiBaseUrl: Uri.parse('https://example.org/$id/api/'),
    protocolVersion: '1.5',
    languages: const ['en'],
    capabilities: const {'search', 'detail', 'catalog', 'content'},
    enabled: true,
    addedAt: DateTime.utc(2026, 7, 31),
  );
}
