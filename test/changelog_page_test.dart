import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xxread/l10n/app_localizations.dart';
import 'package:xxread/pages/settings/about/changelog_page.dart';

void main() {
  testWidgets('changelog page shows the current and historical releases',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ChangelogPage(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('版本更新记录'), findsOneWidget);
    expect(find.text('v2.0.3'), findsOneWidget);
    expect(find.text('设置页新增小元读书和小元读书社区入口'), findsOneWidget);
    expect(
      find.text('新增自愿微信和支付宝捐赠入口，并明确不影响任何功能'),
      findsOneWidget,
    );
    expect(find.text('当前版本'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('v2.0.2'),
      200,
      scrollable: find.byType(Scrollable),
    );

    expect(find.text('v2.0.2'), findsOneWidget);
    expect(
      find.text('阅读信息栏嵌入每张纸页，横滑和仿真翻页时随页面一起移动'),
      findsOneWidget,
    );
    expect(
      find.text('页码向屏幕内侧留出安全距离，避免被圆角遮挡'),
      findsOneWidget,
    );

    await tester.scrollUntilVisible(
      find.text('v2.0.1'),
      200,
      scrollable: find.byType(Scrollable),
    );

    expect(find.text('v2.0.1'), findsOneWidget);
    expect(
      find.text('优化上一页仿真翻页，中间起手立即跟手，纵向晃动不再带偏装订边'),
      findsOneWidget,
    );
    expect(find.text('前后相邻页同步预热，减少首次反向翻页卡顿'), findsOneWidget);
    expect(
      find.text('发现页支持全部或单一书源筛选，最新书籍在多个书源间均衡穿插'),
      findsOneWidget,
    );

    await tester.scrollUntilVisible(
      find.text('v2.0.0'),
      200,
      scrollable: find.byType(Scrollable),
    );

    expect(find.text('v2.0.0'), findsOneWidget);
    expect(find.text('升级顶部信息、纸页页码与仿真翻页体验'), findsOneWidget);
    expect(find.text('支持多套自定义阅读主题、图片背景与拖拽排序'), findsOneWidget);
    expect(find.text('优化 EPUB 分页与可折叠多级目录'), findsOneWidget);
    expect(find.text('Android 阅读时保持屏幕常亮正式生效'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('v1.2.4'),
      200,
      scrollable: find.byType(Scrollable),
    );

    expect(find.text('v1.2.4'), findsOneWidget);
    expect(find.text('新增纸页化页脚、经典折页动画与阅读排版设置'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('v1.2.2'),
      200,
      scrollable: find.byType(Scrollable),
    );

    expect(find.text('v1.2.2'), findsOneWidget);
    expect(find.text('修复在线连续滚动无法中间点击呼出控制栏'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('v1.2.1'),
      300,
      scrollable: find.byType(Scrollable),
    );

    expect(find.text('v1.2.1'), findsOneWidget);
    expect(find.text('在线书源补齐按章节滚动与整书连续滚动'), findsOneWidget);
    expect(find.text('修复中文正文左右留白不对称并统一分页绘制'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('v1.2.0'),
      300,
      scrollable: find.byType(Scrollable),
    );

    expect(find.text('v1.2.0'), findsOneWidget);
    expect(find.text('优化阅读排版，支持零边距与同页更多文字'), findsOneWidget);
    expect(find.text('接入音量键翻页'), findsOneWidget);
    expect(find.text('完善自定义字体，支持导入与管理'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('v1.1.0'),
      300,
      scrollable: find.byType(Scrollable),
    );

    expect(find.text('v1.1.0'), findsOneWidget);
    expect(find.text('新增自定义字体'), findsOneWidget);
    expect(find.text('新增加入书签'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('v0.9.1'),
      300,
      scrollable: find.byType(Scrollable),
    );

    expect(find.text('v1.0.2'), findsOneWidget);
    expect(find.text('v1.0.1'), findsOneWidget);
    expect(find.text('v1.0.0'), findsOneWidget);
    expect(find.text('v0.9.1'), findsOneWidget);
  });
}
