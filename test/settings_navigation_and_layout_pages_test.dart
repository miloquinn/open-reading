import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xxread/l10n/app_localizations.dart';
import 'package:xxread/models/home_navigation_destination.dart';
import 'package:xxread/pages/settings/floating_navigation_settings_page.dart';
import 'package:xxread/pages/settings/library_layout_settings_page.dart';
import 'package:xxread/services/core/app_settings_service.dart';

Future<AppSettingsNotifier> _loadNotifier() async {
  final notifier = AppSettingsNotifier();
  if (notifier.isInitialized) return notifier;

  final initialized = Completer<void>();
  void listener() {
    if (notifier.isInitialized && !initialized.isCompleted) {
      initialized.complete();
    }
  }

  notifier.addListener(listener);
  listener();
  await initialized.future;
  notifier.removeListener(listener);
  return notifier;
}

Widget _testApp({required AppSettingsNotifier settings, required Widget home}) {
  return ChangeNotifierProvider.value(
    value: settings,
    child: MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('floating navigation page previews and persists reordered tabs', (
    tester,
  ) async {
    final settings = (await tester.runAsync(_loadNotifier))!;
    addTearDown(settings.dispose);

    await tester.pumpWidget(
      _testApp(
        settings: settings,
        home: const FloatingNavigationSettingsPage(),
      ),
    );
    await tester.pump();

    final preview = find.byKey(
      const ValueKey('floating-navigation-live-preview'),
    );
    expect(preview, findsOneWidget);
    expect(
      find.descendant(of: preview, matching: find.text('Home')),
      findsNothing,
    );

    final modeSelector = tester.widget<SegmentedButton<bool>>(
      find.byKey(const ValueKey('floating-navigation-display-mode')),
    );
    modeSelector.onSelectionChanged!({true});
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 260));

    expect(settings.showNavigationLabels, isTrue);
    expect(
      find.descendant(of: preview, matching: find.text('Home')),
      findsOneWidget,
    );

    final orderList = tester.widget<ReorderableListView>(
      find.byKey(const ValueKey('floating-navigation-order-list')),
    );
    orderList.onReorderItem!(0, 2);
    await tester.pump();

    expect(settings.homeNavigationOrder, [
      HomeNavigationDestination.library,
      HomeNavigationDestination.discover,
      HomeNavigationDestination.home,
      HomeNavigationDestination.settings,
    ]);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList('home_navigation_order_v1'), [
      'library',
      'discover',
      'home',
      'settings',
    ]);

    final resetButton = find.byKey(
      const ValueKey('floating-navigation-reset-order'),
    );
    await tester.scrollUntilVisible(resetButton, 300);
    await tester.tap(resetButton);
    await tester.pump();

    expect(settings.homeNavigationOrder, defaultHomeNavigationOrder);
  });

  testWidgets('library layout page reveals grid details only for grid mode', (
    tester,
  ) async {
    final settings = (await tester.runAsync(_loadNotifier))!;
    addTearDown(settings.dispose);

    await tester.pumpWidget(
      _testApp(settings: settings, home: const LibraryLayoutSettingsPage()),
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey('settings-library-layout-selector')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('settings-library-grid-columns')),
      findsNothing,
    );

    final layoutSelector = tester.widget<SegmentedButton<LibraryLayoutMode>>(
      find.byKey(const ValueKey('settings-library-layout-selector')),
    );
    layoutSelector.onSelectionChanged!({LibraryLayoutMode.grid});
    await tester.pump();

    expect(settings.libraryLayoutMode, LibraryLayoutMode.grid);
    expect(
      find.byKey(const ValueKey('settings-library-grid-columns')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('settings-library-grid-show-details')),
      findsOneWidget,
    );
  });
}
