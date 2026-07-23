import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xxread/models/home_navigation_destination.dart';
import 'package:xxread/pages/home/widgets/home_bounce_navigation_item.dart';
import 'package:xxread/pages/home/widgets/home_navigation_item.dart';

void main() {
  const label = 'Library';
  const item = HomeNavigationItem(
    destination: HomeNavigationDestination.library,
    icon: Icons.library_books_outlined,
    selectedIcon: Icons.library_books,
    label: label,
    page: SizedBox.shrink(),
  );

  testWidgets('renders an enlarged icon-only navigation item', (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(_testApp(item: item, isSelected: false));

      expect(find.text(label), findsNothing);
      expect(find.bySemanticsLabel(label), findsOneWidget);
      final itemSize = tester.getSize(find.byType(HomeBounceNavigationItem));
      expect(itemSize.width, greaterThanOrEqualTo(48));
      expect(itemSize.height, greaterThanOrEqualTo(48));

      final icons = tester.widgetList<Icon>(
        find.descendant(
          of: find.byType(HomeBounceNavigationItem),
          matching: find.byType(Icon),
        ),
      );
      expect(icons, hasLength(2));
      expect(icons.every((icon) => icon.size == 28), isTrue);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('animates selected and unselected states in both directions', (
    tester,
  ) async {
    await tester.pumpWidget(_testApp(item: item, isSelected: false));
    expect(_selectedIconOpacity(tester, label), 0);
    expect(_unselectedIconOpacity(tester, label), 1);
    expect(_indicatorScaleX(tester, label), closeTo(0.92, 0.001));
    expect(_indicatorScaleY(tester, label), closeTo(0.92, 0.001));
    expect(_indicatorColor(tester, label).a, 0);

    await tester.pumpWidget(_testApp(item: item, isSelected: true));
    await tester.pump(const Duration(milliseconds: 100));
    final selectingOpacity = _selectedIconOpacity(tester, label);
    expect(selectingOpacity, inExclusiveRange(0, 1));
    expect(_indicatorScaleX(tester, label), inExclusiveRange(0.92, 1));
    expect(_indicatorScaleY(tester, label), inExclusiveRange(0.92, 1));
    expect(
      _indicatorScaleX(tester, label),
      closeTo(_indicatorScaleY(tester, label), 0.001),
    );
    expect(_indicatorColor(tester, label).a, inExclusiveRange(0, 1));
    expect(
      _unselectedIconOpacity(tester, label),
      closeTo(1 - selectingOpacity, 0.001),
    );

    await tester.pumpAndSettle();
    expect(_selectedIconOpacity(tester, label), 1);
    expect(_unselectedIconOpacity(tester, label), 0);
    expect(_indicatorScaleX(tester, label), 1);
    expect(_indicatorScaleY(tester, label), 1);
    expect(_indicatorColor(tester, label).a, 1);

    await tester.pumpWidget(_testApp(item: item, isSelected: false));
    await tester.pump(const Duration(milliseconds: 80));
    final deselectingOpacity = _selectedIconOpacity(tester, label);
    expect(deselectingOpacity, inExclusiveRange(0, 1));
    expect(_indicatorScaleX(tester, label), inExclusiveRange(0.92, 1));
    expect(_indicatorScaleY(tester, label), inExclusiveRange(0.92, 1));
    expect(
      _indicatorScaleX(tester, label),
      closeTo(_indicatorScaleY(tester, label), 0.001),
    );
    expect(_indicatorColor(tester, label).a, inExclusiveRange(0, 1));
    expect(
      _unselectedIconOpacity(tester, label),
      closeTo(1 - deselectingOpacity, 0.001),
    );

    await tester.pumpAndSettle();
    expect(_selectedIconOpacity(tester, label), 0);
    expect(_unselectedIconOpacity(tester, label), 1);
    expect(_indicatorScaleX(tester, label), closeTo(0.92, 0.001));
    expect(_indicatorScaleY(tester, label), closeTo(0.92, 0.001));
    expect(_indicatorColor(tester, label).a, 0);
  });

  testWidgets('animates between icon-only and labeled navigation modes', (
    tester,
  ) async {
    await tester.pumpWidget(
      _testApp(
        item: item,
        isSelected: true,
        showLabel: false,
        itemWidth: 94.25,
        itemHeight: 56,
      ),
    );
    expect(find.text(label), findsNothing);
    expect(_indicatorSize(tester, label), const Size(92.25, 54));
    expect(_selectedIconSize(tester), 28);

    await tester.pumpWidget(
      _testApp(
        item: item,
        isSelected: true,
        showLabel: true,
        itemWidth: 94.25,
        itemHeight: 56,
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text(label), findsOneWidget);
    expect(_labelOpacity(tester, label), inExclusiveRange(0, 1));
    expect(_indicatorSize(tester, label).width, inExclusiveRange(92.25, 94.25));
    expect(_selectedIconSize(tester), inExclusiveRange(27, 28));

    await tester.pumpAndSettle();
    expect(_labelOpacity(tester, label), 1);
    expect(_indicatorSize(tester, label), const Size(94.25, 56));
    expect(_selectedIconSize(tester), 27);
    expect(_labelTextStyle(tester, label).fontSize, 10.5);
    expect(_labelTextStyle(tester, label).fontWeight, FontWeight.w700);

    await tester.pumpWidget(
      _testApp(
        item: item,
        isSelected: true,
        showLabel: false,
        itemWidth: 94.25,
        itemHeight: 56,
      ),
    );
    await tester.pump(const Duration(milliseconds: 80));
    expect(find.text(label), findsOneWidget);
    expect(_labelOpacity(tester, label), inExclusiveRange(0, 1));

    await tester.pumpAndSettle();
    expect(find.text(label), findsNothing);
    expect(_indicatorSize(tester, label), const Size(92.25, 54));
    expect(_selectedIconSize(tester), 28);
  });

  testWidgets('keeps press feedback inside the full tap target', (
    tester,
  ) async {
    var tapCount = 0;
    await tester.pumpWidget(
      _testApp(item: item, isSelected: false, onTap: () => tapCount++),
    );

    expect(_pressScale(tester, label), 1);
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(HomeBounceNavigationItem)),
    );
    await tester.pump(const Duration(milliseconds: 120));
    await tester.pump(const Duration(milliseconds: 120));
    expect(_pressScale(tester, label), lessThan(1));

    await gesture.up();
    await tester.pumpAndSettle();
    expect(_pressScale(tester, label), closeTo(1, 0.001));
    expect(tapCount, 1);
  });

  testWidgets('keeps visible unselected labels bold and high contrast', (
    tester,
  ) async {
    await tester.pumpWidget(
      _testApp(
        item: item,
        isSelected: false,
        showLabel: true,
        itemWidth: 94.25,
        itemHeight: 56,
      ),
    );

    final style = _labelTextStyle(tester, label);
    expect(style.fontSize, 10.5);
    expect(style.fontWeight, FontWeight.w600);
    expect(style.color!.a, closeTo(0.9, 0.001));
  });

  testWidgets('keeps long labels inside a narrow production-sized slot', (
    tester,
  ) async {
    const narrowItem = HomeNavigationItem(
      destination: HomeNavigationDestination.library,
      icon: Icons.library_books_outlined,
      selectedIcon: Icons.library_books,
      label: 'Bookshelf',
      page: SizedBox.shrink(),
    );
    await tester.pumpWidget(
      _testApp(
        item: narrowItem,
        isSelected: true,
        showLabel: true,
        itemWidth: 73,
        itemHeight: 56,
      ),
    );

    expect(tester.takeException(), isNull);
    final itemRect = tester.getRect(find.byType(HomeBounceNavigationItem));
    final indicatorRect = tester.getRect(
      find.byKey(const ValueKey('home-nav-indicator-Bookshelf')),
    );
    final labelRect = tester.getRect(find.text('Bookshelf'));

    expect(indicatorRect.width, 73);
    expect(indicatorRect.height, 56);
    expect(indicatorRect.left, greaterThanOrEqualTo(itemRect.left));
    expect(indicatorRect.right, lessThanOrEqualTo(itemRect.right));
    expect(labelRect.left, greaterThanOrEqualTo(itemRect.left));
    expect(labelRect.right, lessThanOrEqualTo(itemRect.right));
  });

  testWidgets('uses matching capsule radii at production item width', (
    tester,
  ) async {
    await tester.pumpWidget(
      _testApp(item: item, isSelected: true, itemWidth: 83, itemHeight: 56),
    );

    var indicatorRect = tester.getRect(
      find.byKey(const ValueKey('home-nav-indicator-Library')),
    );
    final itemRect = tester.getRect(find.byType(HomeBounceNavigationItem));
    expect(indicatorRect.size, const Size(81, 54));
    expect(indicatorRect.center.dx, closeTo(itemRect.center.dx, 0.001));
    expect(
      (itemRect.width - indicatorRect.width) / 2,
      closeTo((itemRect.height - indicatorRect.height) / 2, 0.001),
    );
    expect(_indicatorCornerRadius(tester, label), 27);

    await tester.pumpWidget(
      _testApp(
        item: item,
        isSelected: true,
        showLabel: true,
        itemWidth: 83,
        itemHeight: 56,
      ),
    );
    await tester.pumpAndSettle();

    indicatorRect = tester.getRect(
      find.byKey(const ValueKey('home-nav-indicator-Library')),
    );
    final labeledItemRect = tester.getRect(
      find.byType(HomeBounceNavigationItem),
    );
    expect(indicatorRect.size, const Size(83, 56));
    expect(indicatorRect.center.dx, closeTo(labeledItemRect.center.dx, 0.001));
    expect(
      (labeledItemRect.width - indicatorRect.width) / 2,
      closeTo((labeledItemRect.height - indicatorRect.height) / 2, 0.001),
    );
    expect(_indicatorCornerRadius(tester, label), 28);
  });
}

double _selectedIconOpacity(WidgetTester tester, String label) {
  return tester
      .widget<Opacity>(find.byKey(ValueKey('home-nav-selected-$label')))
      .opacity;
}

double _unselectedIconOpacity(WidgetTester tester, String label) {
  return tester
      .widget<Opacity>(find.byKey(ValueKey('home-nav-unselected-$label')))
      .opacity;
}

double _pressScale(WidgetTester tester, String label) {
  return tester
      .widget<Transform>(find.byKey(ValueKey('home-nav-press-$label')))
      .transform
      .entry(0, 0);
}

double _labelOpacity(WidgetTester tester, String label) {
  return tester
      .widget<Opacity>(find.byKey(ValueKey('home-nav-label-$label')))
      .opacity;
}

Size _indicatorSize(WidgetTester tester, String label) {
  return tester.getSize(find.byKey(ValueKey('home-nav-indicator-$label')));
}

double _indicatorScaleX(WidgetTester tester, String label) {
  return tester
      .widget<Transform>(
        find.byKey(ValueKey('home-nav-indicator-scale-$label')),
      )
      .transform
      .entry(0, 0);
}

double _indicatorScaleY(WidgetTester tester, String label) {
  return tester
      .widget<Transform>(
        find.byKey(ValueKey('home-nav-indicator-scale-$label')),
      )
      .transform
      .entry(1, 1);
}

Color _indicatorColor(WidgetTester tester, String label) {
  final indicator = find.byKey(ValueKey('home-nav-indicator-$label'));
  final decoratedBox = find.descendant(
    of: indicator,
    matching: find.byType(DecoratedBox),
  );
  final decoration =
      tester.widget<DecoratedBox>(decoratedBox).decoration as BoxDecoration;
  return decoration.color!;
}

double _indicatorCornerRadius(WidgetTester tester, String label) {
  final indicator = find.byKey(ValueKey('home-nav-indicator-$label'));
  final decoratedBox = find.descendant(
    of: indicator,
    matching: find.byType(DecoratedBox),
  );
  final decoration =
      tester.widget<DecoratedBox>(decoratedBox).decoration as BoxDecoration;
  final borderRadius = decoration.borderRadius! as BorderRadius;
  return borderRadius.topLeft.x;
}

double _selectedIconSize(WidgetTester tester) {
  return tester.widget<Icon>(find.byIcon(Icons.library_books)).size!;
}

TextStyle _labelTextStyle(WidgetTester tester, String label) {
  return tester.widget<Text>(find.text(label)).style!;
}

Widget _testApp({
  required HomeNavigationItem item,
  required bool isSelected,
  bool showLabel = false,
  double itemWidth = 80,
  double itemHeight = 48,
  VoidCallback? onTap,
}) {
  return MaterialApp(
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: itemWidth,
          height: itemHeight,
          child: HomeBounceNavigationItem(
            item: item,
            isSelected: isSelected,
            showLabel: showLabel,
            onTap: onTap ?? () {},
          ),
        ),
      ),
    ),
  );
}
