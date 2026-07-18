import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xxread/core/reader/reader_safe_area.dart';
import 'package:xxread/utils/reader_themes.dart';
import 'package:xxread/widgets/reader_paper_page_leaf.dart';

void main() {
  testWidgets('page leaf paints only the page number in its footer',
      (tester) async {
    final captureKey = GlobalKey();
    const metadata = ReaderPaperPageMetadata(
      pageIdentity: 'chapter-1:3',
      layoutFingerprint: 'layout-v4',
      themeId: 'day',
      chapterTitle: 'Chapter 3',
      pageNumber: 4,
      pageCount: 12,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: RepaintBoundary(
          key: captureKey,
          child: const ReaderPaperPageLeaf(
            palette: ReaderThemes.day,
            safeArea: ReaderSafeAreaMetrics(
              viewPadding: EdgeInsets.only(top: 24, bottom: 24),
              topMargin: 4,
              bottomMargin: 0,
            ),
            metadata: metadata,
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text('Body'),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Chapter 3'), findsNothing);
    expect(find.text('4 / 12'), findsOneWidget);
    expect(
      find.ancestor(
        of: find.text('4 / 12'),
        matching: find.byKey(captureKey),
      ),
      findsOneWidget,
    );
    expect(
      tester.getCenter(find.text('4 / 12')).dx,
      greaterThan(tester.getSize(find.byKey(captureKey)).width / 2),
    );
  });

  testWidgets('left page places its page number in the outer bottom corner',
      (tester) async {
    const metadata = ReaderPaperPageMetadata(
      pageIdentity: 'chapter-1:4',
      layoutFingerprint: 'layout-v4',
      themeId: 'day',
      chapterTitle: 'Chapter 3',
      pageNumber: 5,
      pageCount: 12,
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: ReaderPaperPageLeaf(
          palette: ReaderThemes.day,
          safeArea: ReaderSafeAreaMetrics(
            viewPadding: EdgeInsets.only(top: 24, bottom: 24),
            topMargin: 4,
            bottomMargin: 0,
          ),
          metadata: metadata,
          pageNumberPlacement: ReaderPageNumberPlacement.bottomLeft,
          child: SizedBox.expand(),
        ),
      ),
    );

    final pageNumber = find.text('5 / 12');
    expect(pageNumber, findsOneWidget);
    expect(
      tester.getCenter(pageNumber).dx,
      lessThan(MediaQuery.sizeOf(tester.element(pageNumber)).width / 2),
    );
  });

  test('snapshot key separates page, layout and theme', () {
    const base = ReaderPageSnapshotKey(
      pageIdentity: 'chapter-1:0',
      layoutFingerprint: 'layout-a',
      themeId: 'day',
    );
    expect(
      base,
      isNot(
        const ReaderPageSnapshotKey(
          pageIdentity: 'chapter-1:1',
          layoutFingerprint: 'layout-a',
          themeId: 'day',
        ),
      ),
    );
    expect(
      base,
      isNot(
        const ReaderPageSnapshotKey(
          pageIdentity: 'chapter-1:0',
          layoutFingerprint: 'layout-b',
          themeId: 'day',
        ),
      ),
    );
    expect(
      base,
      isNot(
        const ReaderPageSnapshotKey(
          pageIdentity: 'chapter-1:0',
          layoutFingerprint: 'layout-a',
          themeId: 'night',
        ),
      ),
    );
  });
}
