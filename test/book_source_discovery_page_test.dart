import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:xxread/book_sources/models/registered_book_source.dart';
import 'package:xxread/book_sources/protocol/book_source_protocol.dart';
import 'package:xxread/book_sources/services/book_source_client.dart';
import 'package:xxread/book_sources/services/book_download_cancellation.dart';
import 'package:xxread/book_sources/services/book_source_shelf_service.dart';
import 'package:xxread/l10n/app_localizations.dart';
import 'package:xxread/models/book.dart';
import 'package:xxread/pages/book_sources/book_sources_page.dart';
import 'package:xxread/pages/book_sources/widgets/sourced_book_widgets.dart';
import 'package:xxread/services/library/download_task_controller.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('discover scope defaults to all and filters every section', (
    tester,
  ) async {
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

    expect(
      find.byKey(const Key('bookSourceDiscoverScopeControl')),
      findsOneWidget,
    );
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

  testWidgets('request failures are not reported as unsupported capabilities', (
    tester,
  ) async {
    final source = _source('source-a', 'Source A');
    SharedPreferences.setMockInitialValues({
      'open_reading_book_sources_v1': jsonEncode([source.toJson()]),
    });

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: BookSourcesPage(client: _FailingDiscoveryClient()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Could not load discovery content'), findsOneWidget);
    expect(
      find.textContaining('Source A: Source request timed out.'),
      findsOneWidget,
    );
    expect(
      find.text('Current sources do not support this section'),
      findsNothing,
    );
    expect(find.text('Try again'), findsOneWidget);

    await tester.tap(find.text('Categories'));
    await tester.pumpAndSettle();
    expect(find.text('Could not load discovery content'), findsOneWidget);
    expect(
      find.textContaining('Source A: Source request timed out.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Latest'));
    await tester.pumpAndSettle();
    expect(find.text('Could not load discovery content'), findsOneWidget);
    expect(
      find.textContaining('Source A: Source request timed out.'),
      findsOneWidget,
    );
  });

  testWidgets('an empty capable source shows an empty state', (tester) async {
    final source = _source('source-a', 'Source A');
    SharedPreferences.setMockInitialValues({
      'open_reading_book_sources_v1': jsonEncode([source.toJson()]),
    });

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: BookSourcesPage(client: _EmptyDiscoveryClient())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Nothing to show yet'), findsOneWidget);
    expect(
      find.text('This section has no content to show yet.'),
      findsOneWidget,
    );
    expect(
      find.text('Current sources do not support this section'),
      findsNothing,
    );
  });

  testWidgets('missing capabilities still show the unsupported state', (
    tester,
  ) async {
    final source = _source(
      'source-a',
      'Source A',
      capabilities: const {'search', 'detail', 'catalog', 'content'},
    );
    SharedPreferences.setMockInitialValues({
      'open_reading_book_sources_v1': jsonEncode([source.toJson()]),
    });

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: BookSourcesPage(client: _EmptyDiscoveryClient())),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Current sources do not support this section'),
      findsOneWidget,
    );
    expect(find.text('Nothing to show yet'), findsNothing);
  });

  testWidgets('large category sets use a searchable lazy picker', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(430, 1100);
    addTearDown(tester.view.reset);

    final source = _source('source-a', 'Source A');
    SharedPreferences.setMockInitialValues({
      'open_reading_book_sources_v1': jsonEncode([source.toJson()]),
    });
    final client = _LargeCategoryDiscoveryClient();

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: BookSourcesPage(client: client)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Categories'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('bookSourceCategoryPickerButton')),
      findsOneWidget,
    );
    expect(find.text('Category 000'), findsOneWidget);
    expect(find.text('Category 499'), findsNothing);

    await tester.tap(find.byKey(const Key('bookSourceCategoryPickerButton')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('bookSourceCategoryLazyList')), findsOneWidget);
    expect(find.text('Category 499'), findsNothing);

    await tester.enterText(
      find.byKey(const Key('bookSourceCategorySearchField')),
      '499',
    );
    await tester.pumpAndSettle();
    expect(find.text('Category 499'), findsOneWidget);

    await tester.tap(find.text('Category 499'));
    await tester.pumpAndSettle();
    expect(client.lastCategoryId, 'category-499');
    expect(find.text('Category 499'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'discovery shelves are built lazily along the vertical viewport',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(430, 700);
      addTearDown(tester.view.reset);

      final source = _source('source-a', 'Source A');
      SharedPreferences.setMockInitialValues({
        'open_reading_book_sources_v1': jsonEncode([source.toJson()]),
      });

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: BookSourcesPage(client: _ManyShelfDiscoveryClient()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Shelf 0'), findsOneWidget);
      expect(find.text('Shelf 11'), findsNothing);

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -5000));
      await tester.pumpAndSettle();
      expect(find.text('Shelf 11'), findsOneWidget);
    },
  );

  testWidgets('details sheet keeps its drag handle below the top safe area', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(430, 900);
    tester.view.padding = const FakeViewPadding(top: 44);
    tester.view.viewPadding = const FakeViewPadding(top: 44);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _bookActionsHarness(
        _FakeShelfService(),
        description: List.filled(
          40,
          'A long description keeps the details content scrollable.',
        ).join(' '),
      ),
    );

    await tester.tap(find.byKey(const Key('openBookDetails')));
    await tester.pumpAndSettle();

    final sheetRect = tester.getRect(find.byType(BottomSheet));
    expect(sheetRect.top, greaterThanOrEqualTo(60));
  });

  testWidgets(
    'switching to shelf options smoothly shrinks the existing sheet',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(430, 900);
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _bookActionsHarness(
          _FakeShelfService(),
          description: List.filled(
            40,
            'A long description keeps the details content scrollable.',
          ).join(' '),
        ),
      );

      await tester.tap(find.byKey(const Key('openBookDetails')));
      await tester.pumpAndSettle();
      final initialHeight = tester.getSize(find.byType(BottomSheet)).height;

      await tester.tap(find.byKey(const Key('bookSourceAddToShelfButton')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 110));
      final animatedHeight = tester.getSize(find.byType(BottomSheet)).height;

      await tester.pumpAndSettle();
      final optionsHeight = tester.getSize(find.byType(BottomSheet)).height;

      expect(optionsHeight, lessThan(initialHeight - 100));
      expect(animatedHeight, lessThan(initialHeight));
      expect(animatedHeight, greaterThan(optionsHeight));
      expect(find.byKey(const Key('bookSourceShelfOptions')), findsOneWidget);
    },
  );

  testWidgets(
    'adding online stays in the details sheet for feedback then closes',
    (tester) async {
      final shelfService = _FakeShelfService();
      await tester.pumpWidget(_bookActionsHarness(shelfService));

      await tester.tap(find.byKey(const Key('openBookDetails')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('bookSourceAddToShelfButton')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 230));

      expect(find.byKey(const Key('bookSourceShelfOptions')), findsOneWidget);
      await tester.tap(find.byKey(const Key('bookSourceAddOnlineOption')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 240));

      expect(shelfService.addCalls, 1);
      expect(
        find.byKey(const Key('bookSourceAddedCompletion')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('bookSourceShelfDropAnimation')),
        findsOneWidget,
      );

      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('bookSourceDetailsContent')), findsNothing);
    },
  );

  testWidgets('an existing shelf book uses an information state without drop', (
    tester,
  ) async {
    final shelfService = _FakeShelfService(existing: true);
    await tester.pumpWidget(_bookActionsHarness(shelfService));

    await tester.tap(find.byKey(const Key('openBookDetails')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('bookSourceAddToShelfButton')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 230));
    await tester.tap(find.byKey(const Key('bookSourceAddOnlineOption')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 220));

    expect(shelfService.addCalls, 0);
    expect(
      find.byKey(const Key('bookSourceAlreadyAddedCompletion')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('bookSourceShelfDropAnimation')), findsNothing);
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
  });

  testWidgets('a failed online add keeps the sheet open for retry', (
    tester,
  ) async {
    final shelfService = _FakeShelfService(
      addError: StateError('Could not save the shelf book.'),
    );
    await tester.pumpWidget(_bookActionsHarness(shelfService));

    await tester.tap(find.byKey(const Key('openBookDetails')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('bookSourceAddToShelfButton')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 230));
    await tester.tap(find.byKey(const Key('bookSourceAddOnlineOption')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 230));

    expect(find.byKey(const Key('bookSourceAddFailed')), findsOneWidget);
    expect(find.byKey(const Key('bookSourceAddRetryButton')), findsOneWidget);
    expect(find.byType(BottomSheet), findsOneWidget);
  });

  testWidgets('local download progress stays in the sheet and can continue', (
    tester,
  ) async {
    final shelfService = _FakeShelfService();
    await tester.pumpWidget(_bookActionsHarness(shelfService));

    await tester.tap(find.byKey(const Key('openBookDetails')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('bookSourceAddToShelfButton')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 230));
    await tester.tap(find.byKey(const Key('bookSourceDownloadLocalOption')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));

    expect(shelfService.downloadStarted, isTrue);
    expect(find.byKey(const Key('bookSourceDownloadInline')), findsOneWidget);
    expect(
      find.byKey(const Key('bookSourceDownloadBackgroundButton')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const Key('bookSourceDownloadBackgroundButton')),
    );
    shelfService.completeDownload();
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
  });

  testWidgets('reading from the details sheet hands off to paper transition', (
    tester,
  ) async {
    await tester.pumpWidget(_bookActionsHarness(_FakeShelfService()));

    await tester.tap(find.byKey(const Key('openBookDetails')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('bookSourceReadButton')));
    await tester.pump(const Duration(milliseconds: 70));
    await tester.pump();

    expect(
      find.byKey(const ValueKey('book-paper-transition-position')),
      findsOneWidget,
    );
    final position = tester.widget<SlideTransition>(
      find.byKey(const ValueKey('book-paper-transition-position')),
    );
    expect(position.position.value.dx, 0);
    expect(position.position.value.dy, greaterThan(0));
  });
}

