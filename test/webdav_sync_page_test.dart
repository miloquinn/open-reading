import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:xxread/l10n/app_localizations.dart';
import 'package:xxread/pages/settings/sync/webdav_setup_page.dart';
import 'package:xxread/pages/settings/sync/webdav_sync_page.dart';
import 'package:xxread/services/sync/webdav_sync_controller.dart';

void main() {
  testWidgets('未配置概览在窄屏展示安全的主操作', (tester) async {
    final controller = WebDavSyncController();
    addTearDown(controller.dispose);

    await tester.binding.setSurfaceSize(const Size(360, 760));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_testApp(controller, const WebDavSyncPage()));
    await tester.pumpAndSettle();

    expect(find.text('WebDAV 同步'), findsWidgets);
    expect(find.text('尚未配置'), findsWidgets);
    expect(find.text('设置 WebDAV'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('配置页先测试连接再允许保存', (tester) async {
    final controller = WebDavSyncController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(_testApp(controller, const WebDavSetupPage()));
    await tester.pumpAndSettle();

    expect(find.text('WebDAV 地址'), findsOneWidget);
    expect(find.text('用户名'), findsOneWidget);
    expect(find.text('应用密码'), findsOneWidget);
    expect(find.text('测试连接'), findsOneWidget);

    final saveButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, '保存配置'),
    );
    expect(saveButton.onPressed, isNull);
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(find.text('书籍原文件'), findsOneWidget);
    expect(find.text('选择需要上传或下载的书籍'), findsOneWidget);
  });
}

Widget _testApp(WebDavSyncController controller, Widget home) {
  return ChangeNotifierProvider<WebDavSyncController>.value(
    value: controller,
    child: MaterialApp(
      locale: const Locale('zh'),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    ),
  );
}
