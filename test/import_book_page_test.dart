import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xxread/l10n/app_localizations.dart';
import 'package:xxread/pages/import_book/import_book_widgets.dart';
import 'package:xxread/pages/import_book_page.dart';

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
}

Widget _testApp() {
  return const MaterialApp(
    locale: Locale('zh'),
    localizationsDelegates: <LocalizationsDelegate<dynamic>>[
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: ImportBookPage(),
  );
}
