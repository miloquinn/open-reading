import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:xxread/book_sources/models/registered_book_source.dart';
import 'package:xxread/book_sources/protocol/book_source_protocol.dart';
import 'package:xxread/book_sources/services/book_source_client.dart';
import 'package:xxread/core/reader/reader_settings.dart';
import 'package:xxread/l10n/app_localizations.dart';
import 'package:xxread/pages/reader/book_source_reader_page.dart';
import 'package:xxread/widgets/reader_paper_page_leaf.dart';

void main() {
  testWidgets('previous-chapter slide preview renders the previous last page',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      ReaderSettingsStore.pageModeKey: 'horizontalSlide',
      'book_source_reading_progress_v1:preview-source:preview-book':
          '{"chapterId":"chapter-2","chapterIndex":1,'
              '"chapterProgress":0,"updatedAt":"2026-07-18T00:00:00.000Z"}',
    });

    final client = _AdjacentPreviewClient();
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: BookSourceReaderPage(
          source: RegisteredBookSource(
            id: 'preview-source',
            name: 'Preview source',
            description: '',
            manifestUrl: Uri.parse('https://example.org/source.json'),
            apiBaseUrl: Uri.parse('https://example.org/api/'),
            protocolVersion: '1.0',
            languages: const ['zh-CN'],
            capabilities: const {'catalog', 'content'},
            enabled: true,
            addedAt: DateTime.utc(2026, 7, 18),
          ),
          book: const BookSourceBook(
            id: 'preview-book',
            title: 'Preview book',
            author: 'Author',
            description: '',
            categories: [],
          ),
          client: client,
        ),
      ),
    );

    await _pumpUntilText(tester, '当前章节正文');
    await _pumpUntil(
      tester,
      () => client.requestedChapterIds.contains('chapter-1'),
      'previous chapter preload',
    );

    final pageView = find.byType(PageView);
    expect(pageView, findsOneWidget);
    final pageViewWidget = tester.widget<PageView>(pageView);
    final delegate =
        pageViewWidget.childrenDelegate as SliverChildBuilderDelegate;
    final previewShell = delegate.builder(tester.element(pageView), 0)!;
    expect(previewShell, isA<LayoutBuilder>());
    final preview = (previewShell as LayoutBuilder).builder(
      tester.element(pageView),
      const BoxConstraints.tightFor(width: 800, height: 600),
    );
    expect(preview, isA<ReaderPaperPageLeaf>());
    final leaf = preview as ReaderPaperPageLeaf;
    expect(leaf.metadata.chapterTitle, '上一章');
    expect(leaf.metadata.pageCount, greaterThan(1));
    expect(leaf.metadata.pageNumber, leaf.metadata.pageCount);
    expect(tester.takeException(), isNull);
  });
}

String _allText(WidgetTester tester) => tester
    .widgetList<Text>(find.byType(Text, skipOffstage: false))
    .map((widget) => widget.data ?? widget.textSpan?.toPlainText() ?? '')
    .join('\n');

Future<void> _pumpUntilText(WidgetTester tester, String text) async {
  await _pumpUntil(
    tester,
    () => _allText(tester).contains(text),
    'text "$text"',
  );
}

Future<void> _pumpUntil(
  WidgetTester tester,
  bool Function() condition,
  String description,
) async {
  for (var attempt = 0; attempt < 50; attempt++) {
    await tester.pump(const Duration(milliseconds: 100));
    if (condition()) return;
  }
  fail(
    'Timed out waiting for $description; '
    'texts=${_allText(tester)}, exception=${tester.takeException()}.',
  );
}

class _AdjacentPreviewClient extends BookSourceClient {
  static const tailMarker = '上一章尾页唯一标记';
  final List<String> requestedChapterIds = <String>[];

  @override
  Future<List<BookSourceChapter>> getChapters(
    RegisteredBookSource source,
    String bookId,
  ) async =>
      const [
        BookSourceChapter(id: 'chapter-1', title: '上一章', order: 1),
        BookSourceChapter(id: 'chapter-2', title: '当前章', order: 2),
      ];

  @override
  Future<BookSourceChapterContent> getChapterContent(
    RegisteredBookSource source, {
    required String bookId,
    required String chapterId,
  }) async {
    requestedChapterIds.add(chapterId);
    final isPrevious = chapterId == 'chapter-1';
    final content = isPrevious
        ? '${List.generate(
            120,
            (index) => '上一章正文第$index段，用于确保章节被分成多页。',
          ).join('\n')}\n$tailMarker'
        : List.generate(
            24,
            (index) => '当前章节正文第$index段。',
          ).join('\n');
    return BookSourceChapterContent(
      bookId: bookId,
      chapterId: chapterId,
      title: isPrevious ? '上一章' : '当前章',
      content: content,
      contentType: 'text/plain',
    );
  }
}
