import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xxread/core/reader/reader_layout.dart';
import 'package:xxread/core/reader/reader_settings.dart';
import 'package:xxread/l10n/app_localizations.dart';
import 'package:xxread/models/book.dart';
import 'package:xxread/pages/reader/native_reader_page.dart';
import 'package:xxread/services/core/app_settings_service.dart';
import 'package:xxread/services/core/custom_font_service.dart';
import 'package:xxread/services/core/online_font_service.dart';
import 'package:xxread/utils/book_open_transition.dart';
import 'package:xxread/utils/font_catalog_helper.dart';
import 'package:xxread/utils/reader_themes.dart';
import 'package:xxread/widgets/reader_navigation_sheet.dart';
import 'package:xxread/widgets/reader_paper_page_leaf.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const fullscreenChannel = MethodChannel('com.niki.xxread/fullscreen');
  const readerKeysChannel = MethodChannel('com.niki.xxread/reader_keys');
  const readerStatusChannel = MethodChannel('com.niki.xxread/reader_status');
  const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');
  late Directory temporaryDirectory;
  late File bookFile;

  setUp(() {
    SharedPreferences.setMockInitialValues({
      ReaderSettingsStore.pageModeKey: ReaderPageMode.instantPage.name,
    });
    temporaryDirectory = Directory.systemTemp.createTempSync(
      'open-reading-txt-title-page-',
    );
    bookFile = File('${temporaryDirectory.path}/title-page.txt')
      ..writeAsStringSync(
        '第十二章  风暴将至\n\n'
        '天边压着墨色的云。\n\n'
        '风从旷野尽头吹来。',
      );

    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(fullscreenChannel, (_) async => null);
    messenger.setMockMethodCallHandler(readerKeysChannel, (_) async => null);
    messenger.setMockMethodCallHandler(
      pathProviderChannel,
      (call) async => call.method == 'getApplicationSupportDirectory'
          ? temporaryDirectory.path
          : null,
    );
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
    messenger.setMockMethodCallHandler(pathProviderChannel, null);
    if (temporaryDirectory.existsSync()) {
      temporaryDirectory.deleteSync(recursive: true);
    }
  });

  testWidgets('TXT chapter title is a dedicated first page', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: NativeReaderPage(
          book: Book(
            title: '测试书',
            filePath: bookFile.path,
            format: 'txt',
            textEncoding: 'utf8',
            fileModifiedTime: bookFile
                .lastModifiedSync()
                .millisecondsSinceEpoch,
          ),
        ),
      ),
    );

    await tester.runAsync(() async {
      for (var attempt = 0; attempt < 30; attempt++) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await tester.pump();
        if (find
            .byKey(const ValueKey('native-chapter-title-page'))
            .evaluate()
            .isNotEmpty) {
          return;
        }
      }
    });

    await _pumpUntilFound(
      tester,
      find.byKey(const ValueKey('native-chapter-title-page')),
    );

    final title = tester.widget<Text>(
      find.byKey(const ValueKey('native-chapter-title-page')),
    );
    expect(title.data, '第十二章  风暴将至');
    expect(title.textAlign, TextAlign.center);
    expect(title.style?.fontSize, 34);
    expect(find.text('1 / 2'), findsOneWidget);
    expect(_richTextContaining('天边压着墨色的云。'), findsNothing);
  });

  testWidgets('opening placeholder uses the seeded reader theme', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: NativeReaderPage(
          initialTheme: ReaderThemes.pureBlack,
          book: Book(
            title: 'Dark opening',
            filePath: bookFile.path,
            format: 'txt',
            textEncoding: 'utf8',
            fileModifiedTime: bookFile
                .lastModifiedSync()
                .millisecondsSinceEpoch,
          ),
        ),
      ),
    );

    final placeholderBackground = tester.widget<ColoredBox>(
      find
          .descendant(
            of: find.byKey(const ValueKey('native-reader-opening-placeholder')),
            matching: find.byType(ColoredBox),
          )
          .first,
    );
    expect(placeholderBackground.color, ReaderThemes.pureBlack.background);

    expect(
      tester
          .widget<AnimatedPositioned>(
            find.byKey(const ValueKey('native-reader-opening-top-controls')),
          )
          .top,
      -130,
    );
    await tester.tapAt(
      tester
          .getRect(
            find.byKey(const ValueKey('native-reader-opening-placeholder')),
          )
          .center,
    );
    await tester.pump();
    expect(
      tester
          .widgetList<AnimatedPositioned>(
            find.byKey(const ValueKey('native-reader-opening-top-controls')),
          )
          .any((bar) => bar.top == 10),
      isTrue,
    );
  });

  testWidgets('waits for reader font restoration before revealing text', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final appSettings = _ControllableAppSettingsNotifier(temporaryDirectory);
    addTearDown(appSettings.dispose);

    await tester.pumpWidget(
      ChangeNotifierProvider<AppSettingsNotifier>.value(
        value: appSettings,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: NativeReaderPage(
            book: Book(
              title: 'Font restoration',
              filePath: bookFile.path,
              format: 'txt',
              textEncoding: 'utf8',
              fileModifiedTime: bookFile
                  .lastModifiedSync()
                  .millisecondsSinceEpoch,
            ),
          ),
        ),
      ),
    );

    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 120)),
    );
    await tester.pump();
    expect(
      find.byKey(const ValueKey('native-reader-opening-placeholder')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('native-reader-content')), findsNothing);

    appSettings.markReaderFontReady();
    await tester.pump();
    await tester.runAsync(() async {
      for (var attempt = 0; attempt < 30; attempt++) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await tester.pump();
        if (find
            .byKey(const ValueKey('native-reader-content'))
            .evaluate()
            .isNotEmpty) {
          return;
        }
      }
    });
    await _pumpUntilFound(
      tester,
      find.byKey(const ValueKey('native-reader-content')),
    );
  });

  testWidgets(
    'vertical paging preserves the dedicated TXT chapter title page',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        ReaderSettingsStore.pageModeKey: ReaderPageMode.verticalScroll.name,
      });
      await tester.binding.setSurfaceSize(const Size(400, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: NativeReaderPage(
            book: Book(
              title: 'Vertical title test',
              filePath: bookFile.path,
              format: 'txt',
              textEncoding: 'utf8',
              fileModifiedTime: bookFile
                  .lastModifiedSync()
                  .millisecondsSinceEpoch,
            ),
          ),
        ),
      );

      await tester.runAsync(() async {
        for (var attempt = 0; attempt < 30; attempt++) {
          await Future<void>.delayed(const Duration(milliseconds: 50));
          await tester.pump();
          if (find
              .byKey(const ValueKey('native-chapter-title-page'))
              .evaluate()
              .isNotEmpty) {
            return;
          }
        }
      });

      await _pumpUntilFound(
        tester,
        find.byKey(const ValueKey('native-chapter-title-page')),
      );

      expect(
        find.byKey(const ValueKey('native-chapter-title-page')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('native-vertical-reading-window')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'horizontal TOC jump mounts the target title on the first frame and keeps the previous page ready',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        ReaderSettingsStore.pageModeKey: ReaderPageMode.horizontalSlide.name,
      });
      bookFile.writeAsStringSync(
        List.generate(8, (chapterIndex) {
          final chapterNumber = chapterIndex + 1;
          final title = chapterNumber == 8 ? '第8章 远方' : '第$chapterNumber章 测试章节';
          final body = List.generate(
            36,
            (paragraphIndex) =>
                '第$chapterNumber章第$paragraphIndex段正文，用于确保上一章末页已经完成分页。',
          ).join('\n\n');
          return '$title\n\n$body';
        }).join('\n\n'),
      );
      await tester.binding.setSurfaceSize(const Size(400, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: NativeReaderPage(
            book: Book(
              title: '目录远跳测试',
              filePath: bookFile.path,
              format: 'txt',
              textEncoding: 'utf8',
              fileModifiedTime: bookFile
                  .lastModifiedSync()
                  .millisecondsSinceEpoch,
            ),
          ),
        ),
      );
      final readerPageView = find.descendant(
        of: find.byType(NativeReaderPage),
        matching: find.byType(PageView),
      );
      await tester.runAsync(() async {
        for (var attempt = 0; attempt < 40; attempt++) {
          await Future<void>.delayed(const Duration(milliseconds: 50));
          await tester.pump();
          if (readerPageView.evaluate().isNotEmpty) return;
        }
      });
      await _pumpUntilFound(tester, readerPageView);
      final originalController = tester
          .widget<PageView>(readerPageView)
          .controller!;

      await tester.tapAt(tester.getRect(readerPageView).center);
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.format_list_bulleted_rounded));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.descendant(
          of: find.byType(ReaderNavigationSheet),
          matching: find.byType(TextField),
        ),
        '第8章',
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(ReaderNavigationSheet),
          matching: find.text('第8章 远方'),
        ),
      );
      await tester.pump();

      final jumpedController = tester
          .widget<PageView>(readerPageView)
          .controller!;
      expect(jumpedController, isNot(same(originalController)));
      expect(
        find.byKey(const ValueKey('native-reader-positioning-placeholder')),
        findsOneWidget,
      );
      await tester.pump();
      expect(
        tester
            .widgetList<Text>(
              find.byKey(const ValueKey('native-chapter-title-page')),
            )
            .any((title) => title.data == '第8章 远方'),
        isTrue,
      );

      final titlePage = jumpedController.page!;
      final previous = jumpedController.previousPage(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
      await tester.pumpAndSettle();
      await previous;
      final previousPageController = tester
          .widget<PageView>(readerPageView)
          .controller!;
      expect(previousPageController, isNot(same(jumpedController)));
      final pageView = tester.widget<PageView>(readerPageView);
      final delegate = pageView.childrenDelegate as SliverChildBuilderDelegate;
      final visibleLeaf = delegate.builder(
        tester.element(readerPageView),
        previousPageController.page!.round(),
      );
      expect(visibleLeaf, isA<ReaderPaperPageLeaf>());
      final metadata = (visibleLeaf! as ReaderPaperPageLeaf).metadata;
      expect(metadata.chapterTitle, '第7章 测试章节');
      expect(metadata.pageNumber, metadata.pageCount);
      expect(titlePage, greaterThan(0));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('TXT initialization preloads behind the cover route', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final navigatorKey = GlobalKey<NavigatorState>();
    final coverKey = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Center(
            child: SizedBox(
              key: coverKey,
              width: 120,
              height: 180,
              child: const ColoredBox(color: Colors.brown),
            ),
          ),
        ),
      ),
    );
    final animation = BookOpenAnimation.fromCoverKey(
      coverKey,
      radius: BorderRadius.circular(12),
      coverBuilder: (_) => const ColoredBox(color: Colors.brown),
    );

    navigatorKey.currentState!.push<void>(
      BookOpenTransition.createRoute<void>(
        NativeReaderPage(
          book: Book(
            title: 'Transition test',
            filePath: bookFile.path,
            format: 'txt',
            textEncoding: 'utf8',
            fileModifiedTime: bookFile
                .lastModifiedSync()
                .millisecondsSinceEpoch,
          ),
          initialTheme: ReaderThemes.day,
        ),
        animation: animation,
        readerBackgroundColor: ReaderThemes.day.background,
        waitForReaderReady: true,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(
      find.byKey(const ValueKey('book-open-transition-deferred-page')),
      findsNothing,
    );
    expect(find.byType(NativeReaderPage), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    await tester.runAsync(() async {
      for (var attempt = 0; attempt < 30; attempt++) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await tester.pump();
        if (find
            .byKey(const ValueKey('native-chapter-title-page'))
            .evaluate()
            .isNotEmpty) {
          return;
        }
      }
    });
    expect(
      find.byKey(const ValueKey('native-chapter-title-page')),
      findsOneWidget,
    );
    final readerOpacity = tester.widget<Opacity>(
      find.byKey(const ValueKey('book-open-transition-reader-opacity')),
    );
    expect(readerOpacity.opacity, lessThan(1));

    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
  });
}

