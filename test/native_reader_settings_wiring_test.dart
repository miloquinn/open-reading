import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xxread/core/reader/reader_layout.dart';
import 'package:xxread/core/reader/reader_settings.dart';
import 'package:xxread/l10n/app_localizations.dart';
import 'package:xxread/models/book.dart';
import 'package:xxread/pages/native_reader_page.dart';
import 'package:xxread/widgets/reader_shader_page_curl.dart';

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
      ReaderSettingsStore.pageTurnStyleKey:
          ReaderPageTurnStyle.classicFold.name,
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
      'native reader loads and persists shared typography and turn style',
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

      expect(
        tester
            .widgetList<ReaderShaderPageCurl>(
              find.byType(ReaderShaderPageCurl),
            )
            .every(
              (curl) => curl.turnStyle == ReaderPageTurnStyle.classicFold,
            ),
        isTrue,
      );

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

      await tester.tap(find.byIcon(Icons.auto_stories_outlined));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<RadioGroup<ReaderPageTurnStyle>>(
              find.byType(RadioGroup<ReaderPageTurnStyle>),
            )
            .groupValue,
        ReaderPageTurnStyle.classicFold,
      );

      final cylinder = find.byWidgetPredicate(
        (widget) =>
            widget is RadioListTile<ReaderPageTurnStyle> &&
            widget.value == ReaderPageTurnStyle.cylinder,
      );
      await tester.tap(cylinder);
      await tester.pumpAndSettle();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt(ReaderSettingsStore.firstLineIndentKey), 4);
      expect(prefs.getInt(ReaderSettingsStore.paragraphSpacingKey), 2);
      expect(
        prefs.getString(ReaderSettingsStore.pageTurnStyleKey),
        ReaderPageTurnStyle.cylinder.name,
      );
      expect(
        tester
            .widgetList<ReaderShaderPageCurl>(
              find.byType(ReaderShaderPageCurl),
            )
            .every(
              (curl) => curl.turnStyle == ReaderPageTurnStyle.cylinder,
            ),
        isTrue,
      );
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
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
      await tester.pumpWidget(
        MaterialApp(
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

      final curlFinder = find.byType(ReaderShaderPageCurl);
      expect(curlFinder, findsNWidgets(2));
      final curls =
          tester.widgetList<ReaderShaderPageCurl>(curlFinder).toList();
      expect(curls.every((curl) => curl.edgeDragOnly), isTrue);

      final rects = curlFinder
          .evaluate()
          .map((element) => tester.getRect(find.byWidget(element.widget)))
          .toList()
        ..sort((left, right) => left.left.compareTo(right.left));
      expect(rects[0].right, closeTo(588, 0.1));
      expect(rects[1].left, closeTo(612, 0.1));
      expect(rects[1].right, closeTo(1200, 0.1));
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await tester.binding.setSurfaceSize(null);
      if (tabletBook.existsSync()) tabletBook.deleteSync();
      debugDefaultTargetPlatformOverride = null;
    }
  });
}

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
