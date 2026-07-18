import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xxread/core/reader/reader_safe_area.dart';

void main() {
  group('ReaderSafeAreaMetrics', () {
    test('keeps iPhone text below Dynamic Island without excessive bottom gap',
        () {
      const metrics = ReaderSafeAreaMetrics(
        viewPadding: EdgeInsets.only(top: 59, bottom: 34),
        topMargin: 4,
        bottomMargin: 0,
      );

      expect(metrics.contentTop, 63);
      expect(metrics.pageNumberBottom, 14);
      expect(metrics.contentBottom, 34);
    });

    test('uses Android insets through the same calculation', () {
      const metrics = ReaderSafeAreaMetrics(
        viewPadding: EdgeInsets.only(top: 24, bottom: 24),
        topMargin: 4,
        bottomMargin: 0,
      );

      expect(metrics.contentTop, 28);
      expect(metrics.pageNumberBottom, 8);
      expect(metrics.contentBottom, 24);
    });

    test('preserves the reader margin setting without summing reserves', () {
      const metrics = ReaderSafeAreaMetrics(
        viewPadding: EdgeInsets.only(top: 59, bottom: 34),
        topMargin: 24,
        bottomMargin: 20,
      );

      expect(metrics.contentTop, 83);
      expect(metrics.pageNumberBottom, 14);
      expect(metrics.contentBottom, 54);
    });

    test('keeps page number clear on devices without a bottom inset', () {
      const metrics = ReaderSafeAreaMetrics(
        viewPadding: EdgeInsets.only(top: 24),
        topMargin: 4,
        bottomMargin: 0,
      );

      expect(metrics.contentTop, 28);
      expect(metrics.pageNumberBottom, 8);
      expect(metrics.contentBottom, 24);
    });

    test('reserves a compact row for reader-owned top information', () {
      const metrics = ReaderSafeAreaMetrics(
        viewPadding: EdgeInsets.only(top: 24, bottom: 24),
        topMargin: 4,
        bottomMargin: 0,
        topChromeReserve: ReaderSafeAreaMetrics.readerTopBarReserve,
      );

      expect(metrics.readerTopBarTop, 28);
      expect(metrics.contentTop, 52);
    });
  });
}