class _ControllableAppSettingsNotifier extends AppSettingsNotifier {
  _ControllableAppSettingsNotifier(Directory directory)
    : super(
        customFontService: CustomFontService(
          supportDirectory: () async => directory,
          registrar: (_, _) async {},
        ),
        onlineFontService: OnlineFontService(
          supportDirectory: () async => directory,
          registrar: (_, _, _) async {},
        ),
      );

  bool _readerFontReady = false;

  @override
  bool get isInitialized => _readerFontReady;

  @override
  FontOption get readerFont => FontCatalog.systemFont;

  void markReaderFontReady() {
    _readerFontReady = true;
    notifyListeners();
  }
}

Finder _richTextContaining(String text) => find.byWidgetPredicate(
  (widget) => widget is RichText && widget.text.toPlainText().contains(text),
);

Future<void> _pumpUntilFound(WidgetTester tester, Finder finder) async {
  for (var attempt = 0; attempt < 60; attempt++) {
    await tester.pump(const Duration(milliseconds: 100));
    if (finder.evaluate().isNotEmpty) return;
  }
  final texts = tester
      .widgetList<Text>(find.byType(Text))
      .map((widget) => widget.data)
      .whereType<String>()
      .toList();
  fail(
    'Timed out waiting for $finder. Texts: $texts. '
    'Exception: ${tester.takeException()}',
  );
}
