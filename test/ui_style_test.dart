import 'package:flutter_test/flutter_test.dart';
import 'package:xxread/utils/ui_style.dart';

void main() {
  group('appUiStyleFromStorage', () {
    test('defaults to Material 3 so glass effects start disabled', () {
      expect(appUiStyleFromStorage(null), AppUiStyle.material3);
    });

    test('keeps explicitly saved glass preference', () {
      expect(appUiStyleFromStorage('glass'), AppUiStyle.glass);
    });
  });
}
