import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:xxread/book_sources/models/registered_book_source.dart';
import 'package:xxread/book_sources/protocol/book_source_protocol.dart';
import 'package:xxread/book_sources/services/book_source_client.dart';
import 'package:xxread/l10n/app_localizations.dart';
import 'package:xxread/pages/book_sources/book_sources_page.dart';
import 'package:xxread/pages/book_sources/widgets/sourced_book_widgets.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('discover scope defaults to all and filters every section',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(430, 1100);
    addTearDown(tester.view.reset);

    final sourceA = _source('source-a', 'Source A');
    final sourceB = _source('source-b', 'Source B');
    SharedPreferences.setMockInitialValues({
      'open_reading_book_sources_v1': jsonEncode(
        [sourceA, sourceB].map((source) => source.toJson()).toList(),
      ),
    });
    final client = _DiscoveryClient();

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: BookSourcesPage(client: client)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('bookSourceDiscoverScopeControl')),
        findsOneWidget);
    expect(find.text('Source A picks'), findsOneWidget);
    expect(find.text('Source B picks'), findsOneWidget);

    await tester.tap(find.byKey(const Key('bookSourceDiscoverScope-source-b')));
    await tester.pumpAndSettle();

    expect(find.text('Source A picks'), findsNothing);
    expect(find.text('Source B picks'), findsOneWidget);

    await tester.tap(find.text('Categories'));
    await tester.pumpAndSettle();

    expect(find.text('Source A category book'), findsNothing);
    expect(find.text('Source B category book'), findsOneWidget);
    expect(client.categoryBrowseSourceIds, ['source-b']);

    await tester.tap(find.text('Latest'));
    await tester.pumpAndSettle();

    expect(find.text('Source A latest 1'), findsNothing);
    expect(find.text('Source B latest 1'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('latest aggregation interleaves sources and caps each contribution', () {
    final sourceA = _source('source-a', 'Source A');
    final sourceB = _source('source-b', 'Source B');
    final batches = [
      [
        _sourcedBook(sourceA, 'A1', DateTime.utc(2026, 7, 18)),
        _sourcedBook(sourceA, 'A2', DateTime.utc(2026, 7, 17)),
        _sourcedBook(sourceA, 'A3', DateTime.utc(2026, 7, 16)),
      ],
      [
        _sourcedBook(sourceB, 'B1', DateTime.utc(2026, 7, 19)),
        _sourcedBook(sourceB, 'B2', DateTime.utc(2026, 7, 15)),
        _sourcedBook(sourceB, 'B3', DateTime.utc(2026, 7, 14)),
      ],
    ];

    final merged = BookSourcesPage.interleaveLatestBatches(
      batches,
      maxItemsPerSource: 2,
    );

    expect(merged.map((result) => result.book.title), ['B1', 'A1', 'B2', 'A2']);
  });
}

class _DiscoveryClient extends BookSourceClient {
  final List<String> categoryBrowseSourceIds = [];

  @override
  Future<BookSourceDiscoveryPage> getDiscovery(
    RegisteredBookSource source,
  ) async {
    return BookSourceDiscoveryPage(
      sections: [
        BookSourceDiscoverySection(
          id: '${source.id}-picks',
          title: '${source.name} picks',
          items: [_book('${source.id}-pick', '${source.name} pick')],
        ),
      ],
    );
  }

  @override
  Future<List<BookSourceCategory>> getCategories(
    RegisteredBookSource source,
  ) async {
    return [
      BookSourceCategory(id: '${source.id}-fiction', name: 'Fiction'),
    ];
  }

  @override
  Future<BookSourceSearchPage> browse(
    RegisteredBookSource source, {
    String? category,
    String sort = 'latest',
    int page = 1,
    int pageSize = 20,
  }) async {
    if (category != null) {
      categoryBrowseSourceIds.add(source.id);
      return _page([
        _book(
          '${source.id}-category-book',
          '${source.name} category book',
        ),
      ]);
    }
    return _page([
      _book(
        '${source.id}-latest-1',
        '${source.name} latest 1',
        updatedAt: source.id == 'source-b'
            ? DateTime.utc(2026, 7, 19)
            : DateTime.utc(2026, 7, 18),
      ),
      _book(
        '${source.id}-latest-2',
        '${source.name} latest 2',
        updatedAt: DateTime.utc(2026, 7, 17),
      ),
    ]);
  }
}

RegisteredBookSource _source(String id, String name) {
  return RegisteredBookSource(
    id: id,
    name: name,
    description: '',
    manifestUrl: Uri.parse('https://example.org/$id/source.json'),
    apiBaseUrl: Uri.parse('https://example.org/$id/api/'),
    protocolVersion: '1.1',
    languages: const ['en'],
    capabilities: const {
      'search',
      'discover',
      'categories',
      'browse',
    },
    enabled: true,
    addedAt: DateTime.utc(2026, 7, 19),
  );
}

SourcedBook _sourcedBook(
  RegisteredBookSource source,
  String title,
  DateTime updatedAt,
) {
  return SourcedBook(
    source: source,
    book: _book(title.toLowerCase(), title, updatedAt: updatedAt),
  );
}

BookSourceBook _book(
  String id,
  String title, {
  DateTime? updatedAt,
}) {
  return BookSourceBook(
    id: id,
    title: title,
    author: 'Author',
    description: '',
    categories: const [],
    updatedAt: updatedAt,
  );
}

BookSourceSearchPage _page(List<BookSourceBook> items) {
  return BookSourceSearchPage(
    items: items,
    page: 1,
    pageSize: items.length,
    total: items.length,
    hasMore: false,
  );
}
