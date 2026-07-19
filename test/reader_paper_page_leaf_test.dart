import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xxread/core/reader/reader_leaf_status.dart';
import 'package:xxread/core/reader/reader_safe_area.dart';
import 'package:xxread/utils/reader_themes.dart';
import 'package:xxread/widgets/reader_paper_page_leaf.dart';
import 'package:xxread/widgets/reader_top_information_bar.dart';

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
    final leafRect = tester.getRect(find.byKey(captureKey));
    final pageNumberRect = tester.getRect(find.text('4 / 12'));
    expect(leafRect.right - pageNumberRect.right, greaterThanOrEqualTo(23));
  });

  testWidgets('reader information is painted inside the paper leaf',
      (tester) async {
    final captureKey = GlobalKey();
    const metadata = ReaderPaperPageMetadata(
      pageIdentity: 'chapter-1:5',
      layoutFingerprint: 'layout-v4',
      themeId: 'day',
      chapterTitle: 'Chapter 3',
      pageNumber: 6,
      pageCount: 12,
    );
    final status = ReaderLeafStatusData(
      time: DateTime(2026, 7, 19, 9, 5),
      battery: const ReaderBatteryStatus(level: 73, charging: false),
      revision: 2,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(alwaysUse24HourFormat: true),
          child: RepaintBoundary(
            key: captureKey,
            child: ReaderPaperPageLeaf(
              palette: ReaderThemes.day,
              safeArea: const ReaderSafeAreaMetrics(
                viewPadding: EdgeInsets.only(top: 24, bottom: 24),
                topMargin: 4,
                bottomMargin: 0,
                topChromeReserve: ReaderSafeAreaMetrics.readerTopBarReserve,
              ),
              metadata: metadata,
              showTopInformation: true,
              status: status,
              child: const SizedBox.expand(),
            ),
          ),
        ),
      ),
    );

    for (final text in ['09:05', 'Chapter 3', '73%']) {
      expect(find.text(text), findsOneWidget);
      expect(
        find.ancestor(
          of: find.text(text),
          matching: find.byKey(captureKey),
        ),
        findsOneWidget,
      );
    }
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

  testWidgets('tablet spread splits chapter and device status across leaves',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final status = ReaderLeafStatusData(
      time: DateTime(2026, 7, 19, 9, 5),
      battery: const ReaderBatteryStatus(level: 73, charging: false),
      revision: 2,
    );

    ReaderPaperPageLeaf leaf(
      String id,
      ReaderTopInformationLayout layout,
      ReaderPageNumberPlacement pageNumberPlacement,
    ) =>
        ReaderPaperPageLeaf(
          palette: ReaderThemes.day,
          safeArea: const ReaderSafeAreaMetrics(
            viewPadding: EdgeInsets.only(top: 24, bottom: 24),
            topMargin: 4,
            bottomMargin: 0,
            topChromeReserve: ReaderSafeAreaMetrics.readerTopBarReserve,
          ),
          metadata: ReaderPaperPageMetadata(
            pageIdentity: id,
            layoutFingerprint: 'layout-v4',
            themeId: 'day',
            chapterTitle: 'Chapter 3',
            pageNumber: id == 'left' ? 5 : 6,
            pageCount: 12,
          ),
          pageNumberPlacement: pageNumberPlacement,
          showTopInformation: true,
          topInformationLayout: layout,
          status: status,
          child: const SizedBox.expand(),
        );

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(alwaysUse24HourFormat: true),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: leaf(
                  'left',
                  ReaderTopInformationLayout.spreadLeft,
                  ReaderPageNumberPlacement.bottomLeft,
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: leaf(
                  'right',
                  ReaderTopInformationLayout.spreadRight,
                  ReaderPageNumberPlacement.bottomRight,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    for (final text in ['Chapter 3', '09:05', '73%']) {
      expect(find.text(text), findsOneWidget);
    }
    expect(tester.getCenter(find.text('Chapter 3')).dx, lessThan(600));
    expect(tester.getCenter(find.text('09:05')).dx, greaterThan(600));
    expect(tester.getCenter(find.text('73%')).dx, greaterThan(600));
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
