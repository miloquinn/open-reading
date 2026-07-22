import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:xxread/l10n/app_localizations.dart';
import 'package:xxread/pages/settings/sync/webdav_setup_page.dart';
import 'package:xxread/pages/settings/sync/webdav_sync_content_page.dart';
import 'package:xxread/pages/settings/sync/webdav_sync_page.dart';
import 'package:xxread/services/sync/secure_sync_config.dart';
import 'package:xxread/services/sync/sync_models.dart';
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
    expect(find.text('阅读进度'), findsNothing);
    expect(find.text('书籍原文件'), findsNothing);
  });

  testWidgets('同步内容开关在独立页面即时保存', (tester) async {
    final preferences = _MemoryPreferences();
    final store = SecureSyncConfigStore(
      secretStorage: _MemorySecrets(),
      preferences: preferences,
    );
    final controller = _ScopeController(store);
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      _testApp(controller, const WebDavSyncContentPage()),
    );
    await tester.pumpAndSettle();

    final progressSwitch = find.widgetWithText(SwitchListTile, '阅读进度');
    expect(progressSwitch, findsOneWidget);
    expect(tester.widget<SwitchListTile>(progressSwitch).value, isTrue);

    await tester.tap(progressSwitch);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(controller.scope.progress, isFalse);
    expect((await store.readScope()).progress, isFalse);
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

class _MemoryPreferences implements SyncPreferences {
  final values = <String, String>{};

  @override
  Future<void> delete(String key) async => values.remove(key);

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;
}

class _MemorySecrets implements SyncSecretStorage {
  final values = <String, String>{};

  @override
  Future<void> delete(String key) async => values.remove(key);

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;
}

class _ScopeController extends WebDavSyncController {
  _ScopeController(this.store);

  final SecureSyncConfigStore store;
  WebDavSyncScope value = const WebDavSyncScope();

  @override
  bool get isConfigured => true;

  @override
  WebDavSyncScope get scope => value;

  @override
  Future<void> setScope(WebDavSyncScope scope) async {
    await store.saveScope(scope);
    value = scope;
    notifyListeners();
  }
}
