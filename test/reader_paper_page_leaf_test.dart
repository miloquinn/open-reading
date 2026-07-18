import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xxread/core/reader/reader_leaf_status.dart';
import 'package:xxread/core/reader/reader_safe_area.dart';
import 'package:xxread/utils/reader_themes.dart';
import 'package:xxread/widgets/reader_paper_page_leaf.dart';

void main() {
  testWidgets('page chrome is painted inside the captured leaf',
      (tester) async {
    final captureKey = GlobalKey();
    const metadata = ReaderPaperPageMetadata(
      pageIdentity: 'chapter-1:3',
      layoutFingerprint: 'layout-v4',
      themeId: 'day',
      chapterTitle: '第三章 雨夜',
      pageNumber: 4,
      pageCount: 12,
    );
    final status = ReaderLeafStatusData(
      time: DateTime(2026, 7, 18, 9, 5),
      battery: const ReaderBatteryStatus(level: 73, charging: false),
      revision: 1,
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
              ),
              metadata: metadata,
              status: status,
              child: const Padding(
                padding: EdgeInsets.all(24),
                child: Text('正文'),
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('第三章 雨夜'), findsOneWidget);
    expect(find.text('4 / 12'), findsOneWidget);
    expect(find.text('09:05'), findsOneWidget);
    expect(find.text('73%'), findsOneWidget);
    expect(
      find.ancestor(
        of: find.text('4 / 12'),
        matching: find.byKey(captureKey),
      ),
      findsOneWidget,
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
