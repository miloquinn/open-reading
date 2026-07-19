import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:xxread/core/reader/reader_page_turn_geometry.dart';
import 'package:xxread/core/reader/reader_layout.dart';
import 'package:xxread/core/reader/reader_settings.dart';
import 'package:xxread/l10n/app_localizations.dart';
import 'package:xxread/models/book.dart';
import 'package:xxread/pages/reader/native_reader_page.dart';
import 'package:xxread/widgets/reader_paper_page_leaf.dart';
import 'package:xxread/widgets/reader_shader_page_curl.dart';
import 'package:xxread/widgets/reader_top_information_bar.dart';

void main() {
  late File bookFile;
  const fullscreenChannel = MethodChannel('com.niki.xxread/fullscreen');
  const readerKeysChannel = MethodChannel('com.niki.xxread/reader_keys');
  const readerStatusChannel = MethodChannel('com.niki.xxread/reader_status');

  setUp(() {
    SharedPreferences.setMockInitialValues({
      ReaderSettingsStore.pageModeKey: ReaderPageMode.pageCurl.name,
      ReaderSettingsStore.firstLineIndentKey: 3,
      ReaderSettingsStore.paragraphSpacingKey: 1,
    });
    bookFile = File('test/fixtures/reader_settings_test.html');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(fullscreenChannel, (_) async => null);
    messenger.setMockMethodCallHandler(readerKeysChannel, (_) async => null);
    messenger.setMockMethodCallHandler(
      readerStatusChannel,
      (_) async => <String, Object?>{'level': 80, 'charging': false},
    );
  });

  tearDown(() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(fullscreenChannel, null);
    messenger.setMockMethodCallHandler(readerKeysChannel, null);
    messenger.setMockMethodCallHandler(readerStatusChannel, null);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets(
      'native reader loads and persists shared typography with classic fold',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: NativeReaderPage(
            book: Book(
              title: 'Settings test',
              filePath: bookFile.path,
              format: 'html',
              fileModifiedTime:
                  bookFile.lastModifiedSync().millisecondsSinceEpoch,
            ),
          ),
        ),
      );
      await tester.runAsync(() async {
        for (var attempt = 0; attempt < 20; attempt++) {
          await Future<void>.delayed(const Duration(milliseconds: 50));
          await tester.pump();
          if (find.byType(ReaderShaderPageCurl).evaluate().isNotEmpty) return;
        }
      });
      await _pumpUntilFound(tester, find.byType(ReaderShaderPageCurl));

      tester
          .widget<IconButton>(
            find.ancestor(
              of: find.byIcon(Icons.tune_rounded),
              matching: find.byType(IconButton),
            ),
          )
          .onPressed!();
      await tester.pumpAndSettle();

      final indentFinder = find.descendant(
        of: find.byKey(const ValueKey('reader-first-line-indent-slider')),
        matching: find.byType(Slider),
      );
      final spacingFinder = find.descendant(
        of: find.byKey(const ValueKey('reader-paragraph-spacing-slider')),
        matching: find.byType(Slider),
      );
      expect(tester.widget<Slider>(indentFinder).value, 3);
      expect(tester.widget<Slider>(spacingFinder).value, 1);

      tester.widget<Slider>(indentFinder).onChanged!(4);
      await tester.pump();
      tester.widget<Slider>(indentFinder).onChangeEnd!(4);
      tester.widget<Slider>(spacingFinder).onChanged!(2);
      await tester.pump();
      tester.widget<Slider>(spacingFinder).onChangeEnd!(2);
      await tester.pumpAndSettle();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt(ReaderSettingsStore.firstLineIndentKey), 4);
      expect(prefs.getInt(ReaderSettingsStore.paragraphSpacingKey), 2);
      expect(find.byIcon(Icons.auto_stories_outlined), findsNothing);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('native vertical paging uses positioned pages and fixed chrome',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    await tester.binding.setSurfaceSize(const Size(400, 800));
    final verticalBook = File(
      '${Directory.systemTemp.path}/open-reading-vertical-paging.html',
    );
    verticalBook.writeAsStringSync(bookFile.readAsStringSync());
    SharedPreferences.setMockInitialValues({
      ReaderSettingsStore.pageModeKey: ReaderPageMode.verticalScroll.name,
      ReaderSettingsStore.scrollByChapterKey: false,
    });
    try {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: NativeReaderPage(
            book: Book(
              title: 'Vertical paging test',
              filePath: verticalBook.path,
              format: 'html',
              fileModifiedTime:
                  verticalBook.lastModifiedSync().millisecondsSinceEpoch,
            ),
          ),
        ),
      );
      await tester.runAsync(() async {
        for (var attempt = 0; attempt < 30; attempt++) {
          await Future<void>.delayed(const Duration(milliseconds: 50));
          await tester.pump();
          if (find.byType(ScrollablePositionedList).evaluate().isNotEmpty) {
            return;
          }
        }
      });
      await _pumpUntilFound(tester, find.byType(ScrollablePositionedList));

      expect(
        find.byKey(const ValueKey('native-reader-viewport-title')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('native-reader-status')),
        findsOneWidget,
      );
      final windowFinder =
          find.byKey(const ValueKey('native-vertical-reading-window'));
      final window = tester.widget<Padding>(windowFinder);
      final windowPadding = window.padding.resolve(TextDirection.ltr);
      final listRect = tester.getRect(find.byType(ScrollablePositionedList));
      expect(windowPadding.vertical, greaterThan(0));
      expect(listRect.top, closeTo(windowPadding.top, 0.1));
      expect(listRect.bottom, closeTo(800 - windowPadding.bottom, 0.1));

      final pageCells = find.byWidgetPredicate(
        (widget) =>
            widget is SizedBox &&
            widget.key is ValueKey<String> &&
            (widget.key! as ValueKey<String>)
                .value
                .startsWith('native-vertical-page:'),
      );
      expect(pageCells, findsWidgets);
      expect(
        tester.widget<SizedBox>(pageCells.first).height,
        closeTo(listRect.height, 0.1),
      );

      final surface = find.byKey(const ValueKey('native-reader-surface'));
      final hiddenTop = tester.widget<AnimatedPositioned>(
        find.byKey(const ValueKey('native-reader-top-controls')),
      );
      expect(hiddenTop.top, -130);

      final drag = await tester.startGesture(tester.getRect(surface).center);
      await drag.moveBy(const Offset(0, -120));
      await drag.up();
      await tester.pump();
      expect(
        tester
            .widget<AnimatedPositioned>(
              find.byKey(const ValueKey('native-reader-top-controls')),
            )
            .top,
        -130,
      );

      await tester.tapAt(tester.getRect(surface).center);
      await tester.pump();
      expect(
        tester
            .widget<AnimatedPositioned>(
              find.byKey(const ValueKey('native-reader-top-controls')),
            )
            .top,
        greaterThan(-130),
      );
      expect(tester.takeException(), isNull);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await tester.binding.setSurfaceSize(null);
      if (verticalBook.existsSync()) verticalBook.deleteSync();
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('native horizontal reader resolves a side tap before animating',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    await tester.binding.setSurfaceSize(const Size(480, 800));
    final horizontalBook = File(
      '${Directory.systemTemp.path}/open-reading-native-tap-animation.html',
    );
    horizontalBook.writeAsStringSync(
      '<!doctype html><html><body><h1>Tap animation</h1>'
      '${List.generate(180, (index) => '<p>Paragraph $index gives the native '
          'reader enough pages to verify animated side-tap navigation.</p>').join()}'
      '</body></html>',
    );
    SharedPreferences.setMockInitialValues({
      ReaderSettingsStore.pageModeKey: ReaderPageMode.horizontalSlide.name,
      ReaderSettingsStore.tapPageAnimationKey: true,
    });
    try {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: NativeReaderPage(
            book: Book(
              title: 'Native tap animation',
              filePath: horizontalBook.path,
              format: 'html',
              fileModifiedTime:
                  horizontalBook.lastModifiedSync().millisecondsSinceEpoch,
            ),
          ),
        ),
      );
      await tester.runAsync(() async {
        for (var attempt = 0; attempt < 30; attempt++) {
          await Future<void>.delayed(const Duration(milliseconds: 50));
          await tester.pump();
          if (find.byType(PageView).evaluate().isNotEmpty) return;
        }
      });
      await _pumpUntilFound(tester, find.byType(PageView));

      final statusFinder = find.byKey(const ValueKey('native-reader-status'));
      int currentPage() => int.parse(
            RegExp(r'(\d+)/(\d+)')
                .allMatches(tester.widget<Text>(statusFinder).data!)
                .toList()[1]
                .group(1)!,
          );
      final initialPage = currentPage();

      await tester.tapAt(const Offset(460, 400));
      await tester.pumpAndSettle();

      expect(currentPage(), initialPage + 1);
      expect(tester.takeException(), isNull);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await tester.binding.setSurfaceSize(null);
      if (horizontalBook.existsSync()) horizontalBook.deleteSync();
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets(
      'native horizontal reader changes immediately when tap animation is off',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    await tester.binding.setSurfaceSize(const Size(480, 800));
    final horizontalBook = File(
      '${Directory.systemTemp.path}/open-reading-native-tap-instant.html',
    );
    horizontalBook.writeAsStringSync(
      '<!doctype html><html><body><h1>Instant tap</h1>'
      '${List.generate(180, (index) => '<p>Paragraph $index gives the native '
          'reader enough pages to verify instant side-tap navigation.</p>').join()}'
      '</body></html>',
    );
    SharedPreferences.setMockInitialValues({
      ReaderSettingsStore.pageModeKey: ReaderPageMode.horizontalSlide.name,
      ReaderSettingsStore.tapPageAnimationKey: false,
    });
    try {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: NativeReaderPage(
            book: Book(
              title: 'Native instant tap',
              filePath: horizontalBook.path,
              format: 'html',
              fileModifiedTime:
                  horizontalBook.lastModifiedSync().millisecondsSinceEpoch,
            ),
          ),
        ),
      );
      await tester.runAsync(() async {
        for (var attempt = 0; attempt < 30; attempt++) {
          await Future<void>.delayed(const Duration(milliseconds: 50));
          await tester.pump();
          if (find.byType(PageView).evaluate().isNotEmpty) return;
        }
      });
      await _pumpUntilFound(tester, find.byType(PageView));

      final statusFinder = find.byKey(const ValueKey('native-reader-status'));
      int currentPage() => int.parse(
            RegExp(r'(\d+)/(\d+)')
                .allMatches(tester.widget<Text>(statusFinder).data!)
                .toList()[1]
                .group(1)!,
          );
      final initialPage = currentPage();

      await tester.tapAt(const Offset(460, 400));
      await tester.pump();

      expect(currentPage(), initialPage + 1);
      expect(tester.takeException(), isNull);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await tester.binding.setSurfaceSize(null);
      if (horizontalBook.existsSync()) horizontalBook.deleteSync();
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('tablet page curl keeps two leaves around a fixed center spine',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    final tabletBook = File(
      '${Directory.systemTemp.path}/open-reading-tablet-spread.html',
    );
    tabletBook.writeAsStringSync(
      '<!doctype html><html><body><h1>Tablet spread</h1>'
      '${List.generate(240, (index) => '<p>Paragraph $index verifies that '
          'the center binding remains fixed while outer page edges turn.</p>').join()}'
      '</body></html>',
    );
    try {
      await tester.pumpWidget(_buildTabletNativeReader(tabletBook));
      await tester.runAsync(() async {
        for (var attempt = 0; attempt < 30; attempt++) {
          await Future<void>.delayed(const Duration(milliseconds: 50));
          await tester.pump();
          if (find.byType(ReaderShaderPageCurl).evaluate().length >= 2) return;
        }
      });
      await _pumpUntilFound(tester, find.byType(ReaderShaderPageCurl));

      final curlFinder = find.byType(ReaderShaderPageCurl);
      expect(curlFinder, findsNWidgets(2));
      expect(find.byType(ReaderPageCurlSpread), findsOneWidget);
      final spread = tester.widget<ReaderPageCurlSpread>(
        find.byType(ReaderPageCurlSpread),
      );
      expect(spread.coordinator.gutterWidth, 24);
      final curls =
          tester.widgetList<ReaderShaderPageCurl>(curlFinder).toList();
      expect(curls.every((curl) => curl.edgeDragOnly), isTrue);
      expect(curls[0].bindingEdge, ReaderPageBindingEdge.right);
      expect(curls[1].bindingEdge, ReaderPageBindingEdge.left);
      expect(
        (curls[0].currentPage.child as ReaderPaperPageLeaf)
            .topInformationLayout,
        ReaderTopInformationLayout.spreadLeft,
      );
      expect(
        (curls[1].currentPage.child as ReaderPaperPageLeaf)
            .topInformationLayout,
        ReaderTopInformationLayout.spreadRight,
      );
      final rightCurl = curls[1];
      final currentRightLeaf =
          rightCurl.currentPage.child as ReaderPaperPageLeaf;
      final nextLeftLeaf =
          rightCurl.outgoingBackPage!.child as ReaderPaperPageLeaf;
      final nextRightLeaf = rightCurl.forwardPage!.child as ReaderPaperPageLeaf;
      expect(
        nextLeftLeaf.metadata.pageNumber,
        currentRightLeaf.metadata.pageNumber + 1,
      );
      expect(
        nextRightLeaf.metadata.pageNumber,
        nextLeftLeaf.metadata.pageNumber + 1,
      );
      expect(
        nextLeftLeaf.pageNumberPlacement,
        ReaderPageNumberPlacement.bottomLeft,
      );
      expect(
        nextLeftLeaf.topInformationLayout,
        ReaderTopInformationLayout.spreadLeft,
      );
      expect(
        nextRightLeaf.topInformationLayout,
        ReaderTopInformationLayout.spreadRight,
      );

      final rects = curlFinder
          .evaluate()
          .map((element) => tester.getRect(find.byWidget(element.widget)))
          .toList()
        ..sort((left, right) => left.left.compareTo(right.left));
      expect(rects[0].right, closeTo(588, 0.1));
      expect(rects[1].left, closeTo(612, 0.1));
      expect(rects[1].right, closeTo(1200, 0.1));

      final rightController = rightCurl.controller!;
      final centerGesture = await tester.startGesture(
        Offset(rects[1].left + 2, rects[1].center.dy),
      );
      await centerGesture.moveBy(const Offset(-90, 0));
      await tester.pump();
      expect(rightController.debugMotion, isNull);
      await centerGesture.cancel();

      final rightGesture = await tester.startGesture(
        Offset(rects[1].right - 2, rects[1].center.dy),
      );
      await rightGesture.moveBy(const Offset(-90, -45));
      await tester.pump();
      await rightGesture.moveBy(const Offset(-20, 0));
      await tester.pump();
      expect(rightController.debugMotion, ReaderPageTurnMotion.outgoing);
      expect(rightController.debugActiveSourceIsCurrent, isTrue);
      expect(
        spread.coordinator.activeBindingEdge,
        ReaderPageBindingEdge.left,
      );
      await rightGesture.cancel();
      for (var frame = 0; frame < 24; frame++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await tester.binding.setSurfaceSize(null);
      if (tabletBook.existsSync()) tabletBook.deleteSync();
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('tablet can disable the two-page reader layout', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    SharedPreferences.setMockInitialValues({
      ReaderSettingsStore.pageModeKey: ReaderPageMode.pageCurl.name,
      ReaderSettingsStore.tabletTwoPageKey: false,
    });
    final tabletBook = File(
      '${Directory.systemTemp.path}/open-reading-tablet-single-page.html',
    );
    tabletBook.writeAsStringSync(
      '<!doctype html><html><body><h1>Tablet single page</h1>'
      '${List.generate(160, (index) => '<p>Paragraph $index.</p>').join()}'
      '</body></html>',
    );
    try {
      await tester.pumpWidget(_buildTabletNativeReader(tabletBook));
      await tester.runAsync(() async {
        for (var attempt = 0; attempt < 30; attempt++) {
          await Future<void>.delayed(const Duration(milliseconds: 50));
          await tester.pump();
          if (find.byType(ReaderShaderPageCurl).evaluate().isNotEmpty) return;
        }
      });
      await _pumpUntilFound(tester, find.byType(ReaderShaderPageCurl));

      expect(find.byType(ReaderShaderPageCurl), findsOneWidget);
      expect(find.byType(ReaderPageCurlSpread), findsNothing);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await tester.binding.setSurfaceSize(null);
      if (tabletBook.existsSync()) tabletBook.deleteSync();
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('tablet spreads keep every chapter on a stable left-page parity',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    final parityBook = File(
      '${Directory.systemTemp.path}/open-reading-tablet-parity.html',
    );
    parityBook.writeAsStringSync(
      '<!doctype html><html><body>'
      '<h1>Short first chapter</h1><p>One short page.</p>'
      '<h1>Long second chapter</h1>'
      '${List.generate(220, (index) => '<p>Second chapter paragraph $index '
          'keeps its first page on the left after an odd previous chapter.'
          '</p>').join()}'
      '</body></html>',
    );
    try {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: NativeReaderPage(
            book: Book(
              title: 'Tablet parity',
              filePath: parityBook.path,
              format: 'html',
              currentPage: 1,
              fileModifiedTime:
                  parityBook.lastModifiedSync().millisecondsSinceEpoch,
            ),
          ),
        ),
      );
      await tester.runAsync(() async {
        for (var attempt = 0; attempt < 30; attempt++) {
          await Future<void>.delayed(const Duration(milliseconds: 50));
          await tester.pump();
          if (find.byType(ReaderShaderPageCurl).evaluate().length >= 2) return;
        }
      });
      await _pumpUntilFound(tester, find.byType(ReaderShaderPageCurl));

      final curls = tester
          .widgetList<ReaderShaderPageCurl>(find.byType(ReaderShaderPageCurl))
          .toList();
      expect(curls, hasLength(2));
      expect(
        curls.map((curl) => curl.currentPage.key.pageIdentity),
        everyElement(contains(':html-1:')),
      );
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await tester.binding.setSurfaceSize(null);
      if (parityBook.existsSync()) parityBook.deleteSync();
      debugDefaultTargetPlatformOverride = null;
    }
  });
}

Widget _buildTabletNativeReader(File tabletBook) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: NativeReaderPage(
        book: Book(
          title: 'Tablet spread',
          filePath: tabletBook.path,
          format: 'html',
          fileModifiedTime:
              tabletBook.lastModifiedSync().millisecondsSinceEpoch,
        ),
      ),
    );

Future<void> _pumpUntilFound(WidgetTester tester, Finder finder) async {
  for (var attempt = 0; attempt < 50; attempt++) {
    await tester.pump(const Duration(milliseconds: 100));
    if (finder.evaluate().isNotEmpty) return;
  }
  final texts = tester
      .widgetList<Text>(find.byType(Text))
      .map((widget) => widget.data)
      .whereType<String>()
      .toList();
  fail(
    'Timed out waiting for $finder; '
    'texts=$texts, coloredBoxes=${find.byType(ColoredBox).evaluate().length}, '
    'progress=${find.byType(CircularProgressIndicator).evaluate().length}, '
    'scaffolds=${find.byType(Scaffold).evaluate().length}, '
    'exception=${tester.takeException()}.',
  );
}
