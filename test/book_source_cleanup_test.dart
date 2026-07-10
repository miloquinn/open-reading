// 文件说明：书源清理回归测试，防止旧入口和同步目录被重新引入。
// 技术要点：Flutter Test、Widget Test、MaterialApp、本地化。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xxread/l10n/app_localizations.dart';
import 'package:xxread/pages/import_book_page.dart';
import 'package:xxread/services/sync/webdav_sync_path_helper.dart';

void main() {
  testWidgets('ImportBookPage only exposes local and WebDAV channels',
      (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ImportBookPage(),
      ),
    );
    await tester.pump();

    expect(find.text('本地文件'), findsOneWidget);
    expect(find.text('WebDAV'), findsOneWidget);
    expect(find.text('书源导入'), findsNothing);
  });

  test('WebDAV sync paths no longer include sources dataset', () {
    expect(
      WebDavSyncPathHelper.allDirectories
          .any((path) => path.contains('sources')),
      isFalse,
    );
  });
}
