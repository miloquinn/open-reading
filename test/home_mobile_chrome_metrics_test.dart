import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xxread/pages/home/home_mobile_chrome.dart';

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
      expect(metrics.floatingNavHeight, 56);
      expect(metrics.topBarHeight, 119);
      expect(metrics.pageTopPadding, 127);
      expect(metrics.navBottomInset, 44);
      expect(metrics.navContainerHeight, 100);
      expect(metrics.pageBottomPadding, 110);
      expect(metrics.floatingActionBottomMargin, 115);
    });

    test(
      'keeps the floating navigation compact with deliberate side margins',
      () {
        expect(
          homeMobileFloatingNavWidthFor(screenWidth: 320, itemCount: 4),
          284,
        );
        expect(
          homeMobileFloatingNavWidthFor(screenWidth: 360, itemCount: 4),
          324,
        );
        expect(
          homeMobileFloatingNavWidthFor(screenWidth: 393, itemCount: 4),
          357,
        );
        expect(
          homeMobileFloatingNavWidthFor(screenWidth: 405, itemCount: 4),
          368,
        );
        expect(
          homeMobileFloatingNavWidthFor(screenWidth: 600, itemCount: 4),
          368,
        );

        expect(
          homeMobileFloatingNavItemWidthFor(screenWidth: 320, itemCount: 4),
          69,
        );
        expect(
          homeMobileFloatingNavItemWidthFor(screenWidth: 393, itemCount: 4),
          closeTo(87.25, 0.001),
        );
        expect(
          homeMobileFloatingNavItemWidthFor(screenWidth: 405, itemCount: 4),
          90,
        );
      },
    );

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
      expect(metrics.navContainerHeight, 90);
      expect(metrics.pageBottomPadding, 100);
      expect(metrics.floatingActionBottomMargin, 105);
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
      expect(metrics.pageBottomPadding, 136);
    });

    test('locks system insets while an immersive reader route is active', () {
      final stabilizer = HomeMobileSystemInsetsStabilizer();
      final homeInsets = stabilizer.resolve(
        const MediaQueryData(
          size: Size(412, 915),
          viewPadding: EdgeInsets.only(top: 24, bottom: 24),
        ),
        lockForReaderTransition: false,
      );

      final hiddenBarInsets = stabilizer.resolve(
        const MediaQueryData(size: Size(412, 915)),
        lockForReaderTransition: true,
      );
      final transientGestureInsets = stabilizer.resolve(
        const MediaQueryData(
          size: Size(412, 915),
          viewPadding: EdgeInsets.only(bottom: 48),
        ),
        lockForReaderTransition: true,
      );

      expect(homeInsets, const EdgeInsets.only(top: 24, bottom: 24));
      expect(hiddenBarInsets, homeInsets);
      expect(transientGestureInsets, homeInsets);

      final restoredInsets = stabilizer.resolve(
        const MediaQueryData(
          size: Size(412, 915),
          viewPadding: EdgeInsets.only(top: 24, bottom: 32),
        ),
        lockForReaderTransition: false,
      );
      expect(restoredInsets, const EdgeInsets.only(top: 24, bottom: 32));
    });
  });
}
