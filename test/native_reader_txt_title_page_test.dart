import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xxread/core/reader/reader_layout.dart';
import 'package:xxread/core/reader/reader_settings.dart';
import 'package:xxread/l10n/app_localizations.dart';
import 'package:xxread/models/book.dart';
import 'package:xxread/pages/reader/native_reader_page.dart';
import 'package:xxread/utils/book_open_transition.dart';

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
            fileModifiedTime:
                bookFile.lastModifiedSync().millisecondsSinceEpoch,
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
  testWidgets('vertical paging preserves the dedicated TXT chapter title page',
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
            fileModifiedTime:
                bookFile.lastModifiedSync().millisecondsSinceEpoch,
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
  });

  testWidgets('TXT initialization waits until the cover route settles',
      (tester) async {
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
            fileModifiedTime:
                bookFile.lastModifiedSync().millisecondsSinceEpoch,
          ),
        ),
        animation: animation,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(
      find.byKey(const ValueKey('book-open-transition-deferred-page')),
      findsOneWidget,
    );
    expect(find.byType(NativeReaderPage), findsNothing);
    expect(
      find.byKey(const ValueKey('native-chapter-title-page')),
      findsNothing,
    );

    await tester.pump(const Duration(milliseconds: 300));
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
  });
}

Finder _richTextContaining(String text) => find.byWidgetPredicate(
      (widget) =>
          widget is RichText && widget.text.toPlainText().contains(text),
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
