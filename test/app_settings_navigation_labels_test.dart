import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xxread/models/home_navigation_destination.dart';
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('navigation labels are hidden by default', () async {
    final notifier = await _loadNotifier();
    addTearDown(notifier.dispose);

    expect(notifier.hideNavigationLabels, isTrue);
    expect(notifier.homeNavigationOrder, HomeNavigationDestination.values);
  });

  test('navigation label visibility restores and persists', () async {
    SharedPreferences.setMockInitialValues({
      'hide_home_navigation_labels_v1': false,
    });
    final notifier = await _loadNotifier();
    addTearDown(notifier.dispose);

    expect(notifier.hideNavigationLabels, isFalse);

    var notifications = 0;
    notifier.addListener(() => notifications++);
    await notifier.setHideNavigationLabels(true);

    final prefs = await SharedPreferences.getInstance();
    expect(notifier.hideNavigationLabels, isTrue);
    expect(prefs.getBool('hide_home_navigation_labels_v1'), isTrue);
    expect(notifications, 1);
  });

  test('navigation order restores, normalizes, and persists', () async {
    SharedPreferences.setMockInitialValues({
      'home_navigation_order_v1': ['settings', 'home', 'home', 'unknown'],
    });
    final notifier = await _loadNotifier();
    addTearDown(notifier.dispose);

    expect(notifier.homeNavigationOrder, [
      HomeNavigationDestination.settings,
      HomeNavigationDestination.home,
      HomeNavigationDestination.library,
      HomeNavigationDestination.discover,
      HomeNavigationDestination.ai,
    ]);

    final repairedPrefs = await SharedPreferences.getInstance();
    expect(repairedPrefs.getStringList('home_navigation_order_v1'), [
      'settings',
      'home',
      'library',
      'discover',
      'ai',
    ]);

    await notifier.setHomeNavigationOrder(const [
      HomeNavigationDestination.discover,
      HomeNavigationDestination.settings,
      HomeNavigationDestination.home,
      HomeNavigationDestination.library,
    ]);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList('home_navigation_order_v1'), [
      'discover',
      'settings',
      'home',
      'library',
      'ai',
    ]);
  });

  test('destination visibility hides pages but never settings', () async {
    final notifier = await _loadNotifier();
    addTearDown(notifier.dispose);

    expect(notifier.visibleHomeNavigationOrder, defaultHomeNavigationOrder);

    await notifier.setHomeNavigationDestinationVisible(
      HomeNavigationDestination.home,
      false,
    );
    expect(
      notifier.visibleHomeNavigationOrder,
      isNot(contains(HomeNavigationDestination.home)),
    );
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList('home_navigation_hidden_v1'), ['home']);

    // 设置页拒绝隐藏。
    await notifier.setHomeNavigationDestinationVisible(
      HomeNavigationDestination.settings,
      false,
    );
    expect(
      notifier.visibleHomeNavigationOrder,
      contains(HomeNavigationDestination.settings),
    );

    // 恢复默认同时清空隐藏集合。
    await notifier.resetHomeNavigationOrder();
    expect(notifier.visibleHomeNavigationOrder, defaultHomeNavigationOrder);
    expect(prefs.getStringList('home_navigation_hidden_v1'), isEmpty);
  });

  test('hidden destinations restore from prefs and drop invalid ids', () async {
    SharedPreferences.setMockInitialValues({
      'home_navigation_hidden_v1': ['home', 'settings', 'unknown'],
    });
    final notifier = await _loadNotifier();
    addTearDown(notifier.dispose);

    expect(notifier.hiddenHomeNavigationDestinations, {
      HomeNavigationDestination.home,
    });
    expect(notifier.visibleHomeNavigationOrder, [
      HomeNavigationDestination.library,
      HomeNavigationDestination.discover,
      HomeNavigationDestination.ai,
      HomeNavigationDestination.settings,
    ]);
  });
}
