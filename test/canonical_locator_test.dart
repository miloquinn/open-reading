import 'package:flutter_test/flutter_test.dart';
import 'package:xxread/core/reader/canonical_locator.dart';

void main() {
  group('RenderedLocator', () {
    test('uses the Flutter-native renderer when stored data is unknown', () {
      final locator = RenderedLocator.fromJson(const {
        'version': 1,
        'format': 'epub',
        'renderer': 'unknown-renderer',
        'href': 'chapter-1',
        'progression': 0.25,
        'position': 2,
        'totalPositions': 8,
      });

      expect(locator.renderer, ReaderRendererType.flutterNative);
    });

    test('round-trips generic renderer identifiers', () {
      final locator = RenderedLocator.create(
        version: 1,
        format: BookFormat.epub,
        renderer: ReaderRendererType.flutterNative,
        href: 'chapter-1',
        progression: 0.25,
        position: 2,
        totalPositions: 8,
      );

      final restored = RenderedLocator.fromJson(locator.toJson());

      expect(restored.renderer, ReaderRendererType.flutterNative);
      expect(restored.href, locator.href);
      expect(restored.position, locator.position);
    });
  });
}
