import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xxread/pages/home_layout_constants.dart';

void main() {
  group('HomeMobileChromeMetrics', () {
    test('keeps floating chrome clear of iPhone system insets', () {
      final metrics = HomeMobileChromeMetrics.fromMediaQuery(
        const MediaQueryData(
          size: Size(393, 852),
          viewPadding: EdgeInsets.only(top: 59, bottom: 34),
        ),
      );

      expect(metrics.systemTopInset, 59);
      expect(metrics.systemBottomInset, 34);
      expect(metrics.topBarHeight, 119);
      expect(metrics.pageTopPadding, 127);
      expect(metrics.navBottomInset, 44);
      expect(metrics.navContainerHeight, 108);
      expect(metrics.pageBottomPadding, 118);
      expect(metrics.floatingActionBottomMargin, 123);
    });

    test('uses Android system insets without platform-specific branches', () {
      final metrics = HomeMobileChromeMetrics.fromMediaQuery(
        const MediaQueryData(
          size: Size(412, 915),
          viewPadding: EdgeInsets.only(top: 24, bottom: 24),
        ),
      );

      expect(metrics.topBarHeight, 84);
      expect(metrics.pageTopPadding, 92);
      expect(metrics.navBottomInset, 34);
      expect(metrics.navContainerHeight, 98);
      expect(metrics.pageBottomPadding, 108);
      expect(metrics.floatingActionBottomMargin, 113);
    });

    test('preserves large system insets instead of clamping them', () {
      final metrics = HomeMobileChromeMetrics.fromMediaQuery(
        const MediaQueryData(
          size: Size(320, 568),
          viewPadding: EdgeInsets.only(top: 20, bottom: 60),
        ),
      );

      expect(metrics.systemBottomInset, 60);
      expect(metrics.navBottomInset, 70);
      expect(metrics.pageBottomPadding, 144);
    });
  });
}
