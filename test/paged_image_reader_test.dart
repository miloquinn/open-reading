import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xxread/core/reader/paged_image_reader_settings.dart';
import 'package:xxread/core/reader/reader_keep_screen_on.dart';
import 'package:xxread/l10n/app_localizations.dart';
import 'package:xxread/pages/reader/paged_image_reader.dart';
import 'package:xxread/utils/reader_themes.dart';
import 'package:xxread/widgets/reader_theme_background.dart';

/// 1x1 透明 PNG，Image.memory 可解码的最小合法图片。
final Uint8List _tinyPng = Uint8List.fromList(const <int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, //
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, //
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00, //
  0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00, //
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49, //
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

Widget _buildReader({
  required int pageCount,
  required int initialPage,
  required List<int> requested,
  ValueChanged<int>? onPageChanged,
  int? bookId,
}) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: PagedImageReader(
        title: '测试书',
        pageCount: pageCount,
        initialPage: initialPage,
        loadPage: (index) async {
          requested.add(index);
          return _tinyPng;
        },
        onPageChanged: onPageChanged,
        bookId: bookId,
      ),
    ),
  );
}

/// 单击后越过双击判定窗口再结算动画，保证轻点动作已经分发。
Future<void> _tapAndSettle(WidgetTester tester, Offset position) async {
  await tester.tapAt(position);
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pumpAndSettle();
}

/// 在测试 zone 内主动卸载阅读器：dispose 会走屏幕常亮/音量键桥接，
/// 必须趁通道 mock 还在时完成，否则残留的同步链会卡死下一个测试的 setUp。
Future<void> _unmountReader(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpAndSettle();
}

