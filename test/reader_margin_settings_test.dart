import 'package:flutter_test/flutter_test.dart';
import 'package:xxread/core/reader/reader_margin_settings.dart';

void main() {
  group('ReaderMarginSettings', () {
    test('uses close-to-screen defaults without stored values', () {
      final margins = ReaderMarginSettings.fromStored();

      expect(margins.top, 4);
      expect(margins.bottom, 0);
    });

    test('migrates the legacy default to the new defaults', () {
      final margins = ReaderMarginSettings.fromStored(legacyVertical: 28);

      expect(margins.top, 4);
      expect(margins.bottom, 0);
    });

    test('preserves legacy user-added spacing on both edges', () {
      final margins = ReaderMarginSettings.fromStored(legacyVertical: 38);

      expect(margins.top, 14);
      expect(margins.bottom, 10);
    });

    test('prefers and clamps independently stored values', () {
      final margins = ReaderMarginSettings.fromStored(top: 48, bottom: -2);

      expect(margins.top, 40);
      expect(margins.bottom, 0);
    });
  });
}
