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

  test('library defaults to a two-column cover grid', () async {
    final notifier = await _loadNotifier();
    addTearDown(notifier.dispose);

    expect(notifier.libraryLayoutMode, LibraryLayoutMode.grid);
    expect(notifier.libraryGridColumns, 2);
    expect(notifier.libraryGridShowDetails, isTrue);
  });

  test('library layout and cover columns restore and persist', () async {
    SharedPreferences.setMockInitialValues({
      'library_layout_mode_v1': 'card',
      'library_grid_columns_v1': 3,
      'library_grid_show_details_v1': false,
    });
    final notifier = await _loadNotifier();
    addTearDown(notifier.dispose);

    expect(notifier.libraryLayoutMode, LibraryLayoutMode.card);
    expect(notifier.libraryGridColumns, 3);
    expect(notifier.libraryGridShowDetails, isFalse);

    await notifier.setLibraryLayoutMode(LibraryLayoutMode.grid);
    await notifier.setLibraryGridColumns(2);
    await notifier.setLibraryGridShowDetails(true);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('library_layout_mode_v1'), 'grid');
    expect(prefs.getInt('library_grid_columns_v1'), 2);
    expect(prefs.getBool('library_grid_show_details_v1'), isTrue);
  });

  test(
    'unsupported saved layout values fall back to grid with two columns',
    () async {
      SharedPreferences.setMockInitialValues({
        'library_layout_mode_v1': 'list',
        'library_grid_columns_v1': 5,
      });
      final notifier = await _loadNotifier();
      addTearDown(notifier.dispose);

      expect(notifier.libraryLayoutMode, LibraryLayoutMode.grid);
      expect(notifier.libraryGridColumns, 2);
      expect(notifier.libraryGridShowDetails, isTrue);
    },
  );
}
