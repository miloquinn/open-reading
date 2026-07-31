import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:xxread/core/reader/reader_settings.dart';
import 'package:xxread/core/reader/reader_layout.dart';
import 'package:xxread/l10n/app_localizations.dart';
import 'package:xxread/models/book.dart';
import 'package:xxread/pages/reader/native_reader_page.dart';
import 'package:xxread/widgets/reader_paper_page_leaf.dart';

void main() {
  test('reader font overrides EPUB font except for the system default', () {
    expect(
      resolveNativeReaderFontFamily(
        readerFontFamily: null,
        epubFontFamily: 'Embedded EPUB Font',
      ),
      'Embedded EPUB Font',
    );
    expect(
      resolveNativeReaderFontFamily(
        readerFontFamily: 'PingFang SC',
        epubFontFamily: 'Embedded EPUB Font',
      ),
      'PingFang SC',
    );
  });

  testWidgets(
    'EPUB horizontal turns warm the next pagination window before a chapter boundary',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      await tester.binding.setSurfaceSize(const Size(480, 800));
      SharedPreferences.setMockInitialValues({
        ReaderSettingsStore.pageModeKey: ReaderPageMode.horizontalSlide.name,
        ReaderSettingsStore.txtChapterTitlePageKey: false,
      });
      final directory = Directory.systemTemp.createTempSync(
        'open-reading-epub-transition-',
      );
      final epub = File('${directory.path}/transition.epub');
      epub.writeAsBytesSync(_epubFixture());
      final paginationMisses = <int>[];

      try {
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: NativeReaderPage(
              book: Book(
                title: 'EPUB transition fixture',
                filePath: epub.path,
                format: 'epub',
                fileModifiedTime: epub
                    .lastModifiedSync()
                    .millisecondsSinceEpoch,
              ),
              onPaginationCacheMiss: paginationMisses.add,
            ),
          ),
        );
        await tester.runAsync(() async {
          for (var attempt = 0; attempt < 60; attempt++) {
            await Future<void>.delayed(const Duration(milliseconds: 50));
            await tester.pump();
            if (find.byType(PageView).evaluate().isNotEmpty) return;
          }
        });
        await _pumpUntil(
          tester,
          () => find.byType(PageView).evaluate().isNotEmpty,
        );
        await tester.idle();
        await tester.pump();
        await _pumpUntil(tester, () => paginationMisses.contains(2));

        final pageView = find.byType(PageView);
        final pageViewWidget = tester.widget<PageView>(pageView);
        final delegate =
            pageViewWidget.childrenDelegate as SliverChildBuilderDelegate;
        final itemCount = delegate.estimatedChildCount!;
        final firstChapterPages = <int>[];
        for (var index = 0; index < itemCount; index++) {
          final leaf = delegate.builder(tester.element(pageView), index)!;
          final metadata = (leaf as ReaderPaperPageLeaf).metadata;
          if (metadata.chapterTitle == 'Chapter 1') {
            firstChapterPages.add(index);
          }
        }
        expect(firstChapterPages, isNotEmpty);

        final controller = pageViewWidget.controller!;
        controller.jumpToPage(firstChapterPages.last);
        await tester.pump();
        await tester.idle();
        await tester.pump();
        await _pumpUntil(tester, () => paginationMisses.contains(3));
        paginationMisses.clear();

        final turn = controller.nextPage(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
        );
        await tester.pumpAndSettle();
        await turn;

        expect(paginationMisses, isEmpty);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        await tester.binding.setSurfaceSize(null);
        debugDefaultTargetPlatformOverride = null;
        directory.deleteSync(recursive: true);
      }
    },
  );

  testWidgets('EPUB horizontal paging continues past image-only front matter', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    await tester.binding.setSurfaceSize(const Size(480, 800));
    SharedPreferences.setMockInitialValues({
      ReaderSettingsStore.pageModeKey: ReaderPageMode.horizontalSlide.name,
      ReaderSettingsStore.txtChapterTitlePageKey: false,
    });
    final directory = Directory.systemTemp.createTempSync(
      'open-reading-epub-front-matter-',
    );
    final epub = File('${directory.path}/front-matter.epub');
    epub.writeAsBytesSync(
      _epubFixture(chapterCount: 14, imageOnlyChapterCount: 8),
    );

    try {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: NativeReaderPage(
            book: Book(
              title: 'EPUB image front matter fixture',
              filePath: epub.path,
              format: 'epub',
              fileModifiedTime: epub.lastModifiedSync().millisecondsSinceEpoch,
            ),
          ),
        ),
      );
      await tester.runAsync(() async {
        for (var attempt = 0; attempt < 60; attempt++) {
          await Future<void>.delayed(const Duration(milliseconds: 50));
          await tester.pump();
          if (find.byType(PageView).evaluate().isNotEmpty) return;
        }
      });
      await _pumpUntil(
        tester,
        () => find.byType(PageView).evaluate().isNotEmpty,
      );

      var reachedBody = false;
      for (var turn = 0; turn < 24 && !reachedBody; turn++) {
        await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 40));
        });
        await tester.pump(const Duration(milliseconds: 50));
        final pageView = tester.widget<PageView>(find.byType(PageView));
        final controller = pageView.controller!;
        final delegate =
            pageView.childrenDelegate as SliverChildBuilderDelegate;
        final currentPage = controller.page?.round() ?? 0;
        final currentLeaf =
            delegate.builder(
                  tester.element(find.byType(PageView)),
                  currentPage,
                )!
                as ReaderPaperPageLeaf;
        if (currentLeaf.metadata.chapterTitle == 'Chapter 9') {
          reachedBody = true;
          break;
        }
        if (delegate.estimatedChildCount! <= currentPage + 1) {
          await _pumpUntil(tester, () {
            final latest = tester.widget<PageView>(find.byType(PageView));
            final latestPage = latest.controller!.page?.round() ?? 0;
            final latestDelegate =
                latest.childrenDelegate as SliverChildBuilderDelegate;
            return latestDelegate.estimatedChildCount! > latestPage + 1;
          });
        }
        final latest = tester.widget<PageView>(find.byType(PageView));
        final latestPage = latest.controller!.page?.round() ?? 0;
        latest.controller!.jumpToPage(latestPage + 1);
        await tester.pump(const Duration(milliseconds: 50));
      }

      expect(reachedBody, isTrue);
      expect(tester.takeException(), isNull);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await tester.binding.setSurfaceSize(null);
      debugDefaultTargetPlatformOverride = null;
      directory.deleteSync(recursive: true);
    }
  });
}

