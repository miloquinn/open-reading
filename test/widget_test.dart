// 文件说明：应用级基础测试，验证主应用可以完成最小化挂载。
// 技术要点：测试、Flutter Test、Provider、Flutter。

// This is a basic Flutter widget test for XX阅读 app.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart' as provider;

import 'package:xxread/main.dart';
import 'package:xxread/services/core/core_services.dart';
import 'package:xxread/services/tts_service.dart';

void main() {
  testWidgets('开元阅读 app smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      provider.MultiProvider(
        providers: [
          provider.ChangeNotifierProvider(create: (_) => ThemeNotifier()),
          provider.ChangeNotifierProvider(create: (_) => AppSettingsNotifier()),
          provider.ChangeNotifierProvider(create: (_) => TtsService()),
        ],
        child: const XxReadApp(),
      ),
    );

    // Pump a few frames to allow initial rendering
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Verify that our app loads without crashing
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
