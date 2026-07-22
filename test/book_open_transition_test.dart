// 文件说明：封面展开转场（BookOpenTransition）的行为测试。
// 技术要点：widget test、路由动画。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:xxread/utils/book_open_transition.dart';
import 'package:xxread/utils/layout_helper.dart';

void main() {
  Widget buildShelf(GlobalKey coverKey, GlobalKey<NavigatorState> navKey) {
    return MaterialApp(
      navigatorKey: navKey,
      home: Scaffold(
        body: Center(
          child: SizedBox(
            key: coverKey,
            width: 120,
            height: 180,
            child: const ColoredBox(
              color: Colors.brown,
              child: Text('cover'),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('打开：封面飞行图层出现，落定后只剩阅读页', (tester) async {
    final coverKey = GlobalKey();
    final navKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(buildShelf(coverKey, navKey));

    final animation = BookOpenAnimation.fromCoverKey(
      coverKey,
      radius: BorderRadius.circular(12),
      coverBuilder: (_) => const ColoredBox(
        color: Colors.brown,
        child: Text('flight-cover'),
      ),
    );
    expect(animation, isNotNull);
    expect(animation!.sourceRect.size, const Size(120, 180));

    navKey.currentState!.push(
      BookOpenTransition.createRoute<void>(
        const Scaffold(body: Text('reader')),
        animation: animation,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // 飞行中：只保留轻量纸色占位，避免阅读器同步初始化抢动画帧。
    expect(find.text('flight-cover'), findsOneWidget);
    expect(find.text('reader'), findsNothing);
    expect(
      find.byKey(const ValueKey('book-open-transition-deferred-page')),
      findsOneWidget,
    );

    await tester.pumpAndSettle();
    // 落定：飞行图层移除，正文完全可见
    expect(find.text('flight-cover'), findsNothing);
    expect(find.text('reader'), findsOneWidget);
  });

  testWidgets('退出：反向飞回书架格子并恢复书架', (tester) async {
    final coverKey = GlobalKey();
    final navKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(buildShelf(coverKey, navKey));

    final animation = BookOpenAnimation.fromCoverKey(
      coverKey,
      radius: BorderRadius.circular(12),
      coverBuilder: (_) => const Text('flight-cover'),
    );
    navKey.currentState!.push(
      BookOpenTransition.createRoute<void>(
        const Scaffold(body: Text('reader')),
        animation: animation,
      ),
    );
    await tester.pumpAndSettle();

    navKey.currentState!.pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    // 反向飞行中飞行图层重新出现
    expect(find.text('flight-cover'), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.text('reader'), findsNothing);
    expect(find.text('cover'), findsOneWidget);
  });

  testWidgets('退出：前段缓慢、后段加速，且起步时正文不闪白', (tester) async {
    final coverKey = GlobalKey();
    final navKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(buildShelf(coverKey, navKey));

    final animation = BookOpenAnimation.fromCoverKey(
      coverKey,
      radius: BorderRadius.circular(12),
      coverBuilder: (_) => const ColoredBox(color: Colors.brown),
    );
    navKey.currentState!.push(
      BookOpenTransition.createRoute<void>(
        const Scaffold(body: Text('reader')),
        animation: animation,
      ),
    );
    await tester.pumpAndSettle();

    navKey.currentState!.pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 30));

    final initialOpacity = tester.widget<Opacity>(
      find.byKey(const ValueKey('book-open-transition-reader-opacity')),
    );
    expect(initialOpacity.opacity, 1.0);

    await tester.pump(const Duration(milliseconds: 60));
    final earlyRect = tester.getRect(
      find.byKey(const ValueKey('book-open-transition-reader-flight')),
    );
    await tester.pump(const Duration(milliseconds: 90));
    final middleRect = tester.getRect(
      find.byKey(const ValueKey('book-open-transition-reader-flight')),
    );

    final earlyInset = earlyRect.left;
    final middleStep = middleRect.left - earlyRect.left;
    expect(earlyInset, greaterThan(0));
    expect(middleStep, greaterThan(earlyInset * 2));

    await tester.pumpAndSettle();
    expect(find.text('cover'), findsOneWidget);
  });

  testWidgets('无动画上下文时退化为平滑淡入路由', (tester) async {
    final navKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(MaterialApp(
      navigatorKey: navKey,
      home: const Scaffold(body: Text('shelf')),
    ));

    navKey.currentState!.push(
      BookOpenTransition.createRoute<void>(
        const Scaffold(body: Text('reader')),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('reader'), findsOneWidget);

    navKey.currentState!.pop();
    await tester.pumpAndSettle();
    expect(find.text('shelf'), findsOneWidget);
  });

  testWidgets('fromCoverKey：未挂载的 key 返回 null', (tester) async {
    final coverKey = GlobalKey();
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    expect(
      BookOpenAnimation.fromCoverKey(
        coverKey,
        radius: BorderRadius.zero,
        coverBuilder: (_) => const SizedBox(),
      ),
      isNull,
    );
  });

  group('书库网格列数按宽度推导', () {
    test('小平板竖屏约 5 列', () {
      expect(LayoutHelper.bookGridColumnsForWidth(820), 5);
    });

    test('平板横屏约 7 列', () {
      expect(LayoutHelper.bookGridColumnsForWidth(1180), 7);
    });

    test('窄容器下限 3 列', () {
      expect(LayoutHelper.bookGridColumnsForWidth(400), 3);
    });

    test('超宽桌面封顶 10 列', () {
      expect(LayoutHelper.bookGridColumnsForWidth(2400), 10);
    });

    test('纯封面网格在手机上严格使用用户选择的列数', () {
      expect(
        LayoutHelper.coverOnlyGridColumnsForWidth(390, mobileColumns: 2),
        2,
      );
      expect(
        LayoutHelper.coverOnlyGridColumnsForWidth(390, mobileColumns: 3),
        3,
      );
    });

    test('纯封面网格在宽屏按所选密度增加列数', () {
      expect(
        LayoutHelper.coverOnlyGridColumnsForWidth(820, mobileColumns: 2),
        4,
      );
      expect(
        LayoutHelper.coverOnlyGridColumnsForWidth(820, mobileColumns: 3),
        5,
      );
    });
  });
}