Widget _bookActionsHarness(
  BookSourceShelfService shelfService, {
  String description = 'A book used to exercise the details sheet.',
}) {
  final source = _source('source-actions', 'Action Source');
  final result = SourcedBook(
    source: source,
    book: BookSourceBook(
      id: 'action-book',
      title: 'Action Book',
      author: 'Author',
      description: description,
      categories: const [],
    ),
  );
  return ChangeNotifierProvider(
    create: (_) => DownloadTaskController(),
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: FilledButton(
              key: const Key('openBookDetails'),
              onPressed: () => SourcedBookActions(
                context: context,
                client: _EmptyDiscoveryClient(),
                shelfService: shelfService,
              ).showBookDetails(result),
              child: const Text('Open details'),
            ),
          ),
        ),
      ),
    ),
  );
}

class _FakeShelfService extends BookSourceShelfService {
  _FakeShelfService({this.existing = false, this.addError});

  final bool existing;
  final Object? addError;
  int addCalls = 0;
  bool downloadStarted = false;
  final Completer<Book> _downloadCompleter = Completer<Book>();

  Book _shelfBook(String sourceId, String sourceBookId) => Book(
    id: 1,
    title: 'Action Book',
    author: 'Author',
    filePath: '',
    format: 'source',
    storageType: 'online',
    sourceId: sourceId,
    sourceBookId: sourceBookId,
  );

