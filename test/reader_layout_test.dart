import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xxread/core/reader/reader_layout.dart';

void main() {
  test('layout cache fingerprint changes when line height changes', () {
    ReaderLayoutFingerprint fingerprint(double lineHeight) =>
        ReaderLayoutFingerprint(
          contentKey: 'chapter-1',
          viewport: const Size(360, 720),
          fontSize: 24,
          lineHeight: lineHeight,
          horizontalMargin: 20,
          verticalMargin: 28,
          textScaler: TextScaler.noScaling,
          locale: const Locale('zh', 'CN'),
          pageMode: ReaderPageMode.pageCurl,
        );

    expect(
      fingerprint(1.4).cacheKey('reader-v1'),
      isNot(fingerprint(2.1).cacheKey('reader-v1')),
    );
  });

  test('local and source readers resolve the same persisted page mode', () {
    expect(
      readerPageModeFromName(
        'horizontalPage',
        fallback: ReaderPageMode.verticalScroll,
      ),
      ReaderPageMode.instantPage,
    );
    expect(
      readerPageModeFromName(
        'pageCurl',
        fallback: ReaderPageMode.verticalScroll,
      ),
      ReaderPageMode.pageCurl,
    );
  });
}