Future<void> _pumpUntil(WidgetTester tester, bool Function() condition) async {
  for (var attempt = 0; attempt < 80; attempt++) {
    await tester.pump(const Duration(milliseconds: 50));
    if (condition()) return;
  }
  fail('Timed out waiting for EPUB reader state.');
}

List<int> _epubFixture({int chapterCount = 4, int imageOnlyChapterCount = 0}) {
  final archive = Archive();
  void add(String name, String content) {
    final bytes = utf8.encode(content);
    archive.addFile(ArchiveFile(name, bytes.length, bytes));
  }

  void addBytes(String name, List<int> bytes) {
    archive.addFile(ArchiveFile(name, bytes.length, bytes));
  }

  add('mimetype', 'application/epub+zip');
  add('META-INF/container.xml', '''<?xml version="1.0"?>
<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
  <rootfiles><rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/></rootfiles>
</container>''');
  add('OEBPS/content.opf', '''<?xml version="1.0" encoding="UTF-8"?>
<package xmlns="http://www.idpf.org/2007/opf" version="2.0" unique-identifier="book-id">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
    <dc:identifier id="book-id">transition-fixture</dc:identifier>
    <dc:title>Transition fixture</dc:title><dc:language>en</dc:language>
  </metadata>
  <manifest>
    <item id="ncx" href="toc.ncx" media-type="application/x-dtbncx+xml"/>
    <item id="stripe" href="stripe.png" media-type="image/png"/>
    ${List.generate(chapterCount, (index) => '<item id="c${index + 1}" href="chapter${index + 1}.xhtml" media-type="application/xhtml+xml"/>').join()}
  </manifest>
  <spine toc="ncx">${List.generate(chapterCount, (index) => '<itemref idref="c${index + 1}"/>').join()}</spine>
</package>''');
  add('OEBPS/toc.ncx', '''<?xml version="1.0" encoding="UTF-8"?>
<ncx xmlns="http://www.daisy.org/z3986/2005/ncx/" version="2005-1">
  <head><meta name="dtb:uid" content="transition-fixture"/></head>
  <docTitle><text>Transition fixture</text></docTitle>
  <navMap>${List.generate(chapterCount, (index) => '<navPoint id="nav${index + 1}" playOrder="${index + 1}"><navLabel><text>Chapter ${index + 1}</text></navLabel><content src="chapter${index + 1}.xhtml"/></navPoint>').join()}</navMap>
</ncx>''');
  addBytes(
    'OEBPS/stripe.png',
    base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
    ),
  );
  for (var chapter = 1; chapter <= chapterCount; chapter++) {
    add('OEBPS/chapter$chapter.xhtml', '''<?xml version="1.0" encoding="UTF-8"?>
<html xmlns="http://www.w3.org/1999/xhtml"><head><title>Chapter $chapter</title></head><body>
${chapter <= imageOnlyChapterCount ? '<img src="stripe.png" alt=""/>' : '<h1>Chapter $chapter</h1>${List.generate(40, (index) => '<p>Chapter $chapter paragraph $index contains enough text to create several deterministic reader pages for transition testing.</p>').join()}'}
</body></html>''');
  }
  return ZipEncoder().encode(archive)!;
}
