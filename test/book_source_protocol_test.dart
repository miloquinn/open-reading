import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:xxread/book_sources/models/registered_book_source.dart';
import 'package:xxread/book_sources/protocol/book_source_protocol.dart';
import 'package:xxread/book_sources/services/book_source_client.dart';
import 'package:xxread/book_sources/services/book_source_registry.dart';

void main() {
  group('Open Reading Source Protocol', () {
    test('parses a compatible manifest', () {
      final manifest = BookSourceManifest.fromJson({
        'protocol': 'open-reading-source',
        'protocolVersion': '1.2',
        'id': 'org.example.books',
        'name': 'Example Books',
        'apiBaseUrl': 'https://example.org/api/',
        'languages': ['zh-CN'],
        'capabilities': ['search', 'detail', 'catalog', 'content'],
      });

      expect(manifest.id, 'org.example.books');
      expect(manifest.apiBaseUrl.toString(), 'https://example.org/api/');
      expect(manifest.supports('content'), isTrue);
    });

    test('rejects an incompatible major version', () {
      expect(
        () => BookSourceManifest.fromJson({
          'protocol': 'open-reading-source',
          'protocolVersion': '2.0',
          'id': 'org.example.books',
          'name': 'Example Books',
          'apiBaseUrl': 'https://example.org/api/',
          'capabilities': ['search'],
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

    test('normalizes service and discovery URLs', () {
      expect(
        BookSourceClient.normalizeManifestUri('https://example.org').toString(),
        'https://example.org/.well-known/open-reading-source.json',
      );
      expect(
        BookSourceClient.normalizeManifestUri('https://example.org/source')
            .toString(),
        'https://example.org/source/.well-known/open-reading-source.json',
      );
      expect(
        BookSourceClient.normalizeManifestUri(
          'https://example.org/source.json',
        ).toString(),
        'https://example.org/source.json',
      );
    });
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
        enabled: true,
        addedAt: DateTime.utc(2026, 7, 11),
      );

      await registry.upsert(source);
      final disabled = await registry.setEnabled(source.id, false);

      expect(disabled.single.id, source.id);
      expect(disabled.single.enabled, isFalse);
      expect((await registry.load()).single.enabled, isFalse);
    });
  });
}
