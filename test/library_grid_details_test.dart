import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xxread/models/book.dart';
import 'package:xxread/pages/library/library_grid_book_details.dart';

void main() {
  testWidgets('grid details show an ellipsized title and reading progress', (
    tester,
  ) async {
    const longTitle = '这是一本书名非常非常长需要在网格中省略显示的测试书籍';
    final book = Book(
      title: longTitle,
      author: '测试作者',
      filePath: '/tmp/long-title.epub',
      format: 'epub',
      currentPage: 50,
      totalPages: 100,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: Scaffold(
          body: SizedBox(width: 110, child: LibraryGridBookDetails(book: book)),
        ),
      ),
    );

    final title = tester.widget<Text>(
      find.byKey(const ValueKey('library-grid-title')),
    );
    expect(title.data, longTitle);
    expect(title.softWrap, isFalse);
    expect(title.maxLines, 1);
    expect(title.overflow, TextOverflow.ellipsis);
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('library-grid-title'))).dy -
          tester.getTopLeft(find.byType(LibraryGridBookDetails)).dy,
      8,
    );

    final progress = tester.widget<LinearProgressIndicator>(
      find.byKey(const ValueKey('library-grid-progress')),
    );
    expect(progress.value, 0.5);
    expect(find.text('50%'), findsOneWidget);
    expect(
      tester
              .getTopLeft(find.byKey(const ValueKey('library-grid-progress')))
              .dy -
          tester
              .getBottomLeft(find.byKey(const ValueKey('library-grid-title')))
              .dy,
      lessThanOrEqualTo(8),
    );
    expect(tester.takeException(), isNull);
  });
}
