import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import 'package:xxread/core/reader/canonical_locator.dart';
import 'package:xxread/core/reader/reader_layout.dart';
import 'package:xxread/core/reader/reader_settings.dart';
import 'package:xxread/l10n/app_localizations.dart';
import 'package:xxread/models/book.dart';
import 'package:xxread/pages/reader/native_reader_page.dart';
import 'package:xxread/widgets/reader_paper_page_leaf.dart';

void main() {
  testWidgets(
    'EPUB horizontal reader paints the restored page on its first frame',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      await tester.binding.setSurfaceSize(const Size(480, 800));
      SharedPreferences.setMockInitialValues({
        ReaderSettingsStore.pageModeKey: ReaderPageMode.horizontalSlide.name,
      });
      final directory = Directory.systemTemp.createTempSync(
        'open-reading-epub-initial-progress-',
      );
      final epub = File('${directory.path}/initial-progress.epub')
        ..writeAsBytesSync(_epubFixture());
      final locator = CanonicalLocator.fromComponents(
        format: BookFormat.epub,
        chapterId: 'chapter2.xhtml',
        offset: 2400,
        excerpt: 'Chapter 2 restored position',
      );

      try {
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: NativeReaderPage(
              book: Book(
                title: 'EPUB initial progress fixture',
                filePath: epub.path,
                format: 'epub',
                currentPage: 0,
                lastCanonicalLocator: LocatorCodec.encodeCanonicalLocator(
                  locator,
                ),
                fileModifiedTime: epub
                    .lastModifiedSync()
                    .millisecondsSinceEpoch,
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

        final pageView = tester.widget<PageView>(find.byType(PageView));
        final controller = pageView.controller!;
        final delegate =
            pageView.childrenDelegate as SliverChildBuilderDelegate;
        final initialLeaf =
            delegate.builder(
                  tester.element(find.byType(PageView)),
                  controller.initialPage,
                )!
                as ReaderPaperPageLeaf;

        expect(controller.initialPage, greaterThan(0));
        expect(initialLeaf.metadata.chapterTitle, 'Chapter 2');
        expect(initialLeaf.metadata.pageNumber, greaterThan(1));
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        await tester.binding.setSurfaceSize(null);
        debugDefaultTargetPlatformOverride = null;
        directory.deleteSync(recursive: true);
      }
    },
  );

  testWidgets(
    'EPUB continuous scroll hides the chapter opening until restore completes',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      await tester.binding.setSurfaceSize(const Size(480, 800));
      SharedPreferences.setMockInitialValues({
        ReaderSettingsStore.pageModeKey: ReaderPageMode.verticalScroll.name,
        ReaderSettingsStore.scrollByChapterKey: false,
      });
      final directory = Directory.systemTemp.createTempSync(
        'open-reading-epub-continuous-progress-',
      );
      final epub = File('${directory.path}/continuous-progress.epub')
        ..writeAsBytesSync(_epubFixture());
      final locator = CanonicalLocator.fromComponents(
        format: BookFormat.epub,
        chapterId: 'chapter2.xhtml',
        offset: 2400,
        excerpt: 'Chapter 2 restored position',
      );

      try {
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: NativeReaderPage(
              book: Book(
                title: 'EPUB continuous progress fixture',
                filePath: epub.path,
                format: 'epub',
                currentPage: 0,
                lastCanonicalLocator: LocatorCodec.encodeCanonicalLocator(
                  locator,
                ),
                fileModifiedTime: epub
                    .lastModifiedSync()
                    .millisecondsSinceEpoch,
              ),
            ),
          ),
        );
        await tester.runAsync(() async {
          for (var attempt = 0; attempt < 60; attempt++) {
            await Future<void>.delayed(const Duration(milliseconds: 50));
            await tester.pump();
            if (find.byType(ScrollablePositionedList).evaluate().isNotEmpty) {
              return;
            }
          }
        });
        await _pumpUntil(
          tester,
          () => find.byType(ScrollablePositionedList).evaluate().isNotEmpty,
        );

        expect(
          find.byKey(const ValueKey('native-reader-positioning-placeholder')),
          findsOneWidget,
        );

        await _pumpUntil(
          tester,
          () => find
              .byKey(const ValueKey('native-reader-positioning-placeholder'))
              .evaluate()
              .isEmpty,
        );
        final status = tester.widget<Text>(
          find.byKey(const ValueKey('native-reader-status')),
        );
        final pageMatches = RegExp(r'(\d+)/(\d+)').allMatches(status.data!);
        expect(int.parse(pageMatches.last.group(1)!), greaterThan(1));
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        await tester.binding.setSurfaceSize(null);
        debugDefaultTargetPlatformOverride = null;
        directory.deleteSync(recursive: true);
      }
    },
  );
}

Future<void> _pumpUntil(WidgetTester tester, bool Function() condition) async {
  for (var attempt = 0; attempt < 80; attempt++) {
    await tester.pump(const Duration(milliseconds: 50));
    if (condition()) return;
  }
  fail('Timed out waiting for EPUB reader state.');
}

List<int> _epubFixture() {
  final archive = Archive();
  void add(String name, String content) {
    final bytes = utf8.encode(content);
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
    <dc:identifier id="book-id">initial-progress-fixture</dc:identifier>
    <dc:title>Initial progress fixture</dc:title><dc:language>en</dc:language>
  </metadata>
  <manifest>
    <item id="ncx" href="toc.ncx" media-type="application/x-dtbncx+xml"/>
    ${List.generate(3, (index) => '<item id="c${index + 1}" href="chapter${index + 1}.xhtml" media-type="application/xhtml+xml"/>').join()}
  </manifest>
  <spine toc="ncx">${List.generate(3, (index) => '<itemref idref="c${index + 1}"/>').join()}</spine>
</package>''');
  add('OEBPS/toc.ncx', '''<?xml version="1.0" encoding="UTF-8"?>
<ncx xmlns="http://www.daisy.org/z3986/2005/ncx/" version="2005-1">
  <head><meta name="dtb:uid" content="initial-progress-fixture"/></head>
  <docTitle><text>Initial progress fixture</text></docTitle>
  <navMap>${List.generate(3, (index) => '<navPoint id="nav${index + 1}" playOrder="${index + 1}"><navLabel><text>Chapter ${index + 1}</text></navLabel><content src="chapter${index + 1}.xhtml"/></navPoint>').join()}</navMap>
</ncx>''');
  for (var chapter = 1; chapter <= 3; chapter++) {
    add('OEBPS/chapter$chapter.xhtml', '''<?xml version="1.0" encoding="UTF-8"?>
<html xmlns="http://www.w3.org/1999/xhtml"><head><title>Chapter $chapter</title></head><body>
<h1>Chapter $chapter</h1>
${List.generate(80, (index) => '<p>Chapter $chapter paragraph $index contains enough text to create deterministic reader pages and restore a saved position without flashing the chapter opening.</p>').join()}
</body></html>''');
  }
  return ZipEncoder().encode(archive)!;
}