  @override
  Future<Book?> findShelfBook({
    required String sourceId,
    required String sourceBookId,
  }) async => existing ? _shelfBook(sourceId, sourceBookId) : null;

  @override
  Future<Book> addOnline({
    required RegisteredBookSource source,
    required BookSourceBook book,
  }) async {
    addCalls += 1;
    if (addError case final error?) throw error;
    return _shelfBook(source.id, book.id);
  }

  @override
  Future<Book> downloadToLocal({
    required RegisteredBookSource source,
    required BookSourceBook book,
    void Function(int completed, int total)? onProgress,
    BookDownloadCancellation? cancellation,
  }) {
    downloadStarted = true;
    onProgress?.call(1, 3);
    return _downloadCompleter.future;
  }

  void completeDownload() {
    if (_downloadCompleter.isCompleted) return;
    _downloadCompleter.complete(
      Book(
        id: 2,
        title: 'Action Book',
        author: 'Author',
        filePath: '/tmp/action-book.txt',
        format: 'txt',
      ),
    );
  }
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
    return [BookSourceCategory(id: '${source.id}-fiction', name: 'Fiction')];
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
        _book('${source.id}-category-book', '${source.name} category book'),
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

class _LargeCategoryDiscoveryClient extends _DiscoveryClient {
  String? lastCategoryId;

