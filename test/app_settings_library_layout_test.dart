import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

  test('library defaults to cards with a three-column cover grid', () async {
    final notifier = await _loadNotifier();
    addTearDown(notifier.dispose);

    expect(notifier.libraryLayoutMode, LibraryLayoutMode.card);
    expect(notifier.libraryGridColumns, 3);
  });

  test('library layout and cover columns restore and persist', () async {
    SharedPreferences.setMockInitialValues({
      'library_layout_mode_v1': 'grid',
      'library_grid_columns_v1': 2,
    });
    final notifier = await _loadNotifier();
    addTearDown(notifier.dispose);

    expect(notifier.libraryLayoutMode, LibraryLayoutMode.grid);
    expect(notifier.libraryGridColumns, 2);

    await notifier.setLibraryLayoutMode(LibraryLayoutMode.card);
    await notifier.setLibraryGridColumns(3);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('library_layout_mode_v1'), 'card');
    expect(prefs.getInt('library_grid_columns_v1'), 3);
  });

  test('unsupported saved column counts fall back to three', () async {
    SharedPreferences.setMockInitialValues({
      'library_grid_columns_v1': 5,
    });
    final notifier = await _loadNotifier();
    addTearDown(notifier.dispose);

    expect(notifier.libraryGridColumns, 3);
  });
}