void main() {
  const fullscreenChannel = MethodChannel('com.niki.xxread/fullscreen');
  const readerKeysChannel = MethodChannel('com.niki.xxread/reader_keys');

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    // 屏幕常亮与音量键桥接必须 mock，避免真实通道调用在测试环境悬挂。
    // 不能在这里 await ReaderKeepScreenOnController.resetForTesting()：
    // 它内部 await 的静态同步链跨 testWidgets 的 fake-async 区域后可能
    // 永不完成，会卡死后续所有测试的 setUp。控制器语义已由
    // reader_keep_screen_on_test.dart 独立覆盖，这里只断言 UI 与偏好写入。
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(fullscreenChannel, (_) async => null);
    messenger.setMockMethodCallHandler(readerKeysChannel, (_) async => null);
  });

  tearDown(() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(fullscreenChannel, null);
    messenger.setMockMethodCallHandler(readerKeysChannel, null);
  });

  testWidgets('初始页越界时收敛到最后一页，页码指示正确', (tester) async {
    final requested = <int>[];
    await tester.pumpWidget(
      _buildReader(pageCount: 3, initialPage: 99, requested: requested),
    );
    await tester.pumpAndSettle();

    expect(find.text('3 / 3'), findsOneWidget);
    // 当前页与相邻页都发起过加载（预载 index-1）。
    expect(requested, contains(2));
    expect(requested, contains(1));
    await _unmountReader(tester);
  });

  testWidgets('打开失败提示页使用阅读主题背景和文字颜色', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const PagedReaderMessageScaffold(
          title: 'Broken book',
          message: 'Open failed',
          palette: ReaderThemes.night,
        ),
      ),
    );

    final background = tester.widget<ReaderThemeBackground>(
      find.byType(ReaderThemeBackground),
    );
    expect(background.palette, ReaderThemes.night);

    final message = tester.widget<Text>(find.text('Open failed'));
    expect(message.style?.color, ReaderThemes.night.text);
    expect(
      Theme.of(
        tester.element(find.text('Open failed')),
      ).scaffoldBackgroundColor,
      ReaderThemes.night.background,
    );
  });

  testWidgets('翻页触发 onPageChanged 并更新页码', (tester) async {
    final requested = <int>[];
    final changes = <int>[];
    await tester.pumpWidget(
      _buildReader(
        pageCount: 3,
        initialPage: 0,
        requested: requested,
        onPageChanged: changes.add,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('1 / 3'), findsOneWidget);

    await tester.fling(find.byType(PageView), const Offset(-400, 0), 1000);
    await tester.pumpAndSettle();

    expect(changes, [1]);
    expect(find.text('2 / 3'), findsOneWidget);
    await _unmountReader(tester);
  });

  testWidgets('默认点击区域：右侧翻页、中间呼出菜单、再点关闭', (tester) async {
    final requested = <int>[];
    await tester.pumpWidget(
      _buildReader(pageCount: 3, initialPage: 0, requested: requested),
    );
    await tester.pumpAndSettle();

    // 右侧三分之一：下一页。
    await _tapAndSettle(tester, const Offset(700, 300));
    expect(find.text('2 / 3'), findsOneWidget);

    // 控制栏默认隐藏，Slider 不接收点击。
    final chromeOpacity = tester.widget<AnimatedOpacity>(
      find
          .ancestor(
            of: find.byType(Slider),
            matching: find.byType(AnimatedOpacity),
          )
          .first,
    );
    expect(chromeOpacity.opacity, 0);

    // 中间：呼出控制栏。
    await _tapAndSettle(tester, const Offset(400, 300));
    final visibleOpacity = tester.widget<AnimatedOpacity>(
      find
          .ancestor(
            of: find.byType(Slider),
            matching: find.byType(AnimatedOpacity),
          )
          .first,
    );
    expect(visibleOpacity.opacity, 1);

    // 控制栏可见时任意位置轻点先收起，不触发翻页。
    await _tapAndSettle(tester, const Offset(700, 300));
    expect(find.text('2 / 3'), findsOneWidget);
    await _unmountReader(tester);
  });

  testWidgets('RTL 方向：PageView 反向且点击列镜像', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      PagedImageReaderSettingsStore.directionOverridesKey: '{"7":"rtl"}',
    });
    final requested = <int>[];
    await tester.pumpWidget(
      _buildReader(
        pageCount: 3,
        initialPage: 0,
        requested: requested,
        bookId: 7,
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.widget<PageView>(find.byType(PageView)).reverse, isTrue);

    // 默认布局左列是上一页；RTL 镜像后点左侧应当翻到下一页。
    await _tapAndSettle(tester, const Offset(100, 300));
    expect(find.text('2 / 3'), findsOneWidget);
    await _unmountReader(tester);
  });

  testWidgets('底部方向切换按书持久化，跳页对话框可直达页码', (tester) async {
    final requested = <int>[];
    await tester.pumpWidget(
      _buildReader(
        pageCount: 5,
        initialPage: 0,
        requested: requested,
        bookId: 7,
      ),
    );
    await tester.pumpAndSettle();

    // 呼出控制栏后切换方向。
    await _tapAndSettle(tester, const Offset(400, 300));
    await tester.tap(find.text('Left to right'));
    await tester.pumpAndSettle();
    expect(tester.widget<PageView>(find.byType(PageView)).reverse, isTrue);
    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getString(PagedImageReaderSettingsStore.directionOverridesKey),
      contains('"7":"rtl"'),
    );

    // 跳页对话框输入页码后直达。对话框内 TextField 自动聚焦后光标闪烁
    // 定时器会让 pumpAndSettle 永不收敛，打开期间只用有界 pump。
    await tester.tap(find.text('Go to page'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.enterText(find.byType(TextField), '4');
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    expect(find.text('4 / 5'), findsOneWidget);
    await _unmountReader(tester);
  });

  testWidgets('设置面板：背景色与屏幕常亮即时持久化', (tester) async {
    final requested = <int>[];
    await tester.pumpWidget(
      _buildReader(pageCount: 3, initialPage: 0, requested: requested),
    );
    await tester.pumpAndSettle();

    await _tapAndSettle(tester, const Offset(400, 300));
    await tester.tap(find.text('Reading settings'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('White'));
    await tester.pumpAndSettle();
    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getString(PagedImageReaderSettingsStore.backgroundKey),
      'white',
    );
    final rootBox = tester.widget<ColoredBox>(
      find
          .descendant(
            of: find.byType(PagedImageReader),
            matching: find.byType(ColoredBox),
          )
          .first,
    );
    expect(rootBox.color, ImageReaderBackground.white.color);

    await tester.tap(find.byType(SwitchListTile).first);
    await tester.pumpAndSettle();
    expect(prefs.getBool(ReaderKeepScreenOnController.preferenceKey), isTrue);
    await _unmountReader(tester);
  });
}
