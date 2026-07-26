import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xxread/l10n/app_localizations.dart';
import 'package:xxread/models/book_note.dart';
import 'package:xxread/utils/reader_themes.dart';
import 'package:xxread/widgets/reader_navigation_sheet.dart';

void main() {
  testWidgets('navigation sheet lists and deletes reader annotations', (
    tester,
  ) async {
    BookNote? selected;
    BookNote? deleted;
    final annotation = BookNote(
      id: 3,
      annotationId: 'annotation-3',
      bookId: 1,
      content: '这是一段被标记的文字',
      cfi: 'or-annotation:note:chapter-1:4:12',
      chapter: '第一章',
      type: 'note',
      color: 'FFD54F',
      readerNote: '这里是我的批注',
      pageNumber: 9,
      startOffset: 4,
      endOffset: 12,
      createTime: DateTime(2026, 7, 26),
    );
    final laterChapterAnnotation = BookNote(
      id: 4,
      annotationId: 'annotation-4',
      bookId: 1,
      content: '第二章的页内高亮',
      cfi: 'or-annotation:highlight:chapter-2:1:8',
      chapter: '第二章',
      type: 'highlight',
      color: '7DD3FC',
      pageNumber: 0,
      startOffset: 1,
      endOffset: 8,
      createTime: DateTime(2026, 7, 26),
    );
    final legacyInk = BookNote(
      id: 5,
      annotationId: 'annotation-5',
      bookId: 1,
      content: '旧手写记录',
      cfi: 'or-annotation:ink:chapter-1:0:0',
      chapter: '第一章',
      type: 'ink',
      color: 'EF4444',
      payloadJson: '{"strokes":[]}',
      pageNumber: 0,
      startOffset: 0,
      endOffset: 0,
      createTime: DateTime(2026, 7, 26),
    );

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ReaderNavigationSheet(
            palette: ReaderThemes.parchment,
            chapters: const [
              ReaderNavigationChapter(title: '第一章', index: 0, id: 'chapter-1'),
              ReaderNavigationChapter(title: '第二章', index: 1, id: 'chapter-2'),
            ],
            currentChapterIndex: 0,
            bookmarks: const [],
            annotations: [laterChapterAnnotation, legacyInk, annotation],
            onChapterSelected: (_) {},
            onBookmarkSelected: (_) {},
            onBookmarkDeleted: (_) {},
            onAnnotationSelected: (value) => selected = value,
            onAnnotationDeleted: (value) => deleted = value,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('笔记'));
    await tester.pumpAndSettle();
    expect(find.text('这里是我的批注'), findsOneWidget);
    expect(find.text('第二章的页内高亮'), findsOneWidget);
    expect(find.text('旧手写记录'), findsNothing);
    expect(
      tester.getTopLeft(find.text('这里是我的批注')).dy,
      lessThan(tester.getTopLeft(find.text('第二章的页内高亮')).dy),
    );

    await tester.tap(find.text('这里是我的批注'));
    expect(selected?.annotationId, annotation.annotationId);

    await tester.tap(find.byType(PopupMenuButton<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除'));
    await tester.pumpAndSettle();
    expect(deleted?.annotationId, annotation.annotationId);
  });
}
