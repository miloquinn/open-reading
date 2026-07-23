// 文件说明：封面展开转场（BookOpenTransition）的行为测试。
// 技术要点：widget test、路由动画。

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:xxread/utils/book_open_transition.dart';
import 'package:xxread/utils/layout_helper.dart';
import 'package:xxread/utils/page_transitions.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();

  Widget buildShelf(GlobalKey coverKey, GlobalKey<NavigatorState> navKey) {
    return MaterialApp(
      navigatorKey: navKey,
      home: Scaffold(
        body: Center(
          child: SizedBox(
            key: coverKey,
            width: 120,
            height: 180,
            child: const ColoredBox(color: Colors.brown, child: Text('cover')),
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
      coverBuilder: (_) =>
          const ColoredBox(color: Colors.brown, child: Text('flight-cover')),
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

    // 飞行中：目标页已经挂载预热，但仍由封面飞行层遮住。
    expect(find.text('flight-cover'), findsOneWidget);
    expect(find.text('reader'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('book-open-transition-deferred-page')),
      findsNothing,
    );

    final earlyCoverRect = tester.getRect(
      find.byKey(const ValueKey('book-open-transition-cover-flight')),
    );
    await tester.pump(const Duration(milliseconds: 100));
    final middleCoverRect = tester.getRect(
      find.byKey(const ValueKey('book-open-transition-cover-flight')),
    );
    await tester.pump(const Duration(milliseconds: 100));
    final lateCoverRect = tester.getRect(
      find.byKey(const ValueKey('book-open-transition-cover-flight')),
    );
    final middleGrowth = middleCoverRect.width - earlyCoverRect.width;
    final lateGrowth = lateCoverRect.width - middleCoverRect.width;
    expect(middleGrowth, greaterThan(lateGrowth));

    final readerOpacity = tester.widget<Opacity>(
      find.byKey(const ValueKey('book-open-transition-reader-opacity')),
    );
    expect(readerOpacity.opacity, greaterThan(0));
    expect(readerOpacity.opacity, lessThan(1));

    await tester.pumpAndSettle();
    // 落定：飞行图层移除，正文完全可见
    expect(find.text('flight-cover'), findsNothing);
    expect(find.text('reader'), findsOneWidget);
  });

  testWidgets('打开：封面化纸层跟随阅读主题背景色', (tester) async {
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
        readerBackgroundColor: Colors.black,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final paperLayers = tester.widgetList<ColoredBox>(
      find.descendant(
        of: find.byKey(const ValueKey('book-open-transition-cover-flight')),
        matching: find.byType(ColoredBox),
      ),
    );
    expect(paperLayers.any((layer) => layer.color == Colors.black), isTrue);
  });

  testWidgets('打开：正文未就绪时保留封面，首帧绘制后再交叉渐变', (tester) async {
    final coverKey = GlobalKey();
    final navKey = GlobalKey<NavigatorState>();
    late BuildContext readerContext;
    await tester.pumpWidget(buildShelf(coverKey, navKey));

    final animation = BookOpenAnimation.fromCoverKey(
      coverKey,
      radius: BorderRadius.circular(12),
      coverBuilder: (_) => const ColoredBox(color: Colors.brown),
    );
    navKey.currentState!.push<void>(
      BookOpenTransition.createRoute<void>(
        Scaffold(
          body: Builder(
            builder: (context) {
              readerContext = context;
              return const Text('reader-ready');
            },
          ),
        ),
        animation: animation,
        waitForReaderReady: true,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    final heldCoverOpacity = tester.widget<Opacity>(
      find.byKey(const ValueKey('book-open-transition-cover-opacity')),
    );
    final heldReaderOpacity = tester.widget<Opacity>(
      find.byKey(const ValueKey('book-open-transition-reader-opacity')),
    );
    expect(heldCoverOpacity.opacity, 1);
    expect(heldReaderOpacity.opacity, 0);

    BookOpenTransition.markReaderContentReady(readerContext);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 140));
    final fadingCoverOpacity = tester.widget<Opacity>(
      find.byKey(const ValueKey('book-open-transition-cover-opacity')),
    );
    final fadingReaderOpacity = tester.widget<Opacity>(
      find.byKey(const ValueKey('book-open-transition-reader-opacity')),
    );
    expect(fadingCoverOpacity.opacity, greaterThan(0));
    expect(fadingCoverOpacity.opacity, lessThan(1));
    expect(fadingReaderOpacity.opacity, greaterThan(0));
    expect(fadingReaderOpacity.opacity, lessThan(1));

    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('book-open-transition-cover-flight')),
      findsNothing,
    );
    expect(find.text('reader-ready'), findsOneWidget);
  });

  testWidgets('打开：持续加载时封面渐隐到加载页而不是裸白屏', (tester) async {
    final coverKey = GlobalKey();
    final navKey = GlobalKey<NavigatorState>();
    var loadingTapCount = 0;
    await tester.pumpWidget(buildShelf(coverKey, navKey));

    final animation = BookOpenAnimation.fromCoverKey(
      coverKey,
      radius: BorderRadius.circular(12),
      coverBuilder: (_) => const ColoredBox(color: Colors.brown),
    );
    navKey.currentState!.push<void>(
      BookOpenTransition.createRoute<void>(
        Scaffold(
          body: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => loadingTapCount += 1,
            child: const Center(child: CircularProgressIndicator()),
          ),
        ),
        animation: animation,
        waitForReaderReady: true,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 860));
    await tester.pump(const Duration(milliseconds: 190));

    final coverOpacity = tester.widget<Opacity>(
      find.byKey(const ValueKey('book-open-transition-cover-opacity')),
    );
    final loadingOpacity = tester.widget<Opacity>(
      find.byKey(const ValueKey('book-open-transition-reader-opacity')),
    );
    expect(coverOpacity.opacity, greaterThan(0));
    expect(coverOpacity.opacity, lessThan(1));
    expect(loadingOpacity.opacity, greaterThan(0));
    expect(loadingOpacity.opacity, lessThan(1));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.tapAt(
      tester.getCenter(find.byType(CircularProgressIndicator)),
    );
    expect(loadingTapCount, 1);

    navKey.currentState!.pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
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

  testWidgets('退出：封面缩回先快后慢，且起步时正文不闪白', (tester) async {
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

    expect(
      tester
          .widget<SnapshotWidget>(
            find.byKey(const ValueKey('book-open-transition-reader-snapshot')),
          )
          .controller
          .allowSnapshotting,
      isFalse,
    );

    navKey.currentState!.pop();
    await tester.pump();
    expect(
      tester
          .widget<SnapshotWidget>(
            find.byKey(const ValueKey('book-open-transition-reader-snapshot')),
          )
          .controller
          .allowSnapshotting,
      isTrue,
    );
    await tester.pump(const Duration(milliseconds: 30));

    final initialOpacity = tester.widget<Opacity>(
      find.byKey(const ValueKey('book-open-transition-reader-opacity')),
    );
    final initialPaperOpacity = tester.widget<Opacity>(
      find.byKey(const ValueKey('book-open-transition-paper-opacity')),
    );
    expect(initialOpacity.opacity, greaterThan(0));
    expect(initialOpacity.opacity, lessThan(1));
    expect(initialPaperOpacity.opacity, 0);

    await tester.pump(const Duration(milliseconds: 60));
    final earlyRect = tester.getRect(
      find.byKey(const ValueKey('book-open-transition-reader-flight')),
    );
    await tester.pump(const Duration(milliseconds: 90));
    final middleRect = tester.getRect(
      find.byKey(const ValueKey('book-open-transition-reader-flight')),
    );
    await tester.pump(const Duration(milliseconds: 90));
    final lateRect = tester.getRect(
      find.byKey(const ValueKey('book-open-transition-reader-flight')),
    );

    final earlyStep = earlyRect.left;
    final middleStep = middleRect.left - earlyRect.left;
    final lateStep = lateRect.left - middleRect.left;
    expect(earlyStep, greaterThan(0));
    expect(earlyStep, greaterThan(middleStep));
    expect(middleStep, greaterThan(lateStep));

    await tester.pumpAndSettle();
    expect(find.text('cover'), findsOneWidget);
  });

  testWidgets(
    'Android 预测性返回跟随侧滑进度且支持取消',
    (tester) async {
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

      await _sendPredictiveBackMessage(
        binding,
        'startBackGesture',
        const <String, dynamic>{
          'touchOffset': <double>[5, 300],
          'progress': 0.0,
          'swipeEdge': 0,
        },
      );
      await tester.pump();
      expect(BookOpenTransition.navigationHiddenListenable.value, isFalse);
      expect(
        tester
            .widget<SnapshotWidget>(
              find.byKey(
                const ValueKey('book-open-transition-reader-snapshot'),
              ),
            )
            .controller
            .allowSnapshotting,
        isTrue,
      );

      await _sendPredictiveBackMessage(
        binding,
        'updateBackGestureProgress',
        const <String, dynamic>{
          'touchOffset': <double>[40, 300],
          'progress': 0.1,
          'swipeEdge': 0,
        },
      );
      await tester.pump();
      final earlyReaderOpacity = tester.widget<Opacity>(
        find.byKey(const ValueKey('book-open-transition-reader-opacity')),
      );
      final earlyPaperOpacity = tester.widget<Opacity>(
        find.byKey(const ValueKey('book-open-transition-paper-opacity')),
      );
      expect(earlyReaderOpacity.opacity, greaterThan(0));
      expect(earlyReaderOpacity.opacity, lessThan(1));
      expect(earlyPaperOpacity.opacity, 0);
      final earlyWorkMode = tester.widget<TickerMode>(
        find.byKey(const ValueKey('book-open-transition-reader-work-mode')),
      );
      expect(earlyWorkMode.enabled, isTrue);

      await _sendPredictiveBackMessage(
        binding,
        'updateBackGestureProgress',
        const <String, dynamic>{
          'touchOffset': <double>[140, 300],
          'progress': 0.4,
          'swipeEdge': 0,
        },
      );
      await tester.pump();
      final draggedRect = tester.getRect(
        find.byKey(const ValueKey('book-open-transition-reader-flight')),
      );
      expect(draggedRect.left, greaterThan(0));
      expect(draggedRect.width, lessThan(800));
      final completedReaderOpacity = tester.widget<Opacity>(
        find.byKey(const ValueKey('book-open-transition-reader-opacity')),
      );
      expect(completedReaderOpacity.opacity, 0);
      final pausedWorkMode = tester.widget<TickerMode>(
        find.byKey(const ValueKey('book-open-transition-reader-work-mode')),
      );
      expect(pausedWorkMode.enabled, isFalse);

      await _sendPredictiveBackMessage(binding, 'cancelBackGesture');
      await tester.pumpAndSettle();
      expect(find.text('reader'), findsOneWidget);
      final restoredReaderOpacity = tester.widget<Opacity>(
        find.byKey(const ValueKey('book-open-transition-reader-opacity')),
      );
      expect(restoredReaderOpacity.opacity, 1);
      final restoredWorkMode = tester.widget<TickerMode>(
        find.byKey(const ValueKey('book-open-transition-reader-work-mode')),
      );
      expect(restoredWorkMode.enabled, isTrue);
      expect(
        tester
            .widget<SnapshotWidget>(
              find.byKey(
                const ValueKey('book-open-transition-reader-snapshot'),
              ),
            )
            .controller
            .allowSnapshotting,
        isFalse,
      );
      expect(
        find.byKey(const ValueKey('book-open-transition-cover-flight')),
        findsNothing,
      );
      expect(BookOpenTransition.navigationHiddenListenable.value, isTrue);

      await _sendPredictiveBackMessage(
        binding,
        'startBackGesture',
        const <String, dynamic>{
          'touchOffset': <double>[5, 300],
          'progress': 0.0,
          'swipeEdge': 0,
        },
      );
      await _sendPredictiveBackMessage(
        binding,
        'updateBackGestureProgress',
        const <String, dynamic>{
          'touchOffset': <double>[180, 300],
          'progress': 0.55,
          'swipeEdge': 0,
        },
      );
      await tester.pump();
      final beforeCommitRect = tester.getRect(
        find.byKey(const ValueKey('book-open-transition-reader-flight')),
      );

      await _sendPredictiveBackMessage(binding, 'commitBackGesture');
      await tester.pump(const Duration(milliseconds: 16));
      final afterCommitRect = tester.getRect(
        find.byKey(const ValueKey('book-open-transition-reader-flight')),
      );
      expect(afterCommitRect.left, greaterThanOrEqualTo(beforeCommitRect.left));

      await tester.pumpAndSettle();
      expect(find.text('reader'), findsNothing);
      expect(find.text('cover'), findsOneWidget);
      expect(BookOpenTransition.navigationHiddenListenable.value, isFalse);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets('无动画上下文时退化为平滑淡入路由', (tester) async {
    final navKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navKey,
        home: const Scaffold(body: Text('shelf')),
      ),
    );

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

  testWidgets('首页无封面入口使用纸面上浮淡入且不缩放正文', (tester) async {
    final navKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navKey,
        home: const Scaffold(body: Text('home')),
      ),
    );

    navKey.currentState!.push(
      BookOpenTransition.createRoute<void>(
        const Scaffold(body: Text('reader')),
        origin: ReaderPageTransitionOrigin.home,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));

    final initialPosition = tester.widget<SlideTransition>(
      find.byKey(const ValueKey('book-paper-transition-position')),
    );
    expect(initialPosition.position.value.dx, 0);
    expect(initialPosition.position.value.dy, closeTo(0.025, 0.001));
    final paperContent = tester.widget<FadeTransition>(
      find.byKey(const ValueKey('book-paper-transition-content-opacity')),
    );
    expect(paperContent.child, isNot(isA<ScaleTransition>()));

    await tester.pump(const Duration(milliseconds: 120));
    final contentOpacity = tester.widget<FadeTransition>(
      find.byKey(const ValueKey('book-paper-transition-content-opacity')),
    );
    expect(contentOpacity.opacity.value, greaterThan(0));
    expect(contentOpacity.opacity.value, lessThan(1));

    await tester.pumpAndSettle();
    navKey.currentState!.pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    final exitPosition = tester.widget<SlideTransition>(
      find.byKey(const ValueKey('book-paper-transition-position')),
    );
    expect(exitPosition.position.value.dy, greaterThan(0));
    await tester.pumpAndSettle();
  });

  testWidgets('发现页入口使用更明显的纵向纸面接力', (tester) async {
    final navKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navKey,
        home: const Scaffold(body: Text('discover')),
      ),
    );

    navKey.currentState!.push(
      BookOpenTransition.createRoute<void>(
        const Scaffold(body: Text('reader')),
        origin: ReaderPageTransitionOrigin.discoverSheet,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));

    final initialPosition = tester.widget<SlideTransition>(
      find.byKey(const ValueKey('book-paper-transition-position')),
    );
    expect(initialPosition.position.value.dx, 0);
    expect(initialPosition.position.value.dy, closeTo(0.04, 0.001));
    await tester.pumpAndSettle();
  });

  testWidgets('减少动态效果时纸面不发生位移', (tester) async {
    final navKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navKey,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: const Scaffold(body: Text('home')),
      ),
    );

    navKey.currentState!.push(
      BookOpenTransition.createRoute<void>(
        const Scaffold(body: Text('reader')),
        origin: ReaderPageTransitionOrigin.discoverSheet,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));

    final position = tester.widget<SlideTransition>(
      find.byKey(const ValueKey('book-paper-transition-position')),
    );
    expect(position.position.value, Offset.zero);
    await tester.pumpAndSettle();
  });

  testWidgets('push 等待退出动画完成后才恢复调用方', (tester) async {
    late BuildContext shelfContext;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            shelfContext = context;
            return const Scaffold(body: Text('shelf'));
          },
        ),
      ),
    );

    final route = BookOpenTransition.createRoute<void>(
      const Scaffold(body: Text('reader')),
    );
    var returned = false;
    final navigation = BookOpenTransition.push<void>(shelfContext, route).then((
      _,
    ) {
      returned = true;
    });
    await tester.pumpAndSettle();

    Navigator.of(shelfContext).pop();
    await tester.pump();
    expect(returned, isFalse);
    await tester.pump(const Duration(milliseconds: 100));
    expect(returned, isFalse);

    await tester.pumpAndSettle();
    await navigation;
    expect(returned, isTrue);
  });

  testWidgets('退出时封面位置解析失败会安全使用捕获位置', (tester) async {
    final navKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navKey,
        home: const Scaffold(body: Text('shelf')),
      ),
    );

    navKey.currentState!.push<void>(
      BookOpenTransition.createRoute<void>(
        const Scaffold(body: Text('reader')),
        animation: BookOpenAnimation(
          sourceRect: const Rect.fromLTWH(120, 180, 100, 150),
          sourceRadius: BorderRadius.circular(12),
          sourceScreenSize: const Size(800, 600),
          coverBuilder: (_) => const ColoredBox(color: Colors.brown),
          rectResolver: () => throw StateError('layout is rebuilding'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    navKey.currentState!.pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    expect(tester.takeException(), isNull);
    expect(
      find.byKey(const ValueKey('book-open-transition-cover-flight')),
      findsOneWidget,
    );
    await tester.pumpAndSettle();
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

Future<void> _sendPredictiveBackMessage(
  TestWidgetsFlutterBinding binding,
  String method, [
  Map<String, dynamic>? arguments,
]) async {
  final message = const StandardMethodCodec().encodeMethodCall(
    MethodCall(method, arguments),
  );
  await binding.defaultBinaryMessenger.handlePlatformMessage(
    'flutter/backgesture',
    message,
    (_) {},
  );
}
