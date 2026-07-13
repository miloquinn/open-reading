import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:xxread/book_sources/models/registered_book_source.dart';
import 'package:xxread/book_sources/protocol/book_source_protocol.dart';
import 'package:xxread/book_sources/services/book_source_client.dart';
import 'package:xxread/book_sources/services/book_source_shelf_service.dart';
import 'package:xxread/l10n/app_localizations.dart';
import 'package:xxread/pages/book_source_search_page.dart';
import 'package:xxread/pages/book_sources_page.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('discover page shows the empty-source call to action',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 1000);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: BookSourcesPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No sources yet'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('search page focuses the query field and searches on submit',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 1000);
    addTearDown(tester.view.reset);

    final client = _PagingBookSourceClient();
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: SourceSearchPage(
          sources: [_source()],
          client: client,
          shelfService: BookSourceShelfService(client: client),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final queryField = find.byKey(const Key('bookSourceQueryControl'));
    expect(
      tester.widget<TextField>(queryField).focusNode?.hasFocus,
      isTrue,
    );

    await tester.enterText(queryField, 'test');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    expect(client.requestedPages, isNotEmpty);
    expect(find.text('Book 1'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('loads the next source page when search results reach the end',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 1000);
    addTearDown(tester.view.reset);

    final source = _source();
    SharedPreferences.setMockInitialValues({
      'open_reading_book_sources_v1': jsonEncode([source.toJson()]),
    });
    final client = _PagingBookSourceClient();
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: SourceSearchPage(
          sources: [source],
          client: client,
          shelfService: BookSourceShelfService(client: client),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final queryField = find.byKey(const Key('bookSourceQueryControl'));
    await tester.enterText(queryField, 'test');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    if (client.requestedPages.length == 1) {
      await tester.drag(
        find.byType(CustomScrollView),
        const Offset(0, -1600),
      );
      await tester.pumpAndSettle();
    }

    expect(client.requestedPages, [1, 2]);
    // 第 11 本书在首屏之外，滚到底部让 Sliver 构建它再断言。
    await tester.drag(
      find.byType(CustomScrollView),
      const Offset(0, -1600),
    );
    await tester.pumpAndSettle();
    expect(find.text('Book 11'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('clear button resets search results', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 1000);
    addTearDown(tester.view.reset);

    final client = _PagingBookSourceClient();
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: SourceSearchPage(
          sources: [_source()],
          client: client,
          shelfService: BookSourceShelfService(client: client),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final queryField = find.byKey(const Key('bookSourceQueryControl'));
    await tester.enterText(queryField, 'test');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(find.text('Book 1'), findsOneWidget);

    await tester.tap(find.byKey(const Key('bookSourceSearchClearButton')));
    await tester.pumpAndSettle();

    expect(find.text('Book 1'), findsNothing);
    expect(
      tester.widget<TextField>(queryField).controller?.text,
      isEmpty,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('scope chips switch between all sources and a single source',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 1000);
    addTearDown(tester.view.reset);

    final sourceA = _source();
    final sourceB = RegisteredBookSource(
      id: 'source-b',
      name: 'Source B',
      description: '',
      manifestUrl: Uri.parse('https://example.org/b/source.json'),
      apiBaseUrl: Uri.parse('https://example.org/b/api/'),
      protocolVersion: '1.1',
      languages: const ['en'],
      capabilities: const {'search'},
      enabled: true,
      addedAt: DateTime.utc(2026, 7, 13),
    );
    final client = _ScopeTrackingClient();
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: SourceSearchPage(
          sources: [sourceA, sourceB],
          client: client,
          shelfService: BookSourceShelfService(client: client),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 默认“全部”：两个书源都被请求。
    final queryField = find.byKey(const Key('bookSourceQueryControl'));
    await tester.enterText(queryField, 'test');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(client.searchedSourceIds, ['source-a', 'source-b']);

    // 选中单个书源 Chip：自动用当前关键词只搜该书源。
    client.searchedSourceIds.clear();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Source B'));
    await tester.pumpAndSettle();
    expect(client.searchedSourceIds, ['source-b']);
    expect(tester.takeException(), isNull);
  });
}

class _ScopeTrackingClient extends BookSourceClient {
  final List<String> searchedSourceIds = [];

  @override
  Future<BookSourceSearchPage> search(
    RegisteredBookSource source,
    String query, {
    int page = 1,
    int pageSize = 20,
  }) async {
    searchedSourceIds.add(source.id);
    return BookSourceSearchPage(
      items: [
        BookSourceBook(
          id: '${source.id}-book',
          title: 'Book of ${source.name}',
          author: 'Author',
          description: '',
          categories: const [],
        ),
      ],
      page: page,
      pageSize: pageSize,
      total: 1,
      hasMore: false,
    );
  }
}

RegisteredBookSource _source() => RegisteredBookSource(
      id: 'source-a',
      name: 'Source A',
      description: '',
      manifestUrl: Uri.parse('https://example.org/source.json'),
      apiBaseUrl: Uri.parse('https://example.org/api/'),
      protocolVersion: '1.1',
      languages: const ['en'],
      capabilities: const {'search'},
      enabled: true,
      addedAt: DateTime.utc(2026, 7, 13),
    );

class _PagingBookSourceClient extends BookSourceClient {
  final List<int> requestedPages = [];

  @override
  Future<BookSourceSearchPage> search(
    RegisteredBookSource source,
    String query, {
    int page = 1,
    int pageSize = 20,
  }) async {
    requestedPages.add(page);
    final start = page == 1 ? 1 : 11;
    final count = page == 1 ? 10 : 1;
    return BookSourceSearchPage(
      items: List.generate(
        count,
        (index) => BookSourceBook(
          id: 'book-${start + index}',
          title: 'Book ${start + index}',
          author: 'Author',
          description: '',
          categories: const [],
        ),
      ),
      page: page,
      pageSize: pageSize,
      total: 11,
      hasMore: page == 1,
    );
  }
}
