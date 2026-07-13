import 'package:flutter_test/flutter_test.dart';

import 'package:xxread/book_sources/models/registered_book_source.dart';
import 'package:xxread/book_sources/services/book_source_client.dart';

import '../tool/example_book_source_server.dart';

void main() {
  test('example source completes discovery to chapter content over HTTP',
      () async {
    final server = ExampleBookSourceServer();
    final sourceUrl = await server.start(port: 0);
    addTearDown(server.close);

    final client = BookSourceClient();
    final discovered = await client.discover(sourceUrl.toString());
    final source = RegisteredBookSource.fromManifest(
      manifest: discovered.manifest,
      manifestUrl: discovered.manifestUrl,
    );

    expect(source.id, 'dev.open-reading.example-source');
    expect(
      source.capabilities,
      containsAll([
        'search',
        'discover',
        'categories',
        'browse',
        'catalog',
        'content',
      ]),
    );

    final discovery = await client.getDiscovery(source);
    expect(discovery.sections, isNotEmpty);
    expect(discovery.sections.first.items, isNotEmpty);

    final categories = await client.getCategories(source);
    expect(categories, isNotEmpty);

    final browsePage = await client.browse(
      source,
      category: categories.first.id,
    );
    expect(browsePage.items, isNotEmpty);

    final searchPage = await client.search(source, '协议');
    expect(searchPage.total, 1);
    expect(searchPage.items.single.id, 'protocol-garden');

    final book = await client.getBook(source, searchPage.items.single.id);
    expect(book.title, '协议花园');

    final chapters = await client.getChapters(source, book.id);
    expect(chapters, hasLength(2));
    expect(chapters.first.id, 'seed');

    final content = await client.getChapterContent(
      source,
      bookId: book.id,
      chapterId: chapters.first.id,
    );
    expect(content.contentType, 'text/plain');
    expect(content.content, contains('你遵循什么协议'));
  });
}
