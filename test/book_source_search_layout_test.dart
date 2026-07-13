import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:xxread/book_sources/models/registered_book_source.dart';
import 'package:xxread/book_sources/protocol/book_source_protocol.dart';
import 'package:xxread/book_sources/services/book_source_client.dart';
import 'package:xxread/l10n/app_localizations.dart';
import 'package:xxread/pages/book_sources_page.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('search controls align on wide layouts and stack on mobile',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(900, 1200);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: BookSourcesPage()),
      ),
    );
    await tester.pumpAndSettle();

    final scope = find.byKey(const Key('bookSourceScopeControl'));
    final query = find.byKey(const Key('bookSourceQueryControl'));
    expect(tester.getSize(scope).height, 56);
    expect(tester.getSize(query).height, 56);
    expect(tester.getTopLeft(scope).dy, tester.getTopLeft(query).dy);

    tester.view.physicalSize = const Size(390, 1000);
    await tester.pumpAndSettle();

    expect(tester.getSize(scope).width, tester.getSize(query).width);
    expect(tester.getTopLeft(query).dy,
        greaterThan(tester.getBottomLeft(scope).dy));
  });

  testWidgets('opens source management and the add-source dialog',
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

    await tester.tap(find.byIcon(Icons.tune_rounded).first);
    await tester.pumpAndSettle();

    expect(find.text('Manage sources'), findsWidgets);

    await tester.tap(find.byIcon(Icons.add_link_rounded).first);
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
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
        home: Scaffold(body: BookSourcesPage(client: client)),
      ),
    );
    await tester.pumpAndSettle();

    final queryField = find.descendant(
      of: find.byKey(const Key('bookSourceQueryControl')),
      matching: find.byType(TextField),
    );
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
    expect(find.text('Book 11'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
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