  @override
  Future<List<BookSourceCategory>> getCategories(
    RegisteredBookSource source,
  ) async {
    return List.generate(
      500,
      (index) => BookSourceCategory(
        id: 'category-${index.toString().padLeft(3, '0')}',
        name: 'Category ${index.toString().padLeft(3, '0')}',
      ),
      growable: false,
    );
  }

  @override
  Future<BookSourceSearchPage> browse(
    RegisteredBookSource source, {
    String? category,
    String sort = 'latest',
    int page = 1,
    int pageSize = 20,
  }) async {
    lastCategoryId = category;
    return _page([_book('selected-book', 'Selected category book')]);
  }
}

class _ManyShelfDiscoveryClient extends _DiscoveryClient {
  @override
  Future<BookSourceDiscoveryPage> getDiscovery(
    RegisteredBookSource source,
  ) async {
    return BookSourceDiscoveryPage(
      sections: List.generate(
        12,
        (index) => BookSourceDiscoverySection(
          id: 'shelf-$index',
          title: 'Shelf $index',
          items: [_book('book-$index', 'Book $index')],
        ),
      ),
    );
  }
}

class _FailingDiscoveryClient extends BookSourceClient {
  @override
  Future<BookSourceDiscoveryPage> getDiscovery(RegisteredBookSource source) {
    throw const BookSourceProtocolException('Source request timed out.');
  }

  @override
  Future<List<BookSourceCategory>> getCategories(RegisteredBookSource source) {
    throw const BookSourceProtocolException('Source request timed out.');
  }

  @override
  Future<BookSourceSearchPage> browse(
    RegisteredBookSource source, {
    String? category,
    String sort = 'latest',
    int page = 1,
    int pageSize = 20,
  }) {
    throw const BookSourceProtocolException('Source request timed out.');
  }
}

class _EmptyDiscoveryClient extends BookSourceClient {
  @override
  Future<BookSourceDiscoveryPage> getDiscovery(
    RegisteredBookSource source,
  ) async {
    return const BookSourceDiscoveryPage(sections: []);
  }
}

RegisteredBookSource _source(
  String id,
  String name, {
  Set<String> capabilities = const {
    'search',
    'discover',
    'categories',
    'browse',
  },
}) {
  return RegisteredBookSource(
    id: id,
    name: name,
    description: '',
    manifestUrl: Uri.parse('https://example.org/$id/source.json'),
    apiBaseUrl: Uri.parse('https://example.org/$id/api/'),
    protocolVersion: '1.1',
    languages: const ['en'],
    capabilities: capabilities,
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

BookSourceBook _book(String id, String title, {DateTime? updatedAt}) {
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
