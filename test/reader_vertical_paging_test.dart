import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xxread/core/reader/reader_safe_area.dart';
import 'package:xxread/core/reader/reader_vertical_paging.dart';

void main() {
  test('viewport chrome reserves fixed title and status slots', () {
    const metrics = ReaderViewportChromeMetrics(
      safeArea: ReaderSafeAreaMetrics(
        viewPadding: EdgeInsets.only(top: 24, bottom: 24),
        topMargin: 4,
        bottomMargin: 0,
      ),
    );

    expect(metrics.titleTop, 31);
    expect(metrics.contentTop, 56);
    expect(metrics.contentBottom, 26);
    expect(metrics.contentHeight(800), 718);
  });

  test('immersive viewport fills the whole screen regardless of margins', () {
    const metrics = ReaderViewportChromeMetrics(
      safeArea: ReaderSafeAreaMetrics(
        viewPadding: EdgeInsets.only(top: 44, bottom: 34),
        topMargin: 4,
        bottomMargin: 6,
      ),
      immersive: true,
    );

    expect(metrics.contentTop, 0);
    expect(metrics.contentBottom, 0);
    expect(metrics.contentHeight(800), 800);
  });

  test('viewport without a title slot only clears the status bar area', () {
    const metrics = ReaderViewportChromeMetrics(
      safeArea: ReaderSafeAreaMetrics(
        viewPadding: EdgeInsets.only(top: 24, bottom: 24),
        topMargin: 4,
        bottomMargin: 0,
      ),
      reservesTitle: false,
    );

    // 状态栏 24 + 上边距 4，不再附加章节标题条的 32。
    expect(metrics.contentTop, 28);
    // 底部页码条照常保留。
    expect(metrics.contentBottom, 26);
  });

  test('primary visible item follows the viewport center', () {
    final primary = pickPrimaryReaderItem(const [
      ReaderVisibleItemPosition(
        index: 4,
        leadingEdge: -0.65,
        trailingEdge: 0.35,
      ),
      ReaderVisibleItemPosition(
        index: 5,
        leadingEdge: 0.35,
        trailingEdge: 1.35,
      ),
    ]);

    expect(primary?.index, 5);
  });

  test('chapter item position resolves its centered page', () {
    const position = ReaderVisibleItemPosition(
      index: 3,
      leadingEdge: -2.25,
      trailingEdge: 1.75,
    );

    expect(readerPageIndexWithinItem(position, 4), 2);
  });
}
