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

    test('parses optional discovery and category responses', () {
      final discovery = BookSourceDiscoveryPage.fromJson({
        'sections': [
          {
            'id': 'featured',
            'title': 'Featured',
            'items': [
              {'id': 'book-1', 'title': 'A Book'}
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
  });
}
