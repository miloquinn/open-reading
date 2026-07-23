import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xxread/l10n/app_localizations.dart';
import 'package:xxread/pages/settings/cache_management_page.dart';
import 'package:xxread/services/core/cache_management_service.dart';

class _FakeCacheManager extends AppCacheManager {
  _FakeCacheManager()
    : _usage = const AppCacheUsage({
        AppCacheCategory.sourceCovers: 3 * 1024 * 1024,
        AppCacheCategory.sourceData: 5 * 1024 * 1024,
        AppCacheCategory.temporaryFiles: 2 * 1024 * 1024,
      });

  AppCacheUsage _usage;
  final List<AppCacheCategory> clearedCategories = [];
  var clearedAll = false;

  @override
  Future<AppCacheUsage> usage() async => _usage;

  @override
  Future<void> clear(AppCacheCategory category) async {
    clearedCategories.add(category);
    _usage = AppCacheUsage({
      for (final item in AppCacheCategory.values)
        item: item == category ? 0 : _usage.bytesFor(item),
    });
  }

  @override
  Future<void> clearAll() async {
    clearedAll = true;
    _usage = const AppCacheUsage({
      AppCacheCategory.sourceCovers: 0,
      AppCacheCategory.sourceData: 0,
      AppCacheCategory.temporaryFiles: 0,
    });
  }
}

Widget _testApp(AppCacheManager cacheManager) {
  return MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: CacheManagementPage(cacheManager: cacheManager),
  );
}

void main() {
  testWidgets('shows cache usage chart and one cleanup action per category', (
    tester,
  ) async {
    final cacheManager = _FakeCacheManager();
    await tester.pumpWidget(_testApp(cacheManager));
    await tester.pumpAndSettle();

    expect(find.byType(PieChart), findsOneWidget);
    expect(
      find.byKey(const ValueKey('cache-category-sourceCovers')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('cache-category-sourceData')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('cache-category-temporaryFiles')),
      findsOneWidget,
    );
    expect(find.text('10.00 MB'), findsOneWidget);
    expect(find.byKey(const ValueKey('cache-clear-all')), findsOneWidget);
  });

  testWidgets('clears a single category after confirmation', (tester) async {
    final cacheManager = _FakeCacheManager();
    await tester.pumpWidget(_testApp(cacheManager));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('cache-clear-sourceCovers')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Clear'));
    await tester.pumpAndSettle();

    expect(cacheManager.clearedCategories, [AppCacheCategory.sourceCovers]);
    expect(find.text('7.00 MB'), findsOneWidget);
  });

  testWidgets('clears all safe cache categories from the bottom action', (
    tester,
  ) async {
    final cacheManager = _FakeCacheManager();
    await tester.pumpWidget(_testApp(cacheManager));
    await tester.pumpAndSettle();

    final clearAll = find.byKey(const ValueKey('cache-clear-all'));
    await tester.ensureVisible(clearAll);
    await tester.pumpAndSettle();
    await tester.tap(clearAll);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Clear'));
    await tester.pumpAndSettle();

    expect(cacheManager.clearedAll, isTrue);
    expect(find.text('0 B'), findsWidgets);
  });
}
