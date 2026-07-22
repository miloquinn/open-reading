import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xxread/l10n/app_localizations.dart';
import 'package:xxread/pages/library/import_book/import_book_page.dart';
import 'package:xxread/pages/library/import_book/import_book_widgets.dart';
import 'package:xxread/services/books/book_import_models.dart';

void main() {
  testWidgets('手机布局先展示来源选择和空队列', (tester) async {
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_testApp());
    await tester.pumpAndSettle();

    expect(find.text('添加书籍'), findsOneWidget);
    expect(find.text('选择文件'), findsOneWidget);
    expect(find.text('还没有选择书籍'), findsOneWidget);
    expect(find.byType(ImportSourcePanel), findsOneWidget);
  });

  testWidgets('宽屏布局同时保留来源面板和导入队列', (tester) async {
    tester.view.physicalSize = const Size(1100, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_testApp());
    await tester.pumpAndSettle();

    expect(find.byType(ImportSourcePanel), findsOneWidget);
    expect(find.text('导入队列（0）'), findsOneWidget);
    expect(find.text('还没有选择书籍'), findsOneWidget);
  });

  testWidgets('does not resize for stale file-picker keyboard insets', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = const FakeViewPadding(bottom: 760);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);

    await tester.pumpWidget(_testApp());
    await tester.pumpAndSettle();

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(scaffold.resizeToAvoidBottomInset, isFalse);
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('import-page-header'))).dy,
      greaterThanOrEqualTo(0),
    );
    expect(find.byType(ImportSourcePanel), findsOneWidget);
  });

  testWidgets('选书确认页会限制异常安全区并固定整宽导入操作', (tester) async {
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(top: 44, bottom: 760);
    tester.view.viewPadding = const FakeViewPadding(top: 44, bottom: 760);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPadding);
    addTearDown(tester.view.resetViewPadding);

    await tester.pumpWidget(
      _testApp(
        initialSources: const [
          BookImportSource(
            id: 'picked-book',
            kind: BookImportSourceKind.filePicker,
            ownership: BookImportOwnership.externalCopy,
            displayName: '测试书籍.epub',
            extension: 'epub',
            locator: '/tmp/test.epub',
            sizeBytes: 1024,
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('测试书籍.epub'), findsOneWidget);
    expect(find.text('导入 1 本'), findsOneWidget);
    expect(find.byType(ImportSourcePanel), findsNothing);

    final headerRect = tester.getRect(
      find.byKey(const ValueKey('import-page-header')),
    );
    final actionRect = tester.getRect(
      find.byKey(const ValueKey('import-primary-action')),
    );
    expect(headerRect.top, greaterThanOrEqualTo(44));
    expect(actionRect.top, greaterThan(headerRect.bottom));
    expect(actionRect.bottom, lessThanOrEqualTo(900));
    expect(actionRect.width, greaterThan(300));

    await tester.tap(find.text('选择文件'));
    await tester.pumpAndSettle();

    final sourcePanelRect = tester.getRect(find.byType(ImportSourcePanel));
    expect(sourcePanelRect.top, greaterThanOrEqualTo(0));
    expect(sourcePanelRect.bottom, lessThanOrEqualTo(900));
  });
}

Widget _testApp({List<BookImportSource> initialSources = const []}) {
  return MaterialApp(
    locale: const Locale('zh'),
    localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: ImportBookPage(initialSources: initialSources),
  );
}
