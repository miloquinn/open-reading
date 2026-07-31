// 文件说明：首页 tab 焦点闸门的回归测试。
// 背景：AI 页聊天输入框残留焦点时，阅读器/对话框关闭会把焦点还给它，
// showCaretOnScreen 顺着视口把首页 PageView 拽到别的 tab（表现为返回
// 动画在发现页抽搐）。闸门保证非当前 tab 的子树不可持有焦点。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:xxread/l10n/app_localizations.dart';
import 'package:xxread/models/home_navigation_destination.dart';
import 'package:xxread/pages/home/home_shell_page.dart';
import 'package:xxread/pages/home/widgets/home_page_wrappers.dart';
import 'package:xxread/services/core/app_settings_service.dart';
import 'package:xxread/utils/ui_style.dart';

void main() {
  testWidgets('切走 tab 时闸门立刻释放该 tab 内的焦点', (tester) async {
    final focusNode = FocusNode();
    addTearDown(focusNode.dispose);
    var active = HomeNavigationDestination.ai;
    late StateSetter setScope;

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            setScope = setState;
            return HomeTabFocusScope(
              activeDestination: active,
              child: Column(
                children: [
                  HomeTabFocusGate(
                    destination: HomeNavigationDestination.library,
                    child: const SizedBox(height: 10),
                  ),
                  HomeTabFocusGate(
                    destination: HomeNavigationDestination.ai,
                    child: Focus(focusNode: focusNode, child: const SizedBox()),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );

    // AI tab 激活时，其内部节点可正常获得焦点。
    focusNode.requestFocus();
    await tester.pump();
    expect(focusNode.hasFocus, isTrue);

    // 切到书库 tab：AI 子树被排除，焦点必须立刻被释放。
    setScope(() => active = HomeNavigationDestination.library);
    await tester.pump();
    expect(focusNode.hasFocus, isFalse);

    // 被排除期间无法重新抢回焦点（对应上层路由关闭时的焦点恢复路径）。
    focusNode.requestFocus();
    await tester.pump();
    expect(focusNode.hasFocus, isFalse);
  });

  testWidgets('首页壳层为每个 tab 装配焦点闸门且仅当前 tab 可聚焦', (tester) async {
    await tester.binding.setSurfaceSize(const Size(412, 915));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AppSettingsNotifier(),
        child: MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF6750A4),
            ),
            extensions: const [
              UiStyleThemeExtension(style: AppUiStyle.material3),
            ],
          ),
          home: const MediaQuery(
            data: MediaQueryData(
              size: Size(412, 915),
              viewPadding: EdgeInsets.only(top: 24, bottom: 24),
            ),
            child: HomeShellPage(),
          ),
        ),
      ),
    );
    await tester.pump();

    ExcludeFocus gateOf(HomeNavigationDestination destination) {
      return tester.widget<ExcludeFocus>(
        find.byKey(
          ValueKey('home-tab-focus-gate-${destination.storageId}'),
          skipOffstage: false,
        ),
      );
    }

    // 初始在首页 tab：首页闸门放行，预构建的相邻书库页被排除焦点。
    expect(gateOf(HomeNavigationDestination.home).excluding, isFalse);
    expect(gateOf(HomeNavigationDestination.library).excluding, isTrue);
  });
}
