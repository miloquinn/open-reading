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

  test('typography controls and direction participate in the fingerprint', () {
    ReaderLayoutFingerprint fingerprint({
      int indent = 2,
      int spacing = 0,
      TextDirection direction = TextDirection.ltr,
    }) => ReaderLayoutFingerprint(
      contentKey: 'chapter-1',
      viewport: const Size(360, 720),
      fontSize: 19,
      lineHeight: 1.75,
      horizontalMargin: 18,
      verticalMargin: 24,
      textScaler: TextScaler.noScaling,
      locale: const Locale('zh'),
      pageMode: ReaderPageMode.pageCurl,
      firstLineIndent: indent,
      paragraphSpacing: spacing,
      textDirection: direction,
    );

    final base = fingerprint().cacheKey('reader-v4');
    expect(base, isNot(fingerprint(indent: 0).cacheKey('reader-v4')));
    expect(base, isNot(fingerprint(spacing: 1).cacheKey('reader-v4')));
    expect(
      base,
      isNot(fingerprint(direction: TextDirection.rtl).cacheKey('reader-v4')),
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

  test('tablet spread breakpoints require a landscape tablet viewport', () {
    expect(ReaderLayoutBreakpoints.isTablet(const Size(430, 932)), isFalse);
    expect(ReaderLayoutBreakpoints.isTablet(const Size(800, 1200)), isTrue);
    expect(
      ReaderLayoutBreakpoints.supportsTwoPageLayout(const Size(800, 1200)),
      isFalse,
    );
    expect(
      ReaderLayoutBreakpoints.supportsTwoPageLayout(const Size(1200, 800)),
      isTrue,
    );
  });
}
